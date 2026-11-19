import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'models/dock_models.dart';
import 'services/native_telemetry.dart';
import 'services/portable_storage.dart';
import 'services/windows_integration.dart';
import 'widgets/settings_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    size: Size(1380, 240),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setPreventClose(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setAlignment(Alignment.bottomCenter);
    await windowManager.show();
  });

  runApp(const RocketDockApp());
}

class RocketDockApp extends StatelessWidget {
  const RocketDockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'рокет док',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DockScreen(),
    );
  }
}

class DockScreen extends StatefulWidget {
  const DockScreen({super.key});

  @override
  State<DockScreen> createState() => _DockScreenState();
}

class _DockScreenState extends State<DockScreen>
    with TickerProviderStateMixin, TrayListener, WindowListener {
  DockSettings _settings = DockSettings();
  late List<DockItemData> items;

  late final Ticker _physicsTicker;
  final ValueNotifier<int> _frameTick = ValueNotifier<int>(0);

  // 2D pointer tracking (X and Y) so multi-row grids highlight ONLY the icon under the cursor
  Offset? _targetPointerLocal;
  Offset? _smoothPointerLocal;
  double _hoverPresence = 0.0;
  int _closestHoverIndex = -1;

  // Per-row hit map populated during layout/paint to isolate zoom strictly to the hovered row
  final Map<int, ({int rowIdx, Offset center})> _itemRowGeometry = {};
  int _activeHoveredRowIdx = -1;

  // Separator mouse-drag reorder state
  int? _draggingSeparatorIndex;
  int? _separatorDropTargetIndex;

  int _activeEffectIndex = -1;
  double _effectPhase = 0.0;

  final Map<String, DateTime> _pointerDownTimeById = {};
  final Map<String, Offset> _pointerDownPosById = {};
  DateTime _lastLaunchTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastLaunchedId = '';

  static const int _maxCachedIcons = 512;

  bool get _isEffectiveEcoMode =>
      _settings.ecoDesktopMode ||
      (_settings.autoEcoOnBattery && _isOnBatteryPower) ||
      (_settings.autoPauseOnFullscreen && _isFullscreenAppActive);

  int get _targetIconDecodePx {
    if (_isEffectiveEcoMode) {
      return _settings.baseIconSize.round().clamp(32, 96);
    }
    final maxIcon = _settings.baseIconSize +
        (_settings.hoverZoomMode == HoverZoomMode.none ? 0.0 : _settings.zoomDeltaPx);
    return maxIcon.round().clamp(32, 128);
  }

  ImageProvider _buildSizedFileImage(File file) {
    final px = _targetIconDecodePx;
    return ResizeImage(
      FileImage(file),
      width: px,
      height: px,
      policy: ResizeImagePolicy.fit,
    );
  }

  /// Rebuilds providers in place (e.g. new decode size) without ever leaving icons uncached
  void _refreshImageCache() {
    for (final key in _imageCache.keys.toList()) {
      _imageCache[key] = _buildSizedFileImage(File(key));
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  final Set<String> _missingIconKeys = {};

  /// Returns a cached provider or lazily creates it, so a cleared cache never shows placeholders
  ImageProvider? _providerFor(String key) {
    if (key.isEmpty) return null;
    final cached = _imageCache[key];
    if (cached != null) return cached;
    if (_missingIconKeys.contains(key)) return null;
    final file = File(key);
    if (!file.existsSync()) {
      _missingIconKeys.add(key);
      return null;
    }
    final provider = _buildSizedFileImage(file);
    _cacheImageProvider(key, provider);
    return provider;
  }

  void _clearImageCache() {
    _missingIconKeys.clear();
    _imageCache.clear();
    _imageLruKeys.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  final Map<String, ImageProvider> _imageCache = {};
  final List<String> _imageLruKeys = [];

  void _cacheImageProvider(String key, ImageProvider provider) {
    if (_imageCache.containsKey(key)) {
      _imageLruKeys.remove(key);
      _imageLruKeys.add(key);
      _imageCache[key] = provider;
      return;
    }
    while (_imageLruKeys.length >= _maxCachedIcons) {
      final oldest = _imageLruKeys.removeAt(0);
      _imageCache.remove(oldest);
    }
    _imageCache[key] = provider;
    _imageLruKeys.add(key);
  }

  final ValueNotifier<String> _timeNotifier = ValueNotifier<String>('12:00');
  final ValueNotifier<double> _ramNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> _cpuNotifier = ValueNotifier<double>(0);
  final ValueNotifier<int> _tempNotifier = ValueNotifier<int>(42);
  final ValueNotifier<int> _desktopNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> _netNotifier = ValueNotifier<int>(8);
  final ValueNotifier<int> _volNotifier = ValueNotifier<int>(65);
  final ValueNotifier<int> _batNotifier = ValueNotifier<int>(100);

  int? _activeStackIndex;
  List<FileSystemEntity> _activeStackEntries = [];

  bool _isDraggingExternalFile = false;
  bool _isAutoHidden = false;
  bool _isDialogOpen = false;
  bool _isExplicitExit = false;
  bool _showSearchFilter = false;
  String _searchQuery = '';
  bool _sortStackByFolderFirst = true;
  String _toggleHotkeyLabel = 'Control+Alt+R';
  String _lastImportDebugLog = '';
  bool _isOnBatteryPower = false;
  bool _isFullscreenAppActive = false;
  List<File> _availableProfiles = [];

  Timer? _clockTimer;
  Timer? _telemetryTimer;
  Timer? _autoHideTimer;
  Timer? _popupHoverTimer;
  Timer? _saveDebounceTimer;
  Timer? _idleTrimTimer;

  void _scheduleIdleWorkingSetTrim() {
    _idleTrimTimer?.cancel();
    _idleTrimTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _targetPointerLocal == null && !_isDialogOpen) {
        WindowsIntegration.trimProcessWorkingSet();
      }
    });
  }

  String _buildDiagnosticsSummary() {
    final mem = WindowsIntegration.getProcessMemoryInfo();
    final buf = StringBuffer();
    buf.writeln('Режим: ${_isEffectiveEcoMode ? "Экономичный${_settings.ecoDesktopMode ? " (вручную)" : (_isFullscreenAppActive ? " (авто: полный экран)" : " (авто: батарея)")}" : "Стандартный"}');
    buf.writeln('Монитор: #${_settings.monitorIndex + 1} (всего: ${WindowsIntegration.getMonitorCount()}) | Громкость: ${_volNotifier.value}% | Hotkey: ${WindowsIntegration.isGlobalHotkeyRegistered ? "активен" : "выкл"}');
    buf.writeln('Положение: ${_settings.layering.name} (${_settings.screenEdge.name}) | AutoHide: ${_settings.autoHide ? (_isAutoHidden ? "скрыт" : "видим") : "выкл"} | LockIcons: ${_settings.lockIcons}');
    if (mem.workingSetMb > 0) {
      buf.writeln('Память (Working Set): ${mem.workingSetMb.toStringAsFixed(1)} МБ | Private: ${mem.privateBytesMb.toStringAsFixed(1)} МБ');
    } else {
      buf.writeln('Память процесса: доступно только на Windows');
    }
    buf.writeln('Кэш иконок в ОЗУ: ${_imageCache.length} / $_maxCachedIcons (декод ${_targetIconDecodePx}px) | AutoExtractExe: ${_settings.autoExtractExeIcons}');

    final launchable = items.where((it) => !it.isSeparator && !it.isHardwareWidget && !it.isWidgetPlugin && !it.isPowerAction).toList();
    final withIcon = launchable.where((it) => it.customIconPath.trim().isNotEmpty).length;
    final missingTargets = <String>[];
    for (final it in launchable) {
      final t = _resolveEnvPath(it.targetPath);
      final tl = t.toLowerCase();
      if (t.isNotEmpty &&
          !tl.startsWith('http://') &&
          !tl.startsWith('https://') &&
          !tl.startsWith('shell:') &&
          !tl.startsWith('ms-') &&
          (t.contains(r'\') || t.contains('/')) &&
          !File(t).existsSync() &&
          !Directory(t).existsSync()) {
        missingTargets.add('${it.title}: $t');
      }
    }
    buf.writeln('Элементов всего: ${items.length} | Программ/ярлыков: ${launchable.length} (с иконкой: $withIcon, без иконки: ${launchable.length - withIcon})');
    buf.writeln('Ненайденных путей на диске: ${missingTargets.length}');
    for (final m in missingTargets.take(8)) {
      buf.writeln('  [!] $m');
    }
    if (missingTargets.length > 8) {
      buf.writeln('  ... и ещё ${missingTargets.length - 8} путей');
    }
    buf.writeln('Профилей в profiles/: ${_availableProfiles.length} | Файлы: ini=${PortableStorage.iniFile.existsSync()} json=${PortableStorage.jsonFile.existsSync()}');

    buf.writeln('Тикер анимации: ${_physicsTicker.isActive ? "АКТИВЕН" : "остановлен (0% CPU)"}');
    buf.writeln('Таймер часов: ${_clockTimer != null && _clockTimer!.isActive ? "активен (15с)" : "остановлен"}');
    buf.writeln('Таймер датчиков/окон: ${_telemetryTimer != null && _telemetryTimer!.isActive ? "активен (5с)" : "остановлен"}');
    final avgScanUs = WindowsIntegration.windowScanCount > 0
        ? (WindowsIntegration.totalWindowScanMicros / WindowsIntegration.windowScanCount).round()
        : 0;
    buf.writeln('Сканирований окон (EnumWindows): ${WindowsIntegration.windowScanCount} (последнее: ${WindowsIntegration.lastWindowScanMicros} мкс, среднее: $avgScanUs мкс)');
    buf.writeln('--- Журнал запущенных процессов и задач ---');
    final logs = WindowsIntegration.getActivityLog();
    if (logs.isEmpty) {
      buf.writeln('Внешние процессы ещё не запускались.');
    } else {
      for (final line in logs) {
        buf.writeln(line);
      }
    }
    return buf.toString().trimRight();
  }

  void _scheduleDebouncedSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(PortableStorage.save(_settings, items));
    });
  }

  @override
  void initState() {
    super.initState();
    items = _buildDefaultItems();
    windowManager.addListener(this);
    trayManager.addListener(this);

    _physicsTicker = createTicker(_onPhysicsTick);

    _loadAllSettings();
  }

  final Set<String> _attemptedNativeIconIds = {};

  String _resolveEnvPath(String raw) {
    var out = raw.trim();
    if (out.length >= 2 && out.startsWith('"') && out.endsWith('"')) {
      out = out.substring(1, out.length - 1).trim();
    }
    if (!out.contains('%')) return out;
    return out.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
      final k = m.group(1) ?? '';
      return Platform.environment[k] ??
          Platform.environment[k.toUpperCase()] ??
          Platform.environment[k.toLowerCase()] ??
          m.group(0)!;
    });
  }

  Future<int> _reextractAllIconsManually() async {
    _attemptedNativeIconIds.clear();
    _clearImageCache();
    int extractedCount = 0;

    for (final item in items) {
      if (item.isSeparator || item.isHardwareWidget || item.isWidgetPlugin || item.isPowerAction) {
        continue;
      }
      final prevPath = _resolveEnvPath(item.customIconPath);
      if (prevPath.toLowerCase().contains('icons_cache') &&
          (prevPath.toLowerCase().endsWith('.bmp') || prevPath.toLowerCase().endsWith('.png'))) {
        final f = File(prevPath);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
        item.customIconPath = '';
      }

      final srcPath = (item.customIconPath.isNotEmpty &&
              !item.customIconPath.toLowerCase().contains('icons_cache'))
          ? _resolveEnvPath(item.customIconPath)
          : _resolveEnvPath(item.targetPath);

      if (Platform.isWindows && srcPath.isNotEmpty) {
        _attemptedNativeIconIds.add(item.id);
        final sLower = srcPath.toLowerCase();
        if (!sLower.startsWith('http://') &&
            !sLower.startsWith('https://') &&
            !sLower.startsWith('shell:') &&
            !sLower.startsWith('ms-')) {
          final resolved = _resolveEnvPath(
            await WindowsIntegration.resolveShortcutTargetIfNeeded(srcPath),
          );
          final outBmp = WindowsIntegration.extractNativeIcon(resolved, iconIndex: item.iconIndex) ??
              WindowsIntegration.extractNativeIcon(srcPath, iconIndex: item.iconIndex);
          if (outBmp != null && await File(outBmp).exists()) {
            item.customIconPath = outBmp;
            extractedCount++;
          }
        }
      }
    }

    if (WindowsIntegration.lastIconDebugTrace.isNotEmpty) {
      _lastImportDebugLog = '${_lastImportDebugLog.trim()}\n--- Последний трасс извлечения иконки ---\n${WindowsIntegration.lastIconDebugTrace}'.trim();
    }
    await _warmUpIconCache();
    await PortableStorage.save(_settings, items);
    if (mounted) {
      setState(() {});
      _frameTick.value++;
    }
    return extractedCount;
  }

  Future<void> _warmUpIconCache() async {
    int warmed = 0;
    bool updatedAnyPath = false;

    for (final item in items) {
      if (item.isSeparator || item.isHardwareWidget || item.isWidgetPlugin || item.isPowerAction) {
        continue;
      }
      String path = _resolveEnvPath(item.customIconPath);
      final target = _resolveEnvPath(item.targetPath);
      final lowerPath = path.toLowerCase();
      final inIconsCache = lowerPath.contains('icons_cache');
      // Legacy cached .bmp icons (no alpha → black squares) are treated as stale and re-extracted as PNG
      final isLegacyCacheBmp = inIconsCache && lowerPath.endsWith('.bmp');
      final isDirectRaster = path.isNotEmpty &&
          !isLegacyCacheBmp &&
          (lowerPath.endsWith('.png') ||
              lowerPath.endsWith('.jpg') ||
              lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.bmp')) &&
          File(path).existsSync();

      if (!isDirectRaster &&
          Platform.isWindows &&
          _settings.autoExtractExeIcons &&
          !_attemptedNativeIconIds.contains(item.id)) {
        _attemptedNativeIconIds.add(item.id);
        final src = (path.isNotEmpty && !inIconsCache) ? path : target;
        final sLower = src.toLowerCase();
        if (src.isNotEmpty &&
            !sLower.startsWith('http://') &&
            !sLower.startsWith('https://') &&
            !sLower.startsWith('shell:') &&
            !sLower.startsWith('ms-')) {
          final resolved = _resolveEnvPath(
            await WindowsIntegration.resolveShortcutTargetIfNeeded(src),
          );
          final extracted = WindowsIntegration.extractNativeIcon(resolved, iconIndex: item.iconIndex) ??
              WindowsIntegration.extractNativeIcon(src, iconIndex: item.iconIndex);
          if (extracted != null) {
            item.customIconPath = extracted;
            path = extracted;
            updatedAnyPath = true;
          }
        }
      }

      if (path.isNotEmpty && warmed < _maxCachedIcons && !_imageCache.containsKey(path)) {
        final file = File(path);
        if (await file.exists()) {
          _cacheImageProvider(path, _buildSizedFileImage(file));
          warmed++;
        }
      }
    }

    if (WindowsIntegration.lastIconDebugTrace.isNotEmpty &&
        !_lastImportDebugLog.contains(WindowsIntegration.lastIconDebugTrace)) {
      _lastImportDebugLog = '${_lastImportDebugLog.trim()}\n--- Трасс извлечения иконки ---\n${WindowsIntegration.lastIconDebugTrace}'.trim();
    }
    if (updatedAnyPath) {
      await PortableStorage.save(_settings, items);
    }
    if (mounted) _frameTick.value++;
    WindowsIntegration.trimProcessWorkingSet();
    _scheduleIdleWorkingSetTrim();
  }

  void _wakePhysicsTicker() {
    if (!_physicsTicker.isActive) {
      _physicsTicker.start();
    }
  }

  void _onPhysicsTick(Duration elapsed) {
    bool needsRepaint = false;

    final double followRate = (46.0 / _settings.zoomDurationMs.clamp(100.0, 500.0)).clamp(0.12, 0.46);

    final double targetPresence = _targetPointerLocal != null ? 1.0 : 0.0;
    if ((_hoverPresence - targetPresence).abs() > 0.002) {
      _hoverPresence += (targetPresence - _hoverPresence) * followRate;
      needsRepaint = true;
    } else if (_hoverPresence != targetPresence) {
      _hoverPresence = targetPresence;
      needsRepaint = true;
    }

    if (_targetPointerLocal != null) {
      if (_smoothPointerLocal == null) {
        _smoothPointerLocal = _targetPointerLocal;
        needsRepaint = true;
      } else {
        final delta = _targetPointerLocal! - _smoothPointerLocal!;
        if (delta.distance > 0.05) {
          _smoothPointerLocal = _smoothPointerLocal! + delta * (followRate * 1.35).clamp(0.12, 0.45);
          needsRepaint = true;
        }
      }
    } else if (_hoverPresence <= 0.002) {
      _smoothPointerLocal = null;
      _activeHoveredRowIdx = -1;
    }

    if (_activeEffectIndex != -1) {
      _effectPhase += 0.055;
      if (_effectPhase >= 1.0) {
        _activeEffectIndex = -1;
        _effectPhase = 0.0;
      }
      needsRepaint = true;
    }

    if (needsRepaint) {
      _frameTick.value++;
    } else if (_targetPointerLocal == null &&
        _hoverPresence == 0.0 &&
        _activeEffectIndex == -1 &&
        _draggingSeparatorIndex == null &&
        _separatorDropTargetIndex == null &&
        _physicsTicker.isActive) {
      // Stop idle ticker to eliminate background CPU draw
      _physicsTicker.stop();
    }
  }

  List<DockItemData> _buildDefaultItems() {
    final userProfile = Platform.environment['USERPROFILE'] ?? r'C:\Users';
    final docsPath = '$userProfile\\Documents';
    return [
      DockItemData(id: '1', title: 'Проводник', iconName: 'explorer', targetPath: 'explorer.exe'),
      DockItemData(id: '2', title: 'Браузер', iconName: 'browser', targetPath: 'https://www.google.com'),
      DockItemData(id: '3', title: 'Блокнот', iconName: 'notes', targetPath: 'notepad.exe'),
      DockItemData(id: '4', title: 'Калькулятор', iconName: 'calc', targetPath: 'calc.exe'),
      DockItemData(id: '5', title: 'Терминал', iconName: 'terminal', targetPath: 'cmd.exe'),
      DockItemData(id: '6', title: 'Разделитель', iconName: '', targetPath: '', isSeparator: true),
      DockItemData(id: '7', title: 'Документы', iconName: 'folder', targetPath: docsPath, isFolderStack: true),
      DockItemData(id: '8', title: 'Корзина', iconName: 'recycle', targetPath: 'shell:RecycleBinFolder'),
      DockItemData(id: '9', title: 'Разделитель', iconName: '', targetPath: '', isSeparator: true),
      DockItemData(id: '20', title: 'Настройка панели...', iconName: 'settings', targetPath: ''),
    ];
  }

  bool get _hasActiveClockWidget =>
      !_isEffectiveEcoMode &&
      _settings.showClockAndDesktopWidgets &&
      items.any((it) => it.isWidgetPlugin && it.widgetType == 'clock');

  bool get _hasActiveHardwareWidgets =>
      !_isEffectiveEcoMode &&
      (_settings.showHardwareTelemetryWidgets || _settings.showExtraSystemWidgets) &&
      items.any((it) => it.isHardwareWidget);

  void _pauseBackgroundTimers() {
    _clockTimer?.cancel();
    _clockTimer = null;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  void _startTimers() {
    _pauseBackgroundTimers();
    if (_hasActiveClockWidget) {
      _updateClock();
      _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateClock());
    }
    if (_hasActiveHardwareWidgets ||
        (!_isEffectiveEcoMode && _settings.indicateRunningApps) ||
        _settings.autoEcoOnBattery ||
        _settings.autoPauseOnFullscreen) {
      _pollNativeFfiTelemetry();
      _telemetryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollNativeFfiTelemetry());
    }
  }

  void _updateClock() {
    if (!_hasActiveClockWidget) return;
    final now = DateTime.now();
    final formatted = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (formatted != _timeNotifier.value) {
      _timeNotifier.value = formatted;
    }
  }

  Future<void> _pollNativeFfiTelemetry() async {
    if (!Platform.isWindows || !mounted) return;

    if (_settings.globalHotkeysEnabled && WindowsIntegration.pollGlobalToggleHotkeyTriggered()) {
      final vis = await windowManager.isVisible();
      if (vis) {
        await _hideToTray();
      } else {
        await _restoreFromTray();
      }
      return;
    }

    if (_isAutoHidden) return;

    final prevEco = _isEffectiveEcoMode;
    if (_settings.autoEcoOnBattery) {
      _isOnBatteryPower = !NativeHardwareTelemetry.isOnAcPower();
    } else {
      _isOnBatteryPower = false;
    }
    if (_settings.autoPauseOnFullscreen) {
      _isFullscreenAppActive = WindowsIntegration.isForegroundAppFullscreen();
    } else {
      _isFullscreenAppActive = false;
    }
    if (prevEco != _isEffectiveEcoMode) {
      if (_isEffectiveEcoMode) {
        _clockTimer?.cancel();
        _clockTimer = null;
        _refreshImageCache();
        WindowsIntegration.trimProcessWorkingSet();
      } else {
        await _warmUpIconCache();
        if (_hasActiveClockWidget && (_clockTimer == null || !_clockTimer!.isActive)) {
          _updateClock();
          _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateClock());
        }
      }
      if (mounted) _frameTick.value++;
    }

    if (_hasActiveHardwareWidgets) {
      final ram = NativeHardwareTelemetry.getRamUsagePercent();
      final cpu = NativeHardwareTelemetry.getCpuUsagePercent();
      _ramNotifier.value = ram;
      _cpuNotifier.value = cpu;
      _tempNotifier.value = NativeHardwareTelemetry.getCpuTemperatureCelsius(cpu);
      if (_settings.showExtraSystemWidgets) {
        _netNotifier.value = NativeHardwareTelemetry.getNetworkLoadPercent(cpu);
        _volNotifier.value = WindowsIntegration.getSystemVolumePercent();
        _batNotifier.value = NativeHardwareTelemetry.getBatteryPercent();
      }
    }

    if (!_isEffectiveEcoMode && _settings.indicateRunningApps) {
      final running = WindowsIntegration.scanVisibleRunningApps();
      bool changed = false;
      for (final item in items) {
        final proc = item.processImageName;
        if (proc.isNotEmpty) {
          final nowRunning = running.contains(proc);
          if (item.isRunning != nowRunning) {
            item.isRunning = nowRunning;
            changed = true;
          }
        }
      }
      if (changed && mounted) {
        _frameTick.value++;
      }
    }
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    _frameTick.dispose();
    _timeNotifier.dispose();
    _ramNotifier.dispose();
    _cpuNotifier.dispose();
    _tempNotifier.dispose();
    _desktopNotifier.dispose();
    _netNotifier.dispose();
    _volNotifier.dispose();
    _batNotifier.dispose();
    _clockTimer?.cancel();
    _telemetryTimer?.cancel();
    _autoHideTimer?.cancel();
    _popupHoverTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _idleTrimTimer?.cancel();
    WindowsIntegration.unregisterGlobalToggleHotkey();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_isExplicitExit || !_settings.minimizeToTrayOnClose) {
      await _exitApplication();
    } else {
      await _hideToTray();
    }
  }

  Future<void> _hideToTray() async {
    _pauseBackgroundTimers();
    _clearImageCache();
    setState(() {
      _activeStackIndex = null;
      _activeStackEntries = [];
      _targetPointerLocal = null;
      _closestHoverIndex = -1;
      _activeHoveredRowIdx = -1;
    });
    await windowManager.hide();
    WindowsIntegration.trimProcessWorkingSet();
  }

  Future<void> _restoreFromTray() async {
    await _warmUpIconCache();
    await windowManager.show();
    await windowManager.focus();
    await _applyLayering();
    _startTimers();
  }

  Future<void> _exitApplication() async {
    _isExplicitExit = true;
    await PortableStorage.save(_settings, items);
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> _initSystemTray() async {
    try {
      await trayManager.setIcon(Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png');
      await trayManager.setToolTip('RocketDock Portable');
      final Menu menu = Menu(
        items: [
          MenuItem(key: 'show', label: 'Показать панель'),
          MenuItem(key: 'hide', label: 'Свернуть в трей'),
          MenuItem.separator(),
          MenuItem(key: 'add', label: 'Добавить значок...'),
          MenuItem(key: 'settings', label: 'Настройка панели...'),
          MenuItem.separator(),
          MenuItem(key: 'pin_edge', label: 'Закрепить к краю экрана'),
          MenuItem(key: 'lock_icons', label: 'Закрепить значки'),
          MenuItem(key: 'open_portable', label: 'Открыть папку с Settings.ini'),
          if (_availableProfiles.isNotEmpty) ...[
            MenuItem.separator(),
            for (int i = 0; i < _availableProfiles.length && i < 5; i++)
              MenuItem(
                key: 'tray_profile_$i',
                label: 'Профиль: ${_availableProfiles[i].path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.ini\$', caseSensitive: false), '')}',
              ),
          ],
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Выход'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await _hideToTray();
    } else {
      await _restoreFromTray();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'exit') {
      await _exitApplication();
    } else if (menuItem.key == 'settings') {
      await _restoreFromTray();
      await _openSettingsModal();
    } else if (menuItem.key == 'add') {
      await _restoreFromTray();
      await _addItemDialog();
    } else if (menuItem.key == 'show') {
      await _restoreFromTray();
    } else if (menuItem.key == 'hide') {
      await _hideToTray();
    } else if (menuItem.key == 'pin_edge') {
      setState(() => _settings.pinToScreenEdge = !_settings.pinToScreenEdge);
      await PortableStorage.save(_settings, items);
      await _warmUpIconCache();
      await _applyWindowProperties();
      _startTimers();
    } else if (menuItem.key == 'lock_icons') {
      setState(() => _settings.lockIcons = !_settings.lockIcons);
      await PortableStorage.save(_settings, items);
    } else if (menuItem.key == 'open_portable') {
      _launchTargetNonBlocking(PortableStorage.appDir);
    } else if (menuItem.key != null && menuItem.key!.startsWith('tray_profile_')) {
      final pIdx = int.tryParse(menuItem.key!.substring('tray_profile_'.length));
      if (pIdx != null && pIdx >= 0 && pIdx < _availableProfiles.length) {
        await _restoreFromTray();
        final loadedProf = await PortableStorage.loadProfileFromFile(
          _availableProfiles[pIdx].path,
          baseSettings: _settings,
        );
        if (loadedProf != null && mounted) {
          setState(() {
            _settings = loadedProf.settings;
            if (loadedProf.items.isNotEmpty) items = loadedProf.items;
            _activeStackIndex = null;
          });
          _playSound();
          _clearImageCache();
          await _warmUpIconCache();
          await PortableStorage.save(_settings, items);
          await _applyWindowProperties();
          _startTimers();
        }
      }
    }
  }

  Future<void> _loadAllSettings() async {
    final loaded = await PortableStorage.load();
    if (loaded != null && mounted) {
      setState(() {
        _settings = loaded.settings;
        if (loaded.debugLog.contains('HotKey-Toggle=')) {
          final m = RegExp(r'HotKey-Toggle=(.+)').firstMatch(loaded.debugLog);
          if (m != null && m.group(1)!.trim().isNotEmpty) {
            _toggleHotkeyLabel = m.group(1)!.trim();
          }
        }
        _lastImportDebugLog = loaded.debugLog;
        if (loaded.items.isNotEmpty) {
          items = loaded.items;
        }
      });
    } else {
      await PortableStorage.save(_settings, items);
    }
    _availableProfiles = await PortableStorage.listSavedProfiles();
    unawaited(_initSystemTray());
    if (_settings.globalHotkeysEnabled) {
      WindowsIntegration.registerGlobalToggleHotkey();
    } else {
      WindowsIntegration.unregisterGlobalToggleHotkey();
    }
    await _warmUpIconCache();
    await _applyWindowProperties();
    _startTimers();
  }

  Future<void> _showImportDebugDialog(String title, String details) async {
    await _runWithExpandedWindow<void>(() => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xF51E1E22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: SelectableText(
                  details,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Consolas', height: 1.4),
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Закрыть', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ));
  }



  Future<void> _saveToProfilesDir() async {
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final profilePath = '${PortableStorage.profilesDir.path}${Platform.pathSeparator}Profile_$stamp.ini';
    final ok = await PortableStorage.exportProfileIni(profilePath, _settings, items);
    _availableProfiles = await PortableStorage.listSavedProfiles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Профиль сохранён в profiles/: $profilePath' : 'Не удалось сохранить профиль'),
        ),
      );
    }
  }

  Future<void> _exportProfileIniDialog() async {
    final FileSaveLocation? loc = await getSaveLocation(
      suggestedName: 'RocketDock_Profile.ini',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'RocketDock Profile (.ini)', extensions: ['ini']),
      ],
    );
    if (loc == null) return;
    final ok = await PortableStorage.exportProfileIni(loc.path, _settings, items);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Профиль сохранён: ${loc.path}' : 'Не удалось сохранить профиль .ini'),
        ),
      );
    }
  }

  Future<void> _importClassicRocketDockIni() async {
    const XTypeGroup iniGroup = XTypeGroup(
      label: 'RocketDock Settings.ini',
      extensions: ['ini'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [iniGroup]);
    if (file == null) return;

    final result = await PortableStorage.importFromExternalIni(
      file.path,
      currentSettings: _settings,
    );

    String debugText = _lastImportDebugLog;
    try {
      if (await PortableStorage.importDebugLogFile.exists()) {
        debugText = await PortableStorage.importDebugLogFile.readAsString();
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _lastImportDebugLog = debugText);
    }

    if (result == null || !mounted) {
      return;
    }

    _attemptedNativeIconIds.clear();
    setState(() {
      _settings = result.settings;
      if (result.items.isNotEmpty) {
        items = result.items;
      }
      _activeStackIndex = null;
    });
    _playSound();
    _clearImageCache();
    await _warmUpIconCache();
    await PortableStorage.save(_settings, items);
    await _applyWindowProperties();
  }

  Future<void> _applyLayering() async {
    try {
      switch (_settings.layering) {
        case DockLayering.alwaysOnTop:
          await windowManager.setAlwaysOnTop(true);
          break;
        case DockLayering.normal:
          await windowManager.setAlwaysOnTop(false);
          break;
        case DockLayering.onDesktop:
          await windowManager.setAlwaysOnTop(false);
          await windowManager.blur();
          break;
      }
    } catch (_) {}
  }

  List<DockItemData> _getFilteredItems({String queryLower = ''}) {
    return items.where((it) {
      if (_isEffectiveEcoMode && (it.isWidgetPlugin || it.isHardwareWidget)) {
        return false;
      }
      if (!_settings.showClockAndDesktopWidgets && it.isWidgetPlugin) {
        return false;
      }
      if (!_settings.showHardwareTelemetryWidgets &&
          it.isHardwareWidget &&
          (it.hardwareType == 'ram' || it.hardwareType == 'temp' || it.hardwareType == 'cpu')) {
        return false;
      }
      if (!_settings.showExtraSystemWidgets &&
          it.isHardwareWidget &&
          (it.hardwareType == 'net' || it.hardwareType == 'vol' || it.hardwareType == 'bat')) {
        return false;
      }
      if (!_settings.showPowerActionIcons && it.isPowerAction) {
        return false;
      }
      if (queryLower.isNotEmpty) {
        if (it.isSeparator) return false;
        if (it.title.toLowerCase().contains(queryLower)) return true;
        if (_settings.spotlightCommandSearch && it.targetPath.toLowerCase().contains(queryLower)) return true;
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _applyWindowProperties() async {
    try {
      await _applyLayering();
      final isVertical = _settings.screenEdge == DockEdge.left || _settings.screenEdge == DockEdge.right;
      final maxIcon = _settings.baseIconSize + (_settings.hoverZoomMode == HoverZoomMode.none ? 0 : _settings.zoomDeltaPx);
      final rowsFactor = isVertical ? 1 : _settings.rowCount.clamp(1, 3);
      final dockThickness = (maxIcon * rowsFactor + 95.0).clamp(185.0, 900.0);

      final activeItems = _getFilteredItems();
      final itemSlots = activeItems.where((e) => !e.isSeparator).length;
      final sepSlots = activeItems.where((e) => e.isSeparator).length;
      final perRowSpan = ((itemSlots / rowsFactor).ceil() * (_settings.baseIconSize + 8.0) + sepSlots * 14.0 + 180.0)
          .clamp(680.0, 4096.0);

      final double bias = (_settings.edgeCenterOffsetPercent / 100.0).clamp(-1.0, 1.0);
      Alignment align = Alignment(bias, 1.0);
      Size size = Size(perRowSpan, dockThickness);
      if (_settings.screenEdge == DockEdge.top) {
        align = Alignment(bias, -1.0);
      } else if (isVertical) {
        align = _settings.screenEdge == DockEdge.left ? Alignment(-1.0, bias) : Alignment(1.0, bias);
        size = Size(dockThickness, perRowSpan.clamp(560.0, 960.0));
      }
      await windowManager.setSize(size);
      final mon = WindowsIntegration.getMonitorWorkArea(_settings.monitorIndex);
      if (mon != null) {
        final double normX = (align.x + 1.0) * 0.5;
        final double normY = (align.y + 1.0) * 0.5;
        final double targetLeft = mon.left + (mon.width - size.width) * normX;
        final double targetTop = mon.top + (mon.height - size.height) * normY;
        await windowManager.setPosition(Offset(targetLeft, targetTop));
      } else {
        await windowManager.setAlignment(align);
      }
    } catch (_) {}
  }

  Future<T?> _runWithExpandedWindow<T>(Future<T?> Function() showDialogFn) async {
    _isDialogOpen = true;
    _targetPointerLocal = null;
    _clearImageCache();
    try {
      // Opaque background while the window is dialog-sized: a transparent window leaves artifacts around dialogs
      try {
        await windowManager.setBackgroundColor(const Color(0xFF1E1E22));
      } catch (_) {}
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSize(const Size(780, 620));
      await windowManager.setAlignment(Alignment.center);
      await windowManager.show();
      await windowManager.focus();
      return await showDialogFn();
    } finally {
      _isDialogOpen = false;
      try {
        await windowManager.setBackgroundColor(Colors.transparent);
      } catch (_) {}
      await _warmUpIconCache();
      await _applyWindowProperties();
    }
  }

  void _playSound() {
    if (_settings.soundEffectsEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  bool _isIntentionalClick(DockItemData item, Offset upPos) {
    final now = DateTime.now();

    final guardWindowMs = _settings.preventAccidentalClicks ? _settings.accidentalClickGuardMs : 160;
    if (item.id == _lastLaunchedId && now.difference(_lastLaunchTime).inMilliseconds < guardWindowMs) {
      return false;
    }

    if (_settings.preventAccidentalClicks) {
      final downTime = _pointerDownTimeById[item.id];
      final downPos = _pointerDownPosById[item.id];
      if (downTime != null && downPos != null) {
        final heldMs = now.difference(downTime).inMilliseconds;
        final driftPx = (upPos - downPos).distance;
        if (driftPx > 14.0 || heldMs < 25) {
          return false;
        }
      }
    }

    _lastLaunchedId = item.id;
    _lastLaunchTime = now;
    return true;
  }

  Future<bool> _verifyTargetExists(String rawTarget) async {
    final target = rawTarget.trim();
    if (target.isEmpty) return false;
    final lower = target.toLowerCase();
    // Allow shell:, ms-*, http/https URLs, and Windows system executables
    if (lower.startsWith('shell:') ||
        lower.startsWith('ms-') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return true;
    }
    if (!target.contains(r'\') && !target.contains('/')) {
      return true;
    }
    if (await File(target).exists() || await Directory(target).exists()) {
      return true;
    }
    return false;
  }

  void _launchTargetNonBlocking(
    String rawTarget, {
    String? itemId,
    String? displayTitle,
    String arguments = '',
    String workingDirectory = '',
  }) {
    final target = rawTarget.trim();
    if (target.isEmpty) return;

    _playSound();

    Future<void>(() async {
      try {
        final ok = await _verifyTargetExists(target);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Путь не найден: ${displayTitle ?? target}')),
            );
          }
          return;
        }
        await WindowsIntegration.activateOrLaunch(
          targetPath: target,
          arguments: arguments,
          workingDirectory: workingDirectory,
          activateExisting: _settings.activateRunningInstance,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось запустить ${displayTitle ?? target}: $e')),
          );
        }
      }
    });
  }

  Future<void> _addFilePathToDock(String path) async {
    if (path.isEmpty) return;
    final isDir = await FileSystemEntity.isDirectory(path);
    final rawName = path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).last;
    final cleanTitle = isDir
        ? rawName
        : rawName.replaceAll(RegExp(r'\.(exe|lnk|url|bat|cmd)$', caseSensitive: false), '');

    final String newId = '${DateTime.now().millisecondsSinceEpoch}_${items.length}';

    if (!mounted) return;
    setState(() {
      items.add(DockItemData(
        id: newId,
        title: cleanTitle,
        iconName: isDir ? 'folder' : 'custom',
        targetPath: path,
        isFolderStack: isDir,
      ));
    });
    _playSound();
    await PortableStorage.save(_settings, items);
    await _applyWindowProperties();

    if (!isDir && _settings.autoExtractExeIcons) {
      final resolvedPath = await WindowsIntegration.resolveShortcutTargetIfNeeded(path);
      final extractedIcon = WindowsIntegration.extractNativeIcon(resolvedPath) ??
          WindowsIntegration.extractNativeIcon(path);
      if (extractedIcon != null && mounted) {
        final file = File(extractedIcon);
        if (await file.exists()) {
          _cacheImageProvider(extractedIcon, _buildSizedFileImage(file));
          final idx = items.indexWhere((e) => e.id == newId);
          if (idx != -1 && items[idx].customIconPath.isEmpty) {
            setState(() => items[idx].customIconPath = extractedIcon);
            await PortableStorage.save(_settings, items);
          }
        }
      }
    }
  }

  Future<void> _addItemDialog() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Программы, ярлыки и файлы',
      extensions: ['exe', 'lnk', 'bat', 'cmd', 'url', 'txt', 'pdf', 'docx', 'xlsx'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      await _addFilePathToDock(file.path);
    }
  }

  Future<void> _addFolderDialog() async {
    final String? dirPath = await getDirectoryPath();
    if (dirPath != null) {
      await _addFilePathToDock(dirPath);
    }
  }

  Future<void> _executePowerAction(String powerType) async {
    if (!Platform.isWindows) return;
    if (powerType == 'lock') {
      WindowsIntegration.recordActivity('rundll32.exe (Блокировка)');
      await Process.start('rundll32.exe', ['user32.dll,LockWorkStation'], mode: ProcessStartMode.detached);
      return;
    }
    if (powerType == 'sleep') {
      WindowsIntegration.recordActivity('rundll32.exe (Сон)');
      await Process.start('rundll32.exe', ['powrprof.dll,SetSuspendState', '0,1,0'], mode: ProcessStartMode.detached);
      return;
    }

    final isShutdown = powerType == 'shutdown';
    final confirmed = await _runWithExpandedWindow<bool>(() => showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xF51E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(isShutdown ? 'Выключить компьютер?' : 'Перезагрузить компьютер?', style: const TextStyle(color: Colors.white)),
            content: Text(
              isShutdown ? 'Все несохраненные данные могут быть потеряны.' : 'Система будет немедленно перезагружена.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isShutdown ? 'Выключить' : 'Перезагрузить', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ));

    if (confirmed == true) {
      WindowsIntegration.recordActivity('shutdown.exe (${isShutdown ? "/s" : "/r"})');
      await Process.start('shutdown', [isShutdown ? '/s' : '/r', '/t', '0'], mode: ProcessStartMode.detached);
    }
  }

  Future<void> _openFolderStack(int index) async {
    if (_activeStackIndex == index) {
      setState(() {
        _activeStackIndex = null;
        _activeStackEntries = [];
      });
      return;
    }

    final path = items[index].targetPath;
    List<FileSystemEntity> entries = [];
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final raw = await dir.list().take(500).toList();
        if (_settings.sortFoldersFirstInStack) {
          raw.sort((a, b) {
            final aDir = a is Directory ? 0 : 1;
            final bDir = b is Directory ? 0 : 1;
            if (aDir != bDir) return aDir.compareTo(bDir);
            return a.path.toLowerCase().compareTo(b.path.toLowerCase());
          });
        }
        entries = raw.take(200).toList();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeStackIndex = index;
      _activeStackEntries = entries;
    });
  }

  void _triggerClickEffect(int index) {
    if (_settings.clickEffect == ClickAttentionEffect.none) return;
    _activeEffectIndex = index;
    _effectPhase = 0.0;
    _wakePhysicsTicker();
    _frameTick.value++;
  }

  Future<void> _editItemDialog(int index) async {
    final item = items[index];
    final titleCtrl = TextEditingController(text: item.title);
    final pathCtrl = TextEditingController(text: item.targetPath);

    await _runWithExpandedWindow<void>(() => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xF51E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Свойства значка', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Название', labelStyle: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pathCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Объект (путь к файлу / URL / команде)', labelStyle: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF)),
                onPressed: () {
                  setState(() {
                    item.title = titleCtrl.text.trim().isEmpty ? item.title : titleCtrl.text.trim();
                    item.targetPath = pathCtrl.text.trim();
                  });
                  PortableStorage.save(_settings, items);
                  Navigator.pop(ctx);
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ));
  }

  Future<void> _openSettingsModal() async {
    if (_isDialogOpen) return;

    final updated = await _runWithExpandedWindow<DockSettings>(
      () => showDialog<DockSettings>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => RocketDockSettingsDialog(
          initialSettings: _settings,
          itemCount: items.length,
          onResetDefaultItems: () {
            setState(() => items = _buildDefaultItems());
            PortableStorage.save(_settings, items);
          },
          onImportIni: _importClassicRocketDockIni,
          onExportIni: _exportProfileIniDialog,
          onSaveNamedProfile: _saveToProfilesDir,
          profiles: _availableProfiles,
          onDeleteProfile: (pPath) async {
            await PortableStorage.deleteProfileFile(pPath);
            _availableProfiles = await PortableStorage.listSavedProfiles();
          },
          onRenameProfile: (pPath, newName) async {
            await PortableStorage.renameProfileFile(pPath, newName);
            _availableProfiles = await PortableStorage.listSavedProfiles();
          },
          lastDebugLog: _lastImportDebugLog,
          onCollectDiagnostics: _buildDiagnosticsSummary,
          onTrimMemoryNow: () {
            _clearImageCache();
            WindowsIntegration.trimProcessWorkingSet();
          },
          onCleanDiskIconCache: () async {
            final active = items.map((e) => e.customIconPath).where((p) => p.isNotEmpty).toSet();
            final res = await PortableStorage.cleanOrphanedIconCache(active);
            return 'Удалено устаревших файлов кэша: ${res.removedFiles} (${res.freedKb.toStringAsFixed(1)} КБ)';
          },
          onReextractIconsManually: _reextractAllIconsManually,
          onStartWindowDrag: () => unawaited(windowManager.startDragging()),
          onClearDebugLog: () async {
            setState(() => _lastImportDebugLog = '');
            try {
              if (await PortableStorage.importDebugLogFile.exists()) {
                await PortableStorage.importDebugLogFile.delete();
              }
            } catch (_) {}
          },
        ),
      ),
    );

    if (updated != null && mounted) {
      final startupChanged = updated.startWithWindows != _settings.startWithWindows;
      setState(() {
        _settings = updated;
        if (!_settings.autoHide) _isAutoHidden = false;
      });
      if (startupChanged) {
        await WindowsIntegration.setStartWithWindows(_settings.startWithWindows);
      }
      if (_settings.globalHotkeysEnabled) {
        WindowsIntegration.registerGlobalToggleHotkey();
      } else {
        WindowsIntegration.unregisterGlobalToggleHotkey();
      }
      await PortableStorage.save(_settings, items);
      await _applyWindowProperties();
    }
  }

  Future<void> _setEdgeAndPin(DockEdge edge) async {
    setState(() {
      _settings.screenEdge = edge;
      _settings.pinToScreenEdge = true;
    });
    await PortableStorage.save(_settings, items);
    await _applyWindowProperties();
  }

  void _showDockContextMenu(Offset globalPosition, {int? itemIndex}) {
    _autoHideTimer?.cancel();
    final DockItemData? item = (itemIndex != null && itemIndex >= 0 && itemIndex < items.length) ? items[itemIndex] : null;

    if (Platform.isWindows) {
      final entries = <NativeMenuEntry>[
        if (item != null && !item.isSeparator && item.targetPath.isNotEmpty)
          const NativeMenuEntry(value: 'launch', label: 'Открыть'),
        if (item != null && !item.isSeparator && item.targetPath.contains(r'\'))
          const NativeMenuEntry(value: 'reveal', label: 'Показать в Проводнике'),
        if (item != null && !item.isSeparator && item.targetPath.isNotEmpty)
          const NativeMenuEntry(value: 'copy_path', label: 'Копировать путь'),
        if (item != null && !item.isSeparator && item.workingDirectory.isNotEmpty)
          const NativeMenuEntry(value: 'open_workdir', label: 'Открыть рабочую папку'),
        if (item != null && !item.isSeparator)
          const NativeMenuEntry(value: 'edit', label: 'Свойства...'),
        if (item != null && !item.isSeparator)
          const NativeMenuEntry(value: 'change_icon', label: 'Изменить иконку...'),
        if (item != null && !_settings.lockIcons)
          const NativeMenuEntry(value: 'delete', label: 'Удалить с панели'),
        if (item != null) const NativeMenuEntry.separator(),
        if (!_settings.lockIcons) ...[
          const NativeMenuEntry(value: 'add_file', label: 'Добавить файл...'),
          const NativeMenuEntry(value: 'add_folder', label: 'Добавить папку...'),
          const NativeMenuEntry(value: 'add_sep', label: 'Добавить разделитель'),
          const NativeMenuEntry.separator(),
        ],
        NativeMenuEntry(
          value: 'lock_icons',
          label: 'Закрепить значки',
          checked: _settings.lockIcons,
        ),
        NativeMenuEntry(
          value: 'pin_edge',
          label: 'Закрепить к краю',
          checked: _settings.pinToScreenEdge,
        ),
        NativeMenuEntry(
          value: 'eco_mode',
          label: 'Экономичный режим',
          checked: _settings.ecoDesktopMode,
        ),
        if (_availableProfiles.isNotEmpty) ...[
          const NativeMenuEntry.separator(),
          for (int pIdx = 0; pIdx < _availableProfiles.length && pIdx < 5; pIdx++)
            NativeMenuEntry(
              value: 'profile_$pIdx',
              label:
                  'Профиль: ${_availableProfiles[pIdx].path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.ini$', caseSensitive: false), '')}',
            ),
        ],
        const NativeMenuEntry.separator(),
        const NativeMenuEntry(value: 'import_ini', label: 'Импорт Settings.ini...'),
        const NativeMenuEntry(value: 'settings', label: 'Настройки...'),
        const NativeMenuEntry(value: 'hide_tray', label: 'Свернуть в трей'),
        const NativeMenuEntry(value: 'exit', label: 'Выход'),
      ];

      final selected = WindowsIntegration.showNativeContextMenu(entries);
      if (selected != null) {
        unawaited(_handleDockContextMenuAction(selected, item: item, itemIndex: itemIndex));
      }
      return;
    }

    PopupMenuItem<String> macItem(String value, String label, {Color textColor = Colors.white, IconData? icon}) {
      return PopupMenuItem<String>(
        value: value,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor.withOpacity(0.85)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      );
    }

    PopupMenuDivider macDivider() {
      return const PopupMenuDivider(height: 8);
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy - 210, globalPosition.dx + 1, globalPosition.dy),
      color: const Color(0xF5222226),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withOpacity(0.16), width: 0.9),
      ),
      elevation: 12,
      items: [
        if (item != null && !item.isSeparator && item.targetPath.isNotEmpty)
          macItem('launch', 'Открыть', textColor: const Color(0xFF64D2FF), icon: Icons.play_arrow_rounded),
        if (item != null && !item.isSeparator && item.targetPath.contains(r'\'))
          macItem('reveal', 'Показать в Проводнике', icon: Icons.folder_open_rounded),
        if (item != null && !item.isSeparator && item.targetPath.isNotEmpty)
          macItem('copy_path', 'Копировать путь', icon: Icons.copy_rounded),
        if (item != null && !item.isSeparator && item.workingDirectory.isNotEmpty)
          macItem('open_workdir', 'Открыть рабочую папку', icon: Icons.work_outline_rounded),
        if (item != null && !item.isSeparator)
          macItem('edit', 'Свойства...', icon: Icons.edit_rounded),
        if (item != null && !item.isSeparator)
          macItem('change_icon', 'Изменить иконку...', icon: Icons.image_rounded),
        if (item != null && !_settings.lockIcons)
          macItem('delete', 'Удалить с панели', textColor: const Color(0xFFFF6961), icon: Icons.delete_outline_rounded),
        if (item != null) macDivider(),
        if (!_settings.lockIcons) ...[
          macItem('add_file', 'Добавить файл...', icon: Icons.add_rounded),
          macItem('add_folder', 'Добавить папку...', icon: Icons.create_new_folder_rounded),
          macItem('add_sep', 'Добавить разделитель', icon: Icons.horizontal_rule_rounded),
          macDivider(),
        ],
        macItem(
          'lock_icons',
          _settings.lockIcons ? 'Закрепить значки ✓' : 'Закрепить значки',
          textColor: _settings.lockIcons ? const Color(0xFF30D158) : Colors.white,
          icon: Icons.lock_outline_rounded,
        ),
        macItem(
          'pin_edge',
          _settings.pinToScreenEdge ? 'Закрепить к краю ✓' : 'Закрепить к краю',
          textColor: _settings.pinToScreenEdge ? const Color(0xFF64D2FF) : Colors.white,
          icon: Icons.push_pin_outlined,
        ),
        macItem(
          'eco_mode',
          _settings.ecoDesktopMode ? 'Экономичный режим ✓' : 'Экономичный режим',
          textColor: _settings.ecoDesktopMode ? const Color(0xFF30D158) : Colors.white,
          icon: Icons.eco_rounded,
        ),
        if (_availableProfiles.isNotEmpty) ...[
          macDivider(),
          for (int pIdx = 0; pIdx < _availableProfiles.length && pIdx < 5; pIdx++)
            macItem(
              'profile_$pIdx',
              'Профиль: ${_availableProfiles[pIdx].path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.ini$', caseSensitive: false), '')}',
              textColor: const Color(0xFF64D2FF),
              icon: Icons.layers_rounded,
            ),
        ],
        macDivider(),
        macItem('import_ini', 'Импорт Settings.ini...', icon: Icons.file_open_rounded),
        macItem('settings', 'Настройки...', icon: Icons.settings_rounded),
        macItem('hide_tray', 'Свернуть в трей', icon: Icons.remove_rounded),
        macItem('exit', 'Выход', textColor: Colors.white60),
      ],
    ).then((value) async {
      if (value == null) return;
      await _handleDockContextMenuAction(value, item: item, itemIndex: itemIndex);
    });
  }

  Future<void> _handleDockContextMenuAction(String value, {DockItemData? item, int? itemIndex}) async {
    if (value == 'launch' && item != null) {
      _launchTargetNonBlocking(item.targetPath, itemId: item.id, displayTitle: item.title, arguments: item.arguments, workingDirectory: item.workingDirectory);
    } else if (value == 'reveal' && item != null && Platform.isWindows) {
      unawaited(Process.start('explorer.exe', ['/select,${item.targetPath}'], mode: ProcessStartMode.detached));
    } else if (value == 'copy_path' && item != null) {
      await Clipboard.setData(ClipboardData(text: item.targetPath));
    } else if (value == 'open_workdir' && item != null && item.workingDirectory.isNotEmpty) {
      _launchTargetNonBlocking(item.workingDirectory, displayTitle: item.title);
    } else if (value == 'edit' && itemIndex != null) {
      await _editItemDialog(itemIndex);
    } else if (value == 'change_icon' && itemIndex != null) {
      const XTypeGroup imgGroup = XTypeGroup(label: 'Изображения', extensions: ['png', 'jpg', 'jpeg', 'bmp']);
      final XFile? img = await openFile(acceptedTypeGroups: [imgGroup]);
      if (img != null) {
        final file = File(img.path);
        if (await file.exists()) {
          _cacheImageProvider(img.path, _buildSizedFileImage(file));
          setState(() => items[itemIndex].customIconPath = img.path);
          await PortableStorage.save(_settings, items);
        }
      }
    } else if (value == 'add_file') {
      await _addItemDialog();
    } else if (value == 'add_folder') {
      await _addFolderDialog();
    } else if (value == 'add_sep') {
      final insertPos = itemIndex != null ? itemIndex + 1 : items.length;
      setState(() {
        items.insert(
          insertPos,
          DockItemData(id: DateTime.now().millisecondsSinceEpoch.toString(), title: 'Разделитель', iconName: '', targetPath: '', isSeparator: true),
        );
      });
      await PortableStorage.save(_settings, items);
      await _applyWindowProperties();
    } else if (value == 'lock_icons') {
      setState(() => _settings.lockIcons = !_settings.lockIcons);
      await PortableStorage.save(_settings, items);
    } else if (value == 'pin_edge') {
      setState(() => _settings.pinToScreenEdge = !_settings.pinToScreenEdge);
      await PortableStorage.save(_settings, items);
      await _applyWindowProperties();
    } else if (value == 'eco_mode') {
      setState(() => _settings.ecoDesktopMode = !_settings.ecoDesktopMode);
      await PortableStorage.save(_settings, items);
      if (_settings.ecoDesktopMode) {
        _refreshImageCache();
      }
      await _warmUpIconCache();
      await _applyWindowProperties();
      _startTimers();
    } else if (value.startsWith('profile_')) {
      final pIdx = int.tryParse(value.substring('profile_'.length));
      if (pIdx != null && pIdx >= 0 && pIdx < _availableProfiles.length) {
        final loadedProf = await PortableStorage.loadProfileFromFile(
          _availableProfiles[pIdx].path,
          baseSettings: _settings,
        );
        if (loadedProf != null && mounted) {
          setState(() {
            _settings = loadedProf.settings;
            if (loadedProf.items.isNotEmpty) items = loadedProf.items;
            _activeStackIndex = null;
          });
          _playSound();
          _clearImageCache();
          await _warmUpIconCache();
          await PortableStorage.save(_settings, items);
          await _applyWindowProperties();
          _startTimers();
        }
      }
    } else if (value == 'import_ini') {
      await _importClassicRocketDockIni();
    } else if (value == 'settings') {
      await _openSettingsModal();
    } else if (value == 'hide_tray') {
      await _hideToTray();
    } else if (value == 'delete' && itemIndex != null && items.length > 1) {
      setState(() {
        items.removeAt(itemIndex);
        if (_activeStackIndex == itemIndex) _activeStackIndex = null;
      });
      await PortableStorage.save(_settings, items);
      await _applyWindowProperties();
    } else if (value == 'exit') {
      await _exitApplication();
    }
  }

  /// Standard cross-platform Material icons so glyphs render cleanly without missing-glyph boxes
  _MacIconStyle _getMacIconStyle(DockItemData item) {
    if (item.isFolderStack) {
      return const _MacIconStyle(
        colors: [Color(0xFF70D7FF), Color(0xFF0A84FF), Color(0xFF0055D4)],
        icon: Icons.folder_rounded,
      );
    }
    switch (item.iconName) {
      case 'explorer':
        return const _MacIconStyle(
          colors: [Color(0xFF64D2FF), Color(0xFF007AFF), Color(0xFF0051D5)],
          icon: Icons.sentiment_satisfied_alt_rounded,
        );
      case 'browser':
        return const _MacIconStyle(
          colors: [Color(0xFF5AC8FA), Color(0xFF0A84FF), Color(0xFF1A4FD6)],
          icon: Icons.explore_rounded,
        );
      case 'notes':
        return const _MacIconStyle(
          colors: [Color(0xFFFFE042), Color(0xFFFF9F0A), Color(0xFFE07A00)],
          icon: Icons.edit_note_rounded,
        );
      case 'calc':
        return const _MacIconStyle(
          colors: [Color(0xFFFFB340), Color(0xFFFF6B22), Color(0xFFD93800)],
          icon: Icons.calculate_rounded,
        );
      case 'terminal':
        return const _MacIconStyle(
          colors: [Color(0xFF48484E), Color(0xFF242428), Color(0xFF121215)],
          icon: Icons.terminal_rounded,
        );
      case 'recycle':
        return const _MacIconStyle(
          colors: [Color(0xFFD1D1D6), Color(0xFF8E8E93), Color(0xFF636366)],
          icon: Icons.delete_rounded,
        );
      case 'weather':
        return const _MacIconStyle(
          colors: [Color(0xFF3A3A3F), Color(0xFF1C1C20), Color(0xFF0A0A0C)],
          icon: Icons.schedule_rounded,
        );
      case 'desktops':
        return const _MacIconStyle(
          colors: [Color(0xFF7D7AFF), Color(0xFF5E5CE6), Color(0xFF3634A3)],
          icon: Icons.desktop_windows_rounded,
        );
      case 'memory':
        return const _MacIconStyle(
          colors: [Color(0xFFDA8FFF), Color(0xFFBF5AF2), Color(0xFF8944AB)],
          icon: Icons.memory_rounded,
        );
      case 'temp':
        return const _MacIconStyle(
          colors: [Color(0xFFFFB340), Color(0xFFFF6B22), Color(0xFFFF3B30)],
          icon: Icons.thermostat_rounded,
        );
      case 'cpu':
        return const _MacIconStyle(
          colors: [Color(0xFF5CE67E), Color(0xFF30D158), Color(0xFF1E8E3E)],
          icon: Icons.developer_board_rounded,
        );
      case 'net':
        return const _MacIconStyle(
          colors: [Color(0xFF64D2FF), Color(0xFF0A84FF), Color(0xFF0055D4)],
          icon: Icons.wifi_rounded,
        );
      case 'vol':
        return const _MacIconStyle(
          colors: [Color(0xFFFFD60A), Color(0xFFFF9F0A), Color(0xFFD96B00)],
          icon: Icons.volume_up_rounded,
        );
      case 'bat':
        return const _MacIconStyle(
          colors: [Color(0xFF5CE67E), Color(0xFF248A3D), Color(0xFF135E29)],
          icon: Icons.battery_charging_full_rounded,
        );
      case 'sleep':
        return const _MacIconStyle(
          colors: [Color(0xFF7D7AFF), Color(0xFF3634A3), Color(0xFF191847)],
          icon: Icons.bedtime_rounded,
        );
      case 'lock':
        return const _MacIconStyle(
          colors: [Color(0xFFFFD60A), Color(0xFFFF9F0A), Color(0xFFC97A00)],
          icon: Icons.lock_rounded,
        );
      case 'restart':
        return const _MacIconStyle(
          colors: [Color(0xFFFF9F0A), Color(0xFFFF5E3A), Color(0xFFCC3700)],
          icon: Icons.restart_alt_rounded,
        );
      case 'shutdown':
        return const _MacIconStyle(
          colors: [Color(0xFFFF6961), Color(0xFFFF3B30), Color(0xFFBA1A12)],
          icon: Icons.power_settings_new_rounded,
        );
      case 'settings':
        return const _MacIconStyle(
          colors: [Color(0xFFAEAEB2), Color(0xFF636366), Color(0xFF3A3A3C)],
          icon: Icons.settings_rounded,
        );
      default:
        final hint = '${item.title} ${item.targetPath}'.toLowerCase();
        if (hint.contains('http') || hint.contains('chrome') || hint.contains('firefox') || hint.contains('edge') || hint.contains('yandex') || hint.contains('opera') || hint.contains('brave') || hint.contains('vivaldi')) {
          return const _MacIconStyle(
            colors: [Color(0xFF5AC8FA), Color(0xFF0A84FF), Color(0xFF1A4FD6)],
            icon: Icons.public_rounded,
          );
        }
        if (hint.contains('cmd') || hint.contains('powershell') || hint.contains('terminal') || hint.contains('wt.exe') || hint.contains('bash')) {
          return const _MacIconStyle(
            colors: [Color(0xFF48484E), Color(0xFF242428), Color(0xFF121215)],
            icon: Icons.terminal_rounded,
          );
        }
        if (hint.contains('notepad') || hint.contains('word') || hint.contains('doc') || hint.contains('txt') || hint.contains('code')) {
          return const _MacIconStyle(
            colors: [Color(0xFFFFE042), Color(0xFFFF9F0A), Color(0xFFE07A00)],
            icon: Icons.description_rounded,
          );
        }
        if (hint.contains('zip') || hint.contains('rar') || hint.contains('7z') || hint.contains('arch')) {
          return const _MacIconStyle(
            colors: [Color(0xFFDA8FFF), Color(0xFFBF5AF2), Color(0xFF8944AB)],
            icon: Icons.folder_zip_rounded,
          );
        }
        if (hint.contains('vlc') || hint.contains('mp3') || hint.contains('mp4') || hint.contains('player') || hint.contains('media') || hint.contains('music') || hint.contains('video')) {
          return const _MacIconStyle(
            colors: [Color(0xFFFF6961), Color(0xFFFF3B30), Color(0xFFBA1A12)],
            icon: Icons.play_circle_fill_rounded,
          );
        }
        return const _MacIconStyle(
          colors: [Color(0xFF5E5CE6), Color(0xFF3634A3), Color(0xFF1E1C66)],
          icon: Icons.rocket_launch_rounded,
        );
    }
  }

  BoxDecoration _getDockShelfDecoration() {
    final op = _settings.panelOpacity;
    final dragBorder = Border.all(color: const Color(0xFF0A84FF), width: 2.2);

    switch (_settings.themeName) {
      case 'CrystalXP.net':
        return BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: _isDraggingExternalFile ? dragBorder : Border.all(color: Colors.white.withOpacity(0.45 * op), width: 1.1),
          boxShadow: op > 0.05
              ? [BoxShadow(color: Colors.black.withOpacity(0.50 * op), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF565A62).withOpacity(0.88 * op),
              const Color(0xFF25272C).withOpacity(0.92 * op),
              const Color(0xFF121316).withOpacity(0.95 * op),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        );
      case 'Classic Metal 1.3.5':
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _isDraggingExternalFile ? dragBorder : Border.all(color: Colors.white.withOpacity(0.5 * op), width: 1.3),
          boxShadow: op > 0.05
              ? [BoxShadow(color: Colors.black.withOpacity(0.50 * op), blurRadius: 16, offset: const Offset(0, 7))]
              : null,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF72767E).withOpacity(0.9 * op),
              const Color(0xFF34363B).withOpacity(0.94 * op),
            ],
          ),
        );
      case 'VisionOS Crystal':
        return BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: _isDraggingExternalFile ? dragBorder : Border.all(color: Colors.white.withOpacity(0.65 * op), width: 1.3),
          boxShadow: op > 0.05
              ? [BoxShadow(color: Colors.black.withOpacity(0.30 * op), blurRadius: 20, offset: const Offset(0, 8))]
              : null,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.48 * op),
              Colors.white.withOpacity(0.24 * op),
              const Color(0xFFD8E2F0).withOpacity(0.32 * op),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        );
      case 'Dark Obsidian':
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: _isDraggingExternalFile ? dragBorder : Border.all(color: Colors.white.withOpacity(0.18 * op), width: 1.0),
          boxShadow: op > 0.05
              ? [BoxShadow(color: Colors.black.withOpacity(0.60 * op), blurRadius: 20, offset: const Offset(0, 8))]
              : null,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF26262A).withOpacity(0.92 * op),
              const Color(0xFF101013).withOpacity(0.96 * op),
            ],
          ),
        );
      default:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: _isDraggingExternalFile ? dragBorder : Border.all(color: Colors.white.withOpacity(0.34 * op), width: 1.1),
          boxShadow: op > 0.05
              ? [BoxShadow(color: Colors.black.withOpacity(0.42 * op), blurRadius: 20, offset: const Offset(0, 8))]
              : null,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4C4C56).withOpacity(0.78 * op),
              const Color(0xFF282830).withOpacity(0.86 * op),
              const Color(0xFF1C1C22).withOpacity(0.90 * op),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        );
    }
  }

  /// 2D distance-based zoom so in multi-row grids ONLY the icon under the cursor in its own row peaks
  double _computeIconSizePx2D(int globalIdx, double restSlotPitch) {
    final base = _settings.baseIconSize;
    if (_settings.hoverZoomMode == HoverZoomMode.none ||
        _smoothPointerLocal == null ||
        _hoverPresence <= 0.001) {
      return base;
    }

    final geom = _itemRowGeometry[globalIdx];
    if (geom == null) return base;

    // Only magnify icons in the row/column closest to the pointer Y/X
    if (_activeHoveredRowIdx != -1 && geom.rowIdx != _activeHoveredRowIdx) {
      return base;
    }

    final double dx = (geom.center.dx - _smoothPointerLocal!.dx).abs();
    final double influenceRadius = restSlotPitch * (_settings.neighborCount * 0.55);
    if (dx >= influenceRadius) return base;

    double factor;
    if (_settings.hoverZoomMode == HoverZoomMode.plateau) {
      final double flatRadius = restSlotPitch * 0.45;
      if (dx <= flatRadius) {
        factor = 1.0;
      } else {
        final double t = ((dx - flatRadius) / (influenceRadius - flatRadius)).clamp(0.0, 1.0);
        factor = 0.5 * (1.0 + math.cos(t * math.pi));
      }
    } else {
      final double sigma = influenceRadius * 0.48;
      factor = math.exp(-(dx * dx) / (2.0 * sigma * sigma));
    }

    return base + (_settings.zoomDeltaPx * factor * _hoverPresence);
  }

  void _launchQuickSlot(int slotZeroBased) {
  if (!_settings.altNumberQuickLaunch) return;
  final launchable = _getFilteredItems()
  .where((it) => !it.isSeparator && !it.isHardwareWidget && !it.isWidgetPlugin && !it.isPowerAction)
  .toList();
  if (slotZeroBased < 0 || slotZeroBased >= launchable.length) return;
  final targetItem = launchable[slotZeroBased];
  final realIdx = items.indexOf(targetItem);
  if (realIdx != -1) {
  _triggerClickEffect(realIdx);
  }
  if (targetItem.iconName == 'settings') {
  _playSound();
  _openSettingsModal();
  } else if (targetItem.isFolderStack && realIdx != -1) {
  _playSound();
  _openFolderStack(realIdx);
  } else if (targetItem.targetPath.isNotEmpty) {
  _launchTargetNonBlocking(
  targetItem.targetPath,
  itemId: targetItem.id,
  displayTitle: targetItem.title,
  arguments: targetItem.arguments,
  workingDirectory: targetItem.workingDirectory,
  );
  }
  }

  @override
  Widget build(BuildContext context) {
    final bool hidden = _settings.autoHide && _isAutoHidden && !_isDraggingExternalFile && !_isDialogOpen;
    final bool isVertical = _settings.screenEdge == DockEdge.left || _settings.screenEdge == DockEdge.right;

    final double bias = (_settings.edgeCenterOffsetPercent / 100.0).clamp(-1.0, 1.0);
    Alignment alignmentVal = Alignment(bias, 1.0);
    if (_settings.screenEdge == DockEdge.top) alignmentVal = Alignment(bias, -1.0);
    if (_settings.screenEdge == DockEdge.left) alignmentVal = Alignment(-1.0, bias);
    if (_settings.screenEdge == DockEdge.right) alignmentVal = Alignment(1.0, bias);

    final String qLower = _searchQuery.trim().toLowerCase();
    final List<DockItemData> visibleItems = _getFilteredItems(queryLower: qLower);

    final List<List<DockItemData>> rowsList = [];
    if (_settings.rowCount <= 1 || isVertical) {
      rowsList.add(visibleItems);
    } else {
      int itemsPerRow = (visibleItems.length / _settings.rowCount).ceil();
      if (itemsPerRow < 1) itemsPerRow = 1;
      for (int i = 0; i < visibleItems.length; i += itemsPerRow) {
        rowsList.add(visibleItems.sublist(i, i + itemsPerRow > visibleItems.length ? visibleItems.length : i + itemsPerRow));
      }
    }

    final double edgeGap = _settings.pinToScreenEdge ? _settings.edgeDistancePx.clamp(0.0, 128.0) : 8.0;
    final int hideAnimMs = _settings.autoHideDurationMs.round().clamp(0, 1000);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.comma, control: true): _openSettingsModal,
        const SingleActivator(LogicalKeyboardKey.f2): _openSettingsModal,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => setState(() => _showSearchFilter = !_showSearchFilter),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true, alt: true): () async {
          final visible = await windowManager.isVisible();
          if (visible) {
            await _hideToTray();
          } else {
            await _restoreFromTray();
          }
        },
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _launchQuickSlot(0),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _launchQuickSlot(1),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _launchQuickSlot(2),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => _launchQuickSlot(3),
        const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () => _launchQuickSlot(4),
        const SingleActivator(LogicalKeyboardKey.digit6, alt: true): () => _launchQuickSlot(5),
        const SingleActivator(LogicalKeyboardKey.digit7, alt: true): () => _launchQuickSlot(6),
        const SingleActivator(LogicalKeyboardKey.digit8, alt: true): () => _launchQuickSlot(7),
        const SingleActivator(LogicalKeyboardKey.digit9, alt: true): () => _launchQuickSlot(8),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DropTarget(
            onDragEntered: (_) => setState(() {
              _isDraggingExternalFile = true;
              _isAutoHidden = false;
            }),
            onDragExited: (_) => setState(() => _isDraggingExternalFile = false),
            onDragDone: (DropDoneDetails details) async {
              setState(() => _isDraggingExternalFile = false);
              if (_settings.lockIcons) return;
              for (final xfile in details.files) {
                await _addFilePathToDock(xfile.path);
              }
            },
            child: Stack(
              alignment: alignmentVal,
              children: [
                if (_settings.autoHide)
                  Positioned(
                    bottom: _settings.screenEdge == DockEdge.bottom ? 0 : null,
                    top: _settings.screenEdge == DockEdge.top ? 0 : null,
                    left: _settings.screenEdge == DockEdge.left ? 0 : null,
                    right: _settings.screenEdge == DockEdge.right ? 0 : null,
                    width: isVertical ? 18 : null,
                    height: !isVertical ? 18 : null,
                    child: MouseRegion(
                      onEnter: (_) {
                        _autoHideTimer?.cancel();
                        setState(() => _isAutoHidden = false);
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                AnimatedPositioned(
                  duration: Duration(milliseconds: hideAnimMs),
                  curve: Curves.easeOutCubic,
                  bottom: (_settings.screenEdge == DockEdge.bottom) ? (hidden ? -220 : edgeGap) : null,
                  top: (_settings.screenEdge == DockEdge.top) ? (hidden ? -220 : edgeGap) : null,
                  left: (_settings.screenEdge == DockEdge.left) ? (hidden ? -220 : edgeGap) : null,
                  right: (_settings.screenEdge == DockEdge.right) ? (hidden ? -220 : edgeGap) : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showSearchFilter)
                        Container(
                          width: 260,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xF21E1E24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF64D2FF).withOpacity(0.55)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64D2FF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'Поиск значка...',
                                    hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  onSubmitted: (v) {
                                    final q = v.trim().toLowerCase();
                                    if (q.isEmpty) return;
                                    final match = items.cast<DockItemData?>().firstWhere(
                                      (it) => it != null && !it.isSeparator && it.title.toLowerCase().contains(q),
                                      orElse: () => null,
                                    );
                                    if (match != null && match.targetPath.isNotEmpty) {
                                      _launchTargetNonBlocking(
                                        match.targetPath,
                                        itemId: match.id,
                                        displayTitle: match.title,
                                        arguments: match.arguments,
                                        workingDirectory: match.workingDirectory,
                                      );
                                      setState(() {
                                        _searchQuery = '';
                                        _showSearchFilter = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _searchQuery = '';
                                  _showSearchFilter = false;
                                }),
                                child: const Icon(Icons.close_rounded, size: 15, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),

                      if (_isDraggingExternalFile)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: _settings.lockIcons ? Colors.redAccent : const Color(0xEB0A84FF),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12)],
                          ),
                          child: Text(
                            _settings.lockIcons
                                ? 'Значки закреплены (разблокируйте в настройках)'
                                : 'Отпустите файл или папку, чтобы закрепить на панели',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                          ),
                        ),

                      if (_activeStackIndex != null && _activeStackIndex! < items.length && items[_activeStackIndex!].isFolderStack)
                        Container(
                          width: 290,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xF51E1E22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 1),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      items[_activeStackIndex!].title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Открыть папку в Проводнике',
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.lightBlueAccent),
                                    onPressed: () {
                                      _launchTargetNonBlocking(items[_activeStackIndex!].targetPath);
                                      setState(() => _activeStackIndex = null);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _activeStackIndex = null),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24),
                              if (_activeStackEntries.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('Папка пуста', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                )
                              else
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 140),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _activeStackEntries.length,
                                    itemBuilder: (ctx, i) {
                                      final entity = _activeStackEntries[i];
                                      final name = entity.path.split(Platform.pathSeparator).last;
                                      final isSubDir = entity is Directory;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          _launchTargetNonBlocking(entity.path, displayTitle: name);
                                          setState(() => _activeStackIndex = null);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSubDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                                                size: 15,
                                                color: isSubDir ? const Color(0xFF64D2FF) : Colors.white70,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),

                      MouseRegion(
                        onEnter: (_) {
                          _autoHideTimer?.cancel();
                          if (_settings.popupOnMouseover && _settings.layering != DockLayering.alwaysOnTop) {
                            _popupHoverTimer?.cancel();
                            _popupHoverTimer = Timer(Duration(milliseconds: _settings.popupDelayMs.round()), () {
                              windowManager.setAlwaysOnTop(true);
                            });
                          }
                        },
                        onHover: (event) {
                          _targetPointerLocal = event.localPosition;
                          _wakePhysicsTicker();
                        },
                        onExit: (_) {
                          _targetPointerLocal = null;
                          _scheduleIdleWorkingSetTrim();
                          _closestHoverIndex = -1;
                          _activeHoveredRowIdx = -1;
                          _popupHoverTimer?.cancel();
                          if (_settings.popupOnMouseover && _settings.layering != DockLayering.alwaysOnTop) {
                            _applyLayering();
                          }
                          if (_settings.autoHide && !_isDraggingExternalFile && !_isDialogOpen) {
                            _autoHideTimer?.cancel();
                            _autoHideTimer = Timer(Duration(milliseconds: _settings.autoHideDelayMs.round()), () {
                              if (mounted && _targetPointerLocal == null && !_isDialogOpen) {
                                setState(() => _isAutoHidden = true);
                              }
                            });
                          }
                        },
                        child: GestureDetector(
                          onPanStart: _settings.pinToScreenEdge ? null : (_) => windowManager.startDragging(),
                          onSecondaryTapUp: (d) => _showDockContextMenu(d.globalPosition),
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _frameTick,
                              builder: (context, _) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: _getDockShelfDecoration(),
                                      child: isVertical
                                          ? _buildRowOrCol(visibleItems, rowIdx: 0, isVertical: true)
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                for (int r = 0; r < rowsList.length; r++)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                                                    child: _buildRowOrCol(rowsList[r], rowIdx: r, isVertical: false),
                                                  ),
                                              ],
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowOrCol(List<DockItemData> rowItems, {required int rowIdx, required bool isVertical}) {
    const double itemSpacing = 6.0;
    const double sepThickness = 14.0; // 2px line + 2*6px padding, must match the separator widget
    final double restPitch = _settings.baseIconSize + itemSpacing;
    final double rowBandHeight = _settings.baseIconSize + 14.0;
    final double rowCenterY = 8.0 + rowIdx * (rowBandHeight + 6.0) + rowBandHeight * 0.5;

    final List<double> restCentersX = [];
    double cursorX = 12.0;
    for (int i = 0; i < rowItems.length; i++) {
      final item = rowItems[i];
      final globalIdx = items.indexOf(item);
      if (item.isSeparator) {
        final cx = cursorX + sepThickness * 0.5;
        restCentersX.add(cx);
        _itemRowGeometry[globalIdx] = (rowIdx: rowIdx, center: Offset(cx, rowCenterY));
        cursorX += sepThickness;
      } else {
        final cx = cursorX + restPitch * 0.5;
        restCentersX.add(cx);
        _itemRowGeometry[globalIdx] = (rowIdx: rowIdx, center: Offset(cx, rowCenterY));
        cursorX += restPitch;
      }
    }

    // Determine which row is closest to cursor Y so multi-row grids only zoom one row at a time
    if (_smoothPointerLocal != null && _hoverPresence > 0.25 && !isVertical) {
      int bestRow = 0;
      double bestRowDist = double.infinity;
      for (int r = 0; r < (_settings.rowCount.clamp(1, 3)); r++) {
        final ry = 8.0 + r * (rowBandHeight + 6.0) + rowBandHeight * 0.5;
        final dy = (_smoothPointerLocal!.dy - ry).abs();
        if (dy < bestRowDist) {
          bestRowDist = dy;
          bestRow = r;
        }
      }
      _activeHoveredRowIdx = bestRow;
    }

    // Pick closest non-separator item ONLY within the active row
    if (_smoothPointerLocal != null && _hoverPresence > 0.35 && (isVertical || _activeHoveredRowIdx == rowIdx)) {
      int bestGlobalIdx = -1;
      double bestDist = double.infinity;
      for (int i = 0; i < rowItems.length; i++) {
        if (rowItems[i].isSeparator) continue;
        final d = (restCentersX[i] - _smoothPointerLocal!.dx).abs();
        if (d < restPitch * 0.55 && d < bestDist) {
          bestDist = d;
          bestGlobalIdx = items.indexOf(rowItems[i]);
        }
      }
      if (bestGlobalIdx != -1) {
        _closestHoverIndex = bestGlobalIdx;
      }
    }

    final children = <Widget>[];
    for (int i = 0; i < rowItems.length; i++) {
      final item = rowItems[i];
      final globalIdx = items.indexOf(item);
      final sizePx = item.isSeparator ? _settings.baseIconSize : _computeIconSizePx2D(globalIdx, restPitch);
      children.add(_buildDockItem(item, globalIdx, currentSize: sizePx, isVertical: isVertical));
    }

    return isVertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: children);
  }

  Widget _buildMacSquircleIcon(DockItemData item, double size) {
    final iconKey = _resolveEnvPath(item.customIconPath);
    final cachedProvider = _providerFor(iconKey);
    if (cachedProvider != null) {
      // Classic RocketDock look: icon as is — no rounded clipping, no box shadow under transparent pixels
      return SizedBox(
        width: size,
        height: size,
        child: Image(
          image: cachedProvider,
          fit: BoxFit.contain,
          isAntiAlias: true,
          filterQuality: _settings.filterQuality,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildFallbackSquircle(item, size),
        ),
      );
    }
    return _buildFallbackSquircle(item, size);
  }

  Widget _buildFallbackSquircle(DockItemData item, double size) {
    final radius = size * 0.225;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: const Color(0xFF2C2C34),
        border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.8),
      ),
      alignment: Alignment.center,
      child: item.isFolderStack
          ? Icon(Icons.folder_rounded, color: Colors.white70, size: size * 0.52)
          : Text(
              _fallbackLetter(item),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white70,
                fontSize: size * 0.46,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
    );
  }

  String _fallbackLetter(DockItemData item) {
    final title = item.title.trim();
    if (title.isEmpty) return '?';
    return String.fromCharCode(title.runes.first).toUpperCase();
  }

  int _quickLaunchSlotForItem(DockItemData target) {
    if (!_settings.altNumberQuickLaunch || !_settings.showQuickLaunchBadges) return -1;
    if (target.isSeparator || target.isHardwareWidget || target.isWidgetPlugin || target.isPowerAction) {
      return -1;
    }
    final launchable = _getFilteredItems()
        .where((it) => !it.isSeparator && !it.isHardwareWidget && !it.isWidgetPlugin && !it.isPowerAction)
        .toList();
    final idx = launchable.indexOf(target);
    return (idx >= 0 && idx < 9) ? idx + 1 : -1;
  }

  Widget _buildLiveBadge(DockItemData item) {
    if (item.isHardwareWidget) {
      if (item.hardwareType == 'ram') {
        return ValueListenableBuilder<double>(
          valueListenable: _ramNotifier,
          builder: (_, val, __) => _badgePill('${val.toStringAsFixed(0)}%', const Color(0xFFDA8FFF)),
        );
      } else if (item.hardwareType == 'temp') {
        return ValueListenableBuilder<int>(
          valueListenable: _tempNotifier,
          builder: (_, val, __) {
            final c = val >= 80
                ? const Color(0xFFFF453A)
                : (val >= 65 ? const Color(0xFFFF9F0A) : const Color(0xFF64D2FF));
            return _badgePill('$val°C', c);
          },
        );
      } else if (item.hardwareType == 'cpu') {
        return ValueListenableBuilder<double>(
          valueListenable: _cpuNotifier,
          builder: (_, val, __) => _badgePill('${val.toStringAsFixed(0)}%', const Color(0xFF30D158)),
        );
      } else if (item.hardwareType == 'net') {
        return ValueListenableBuilder<int>(
          valueListenable: _netNotifier,
          builder: (_, val, __) => _badgePill('$val%', const Color(0xFF64D2FF)),
        );
      } else if (item.hardwareType == 'vol') {
        return ValueListenableBuilder<int>(
          valueListenable: _volNotifier,
          builder: (_, val, __) => _badgePill('$val%', const Color(0xFFFFD60A)),
        );
      } else if (item.hardwareType == 'bat') {
        return ValueListenableBuilder<int>(
          valueListenable: _batNotifier,
          builder: (_, val, __) => _badgePill('$val%', const Color(0xFF30D158)),
        );
      }
    } else if (item.isWidgetPlugin) {
      if (item.widgetType == 'clock') {
        return ValueListenableBuilder<String>(
          valueListenable: _timeNotifier,
          builder: (_, val, __) => _badgePill(val, const Color(0xFFFFD60A)),
        );
      } else if (item.widgetType == 'desktops') {
        return ValueListenableBuilder<int>(
          valueListenable: _desktopNotifier,
          builder: (_, val, __) => _badgePill('#$val', const Color(0xFF64D2FF)),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _badgePill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        color: const Color(0xEE141416),
        borderRadius: BorderRadius.circular(4.5),
        border: Border.all(color: color.withOpacity(0.82), width: 0.75),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8.2, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
      ),
    );
  }

  Widget _buildStyledLabel(String text) {
    final shadowColor = Color(_settings.labelShadowColorValue).withOpacity(_settings.labelShadowOpacity);
    final outlineColor = Color(_settings.labelOutlineColorValue).withOpacity(_settings.labelOutlineOpacity);

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_settings.labelOutlineOpacity > 0.02)
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: _settings.labelFontFamily,
              fontSize: _settings.labelFontSize,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (_settings.labelFontSize * 0.2).clamp(1.6, 3.2).toDouble()
                ..strokeJoin = StrokeJoin.round
                ..color = outlineColor,
            ),
          ),
        Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: _settings.labelFontFamily,
            fontSize: _settings.labelFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            decoration: TextDecoration.none,
            shadows: _settings.labelShadowOpacity > 0.02
                ? [Shadow(color: shadowColor, blurRadius: 4, offset: const Offset(1.5, 2.0))]
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDockItem(
    DockItemData item,
    int index, {
    required double currentSize,
    required bool isVertical,
  }) {
    if (item.isSeparator) {
      final bool isDropTarget = _separatorDropTargetIndex == index;
      final bool isBeingDragged = _draggingSeparatorIndex == index;
      final double sepLen = _settings.baseIconSize * (isDropTarget ? 1.02 : 0.84);

      final Widget sepVisual = MouseRegion(
        cursor: _settings.lockIcons ? SystemMouseCursors.basic : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (d) => _showDockContextMenu(d.globalPosition, itemIndex: index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            // Dock items carry 9px (gap + running dot + padding) below the icon: lift the line so its centre matches the icons' centre
            padding: isVertical
                ? EdgeInsets.symmetric(vertical: isDropTarget ? 12 : 6, horizontal: 4)
                : EdgeInsets.fromLTRB(
                    isDropTarget ? 13 : 6,
                    3,
                    isDropTarget ? 13 : 6,
                    (_settings.baseIconSize - sepLen) / 2 + 9.0,
                  ),
            decoration: isDropTarget
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0A84FF).withOpacity(0.35),
                        const Color(0xFF64D2FF).withOpacity(0.14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF64D2FF).withOpacity(0.9), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0A84FF).withOpacity(0.45), blurRadius: 10),
                    ],
                  )
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: isVertical ? 36 : (isDropTarget ? 4.0 : 2.0),
              height: isVertical ? (isDropTarget ? 4.0 : 2.0) : sepLen,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDropTarget
                      ? [const Color(0xFF8BE5FF), const Color(0xFF0A84FF)]
                      : [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.22)],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: isDropTarget
                    ? [BoxShadow(color: const Color(0xFF64D2FF).withOpacity(0.95), blurRadius: 9)]
                    : null,
              ),
            ),
          ),
        ),
      );

      if (_settings.lockIcons) {
        return sepVisual;
      }

      return DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          if (details.data != index && details.data >= 0 && details.data < items.length) {
            if (_separatorDropTargetIndex != index) {
              setState(() => _separatorDropTargetIndex = index);
              _wakePhysicsTicker();
            }
            return true;
          }
          return false;
        },
        onLeave: (_) {
          if (_separatorDropTargetIndex == index) {
            setState(() => _separatorDropTargetIndex = null);
          }
        },
        onAcceptWithDetails: (details) {
          final fromIndex = details.data;
          setState(() {
            _draggingSeparatorIndex = null;
            _separatorDropTargetIndex = null;
            if (fromIndex != index && fromIndex >= 0 && fromIndex < items.length) {
              final moved = items.removeAt(fromIndex);
              final insertIdx = fromIndex < index ? index - 1 : index;
              items.insert(insertIdx.clamp(0, items.length), moved);
            }
          });
          _scheduleDebouncedSave();
          unawaited(_applyWindowProperties());
        },
        builder: (context, candidate, rejected) {
          return Draggable<int>(
            data: index,
            onDragStarted: () {
              setState(() => _draggingSeparatorIndex = index);
              _wakePhysicsTicker();
            },
            onDragEnd: (_) => setState(() {
              _draggingSeparatorIndex = null;
              _separatorDropTargetIndex = null;
            }),
            feedback: Material(
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.08,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xF22A2D36), Color(0xF2171920)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF64D2FF), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0A84FF).withOpacity(0.5), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 3.5,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF8BE5FF), Color(0xFF0A84FF)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.drag_indicator_rounded, size: 15, color: Color(0xFF64D2FF)),
                      const SizedBox(width: 4),
                      const Text(
                        'Разделитель',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: isBeingDragged ? 0.18 : 0.3, child: sepVisual),
            child: sepVisual,
          );
        },
      );
    }

    final double maxDelta = _settings.hoverZoomMode == HoverZoomMode.none ? 1.0 : math.max(1.0, _settings.zoomDeltaPx);
    final double liftRatio = ((currentSize - _settings.baseIconSize) / maxDelta).clamp(0.0, 1.0);
    final double hoverLiftY = -6.5 * liftRatio;

    final double baseOp = _settings.iconOpacity;
    final double effectiveOpacity = _settings.fullOpacityOnHover
        ? (baseOp + (1.0 - baseOp) * liftRatio).clamp(0.0, 1.0)
        : baseOp;

    double clickBounceY = 0.0;
    double clickScale = 1.0;
    double clickAngle = 0.0;
    if (_activeEffectIndex == index && _effectPhase > 0.0 && _effectPhase < 1.0) {
      if (_settings.clickEffect == ClickAttentionEffect.bounce) {
        clickBounceY = -15.0 * math.sin(_effectPhase * math.pi) * (1.0 - _effectPhase * 0.45);
      } else if (_settings.clickEffect == ClickAttentionEffect.pulse) {
        clickScale = 1.0 + 0.25 * math.sin(_effectPhase * math.pi);
      } else if (_settings.clickEffect == ClickAttentionEffect.spin) {
        clickAngle = _effectPhase * 2.0 * math.pi;
      }
    }

    final bool showTooltip = !_settings.hideIconLabels && _closestHoverIndex == index;
    final bool showRunningDot = _settings.indicateRunningApps &&
        item.isRunning &&
        !item.isHardwareWidget &&
        !item.isWidgetPlugin &&
        !item.isPowerAction;

    final slotBadge = _quickLaunchSlotForItem(item);
    Widget graphic = Stack(
      alignment: Alignment.center,
      children: [
        _buildMacSquircleIcon(item, currentSize),
        if (slotBadge > 0)
          Positioned(
            top: 2,
            left: 2,
            child: _badgePill('$slotBadge', const Color(0xFF64D2FF)),
          ),
        if (item.isHardwareWidget || item.isWidgetPlugin)
          Positioned(
            bottom: 2.5,
            child: _buildLiveBadge(item),
          ),
      ],
    );

    if (clickScale != 1.0) {
      graphic = Transform.scale(scale: clickScale, child: graphic);
    }
    if (clickAngle != 0.0) {
      graphic = Transform.rotate(angle: clickAngle, child: graphic);
    }

    final Widget iconCore = RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _pointerDownTimeById[item.id] = DateTime.now();
            _pointerDownPosById[item.id] = details.globalPosition;
          },
          onTapCancel: () {
            _pointerDownTimeById.remove(item.id);
            _pointerDownPosById.remove(item.id);
          },
          onTapUp: (details) {
            _pointerDownTimeById.remove(item.id);
            _pointerDownPosById.remove(item.id);
            if (!_isIntentionalClick(item, details.globalPosition)) {
              return;
            }
            _triggerClickEffect(index);
            if (item.iconName == 'settings') {
              _playSound();
              _openSettingsModal();
            } else if (item.isFolderStack) {
              _playSound();
              _openFolderStack(index);
            } else if (item.isPowerAction) {
              _playSound();
              _executePowerAction(item.powerType);
            } else if (item.isWidgetPlugin && item.widgetType == 'desktops') {
              _playSound();
              _desktopNotifier.value = _desktopNotifier.value == 1 ? 2 : 1;
              if (Platform.isWindows) {
                unawaited(Process.start('explorer.exe', ['shell:::{3080F90E-D7AD-11D9-BD98-0000947B0257}'], mode: ProcessStartMode.detached));
              }
            } else if (item.targetPath.isNotEmpty) {
              if (_settings.indicateRunningApps && !item.isRunning) {
                setState(() => item.isRunning = true);
              }
              _launchTargetNonBlocking(item.targetPath, itemId: item.id, displayTitle: item.title, arguments: item.arguments, workingDirectory: item.workingDirectory);
            }
          },
          onSecondaryTapUp: (details) => _showDockContextMenu(details.globalPosition, itemIndex: index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                if (showTooltip && !isVertical)
                  Positioned(
                    bottom: currentSize + 13.0,
                    child: IgnorePointer(
                      child: _buildStyledLabel(item.title),
                    ),
                  ),
                Transform.translate(
                  offset: isVertical ? Offset(-hoverLiftY, 0) : Offset(0, hoverLiftY + clickBounceY),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: effectiveOpacity,
                        child: graphic,
                      ),
                      const SizedBox(height: 2.5),
                      Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: showRunningDot ? Colors.white.withOpacity(0.95) : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: showRunningDot
                              ? [BoxShadow(color: Colors.lightBlueAccent.withOpacity(0.9), blurRadius: 4)]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (_settings.lockIcons) {
      return iconCore;
    }

    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        final fromIndex = details.data;
        if (fromIndex != index && fromIndex >= 0 && fromIndex < items.length) {
          setState(() {
            _draggingSeparatorIndex = null;
            _separatorDropTargetIndex = null;
            final moved = items.removeAt(fromIndex);
            items.insert(index, moved);
          });
          _scheduleDebouncedSave();
          unawaited(_applyWindowProperties());
        }
      },
      builder: (context, candidate, rejected) {
        return Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: _buildMacSquircleIcon(item, _settings.baseIconSize * 1.15),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: iconCore),
          child: iconCore,
        );
      },
    );
  }
}

class _MacIconStyle {
  final List<Color> colors;
  final IconData icon;
  const _MacIconStyle({required this.colors, required this.icon});
}
