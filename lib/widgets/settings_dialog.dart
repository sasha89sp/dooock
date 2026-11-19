import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dock_models.dart';
import '../services/portable_storage.dart';

class RocketDockSettingsDialog extends StatefulWidget {
  final DockSettings initialSettings;
  final int itemCount;
  final VoidCallback onResetDefaultItems;
  final Future<void> Function()? onImportIni;
  final Future<void> Function()? onExportIni;
  final Future<void> Function()? onSaveNamedProfile;
  final String lastDebugLog;
  final VoidCallback? onClearDebugLog;
  final List<File> profiles;
  final Future<void> Function(String profilePath)? onDeleteProfile;
  final Future<void> Function(String profilePath, String newName)? onRenameProfile;
  final String Function()? onCollectDiagnostics;
  final VoidCallback? onTrimMemoryNow;
  final Future<String> Function()? onCleanDiskIconCache;
  final Future<int> Function()? onReextractIconsManually;
  final VoidCallback? onStartWindowDrag;

  const RocketDockSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.itemCount,
    required this.onResetDefaultItems,
    this.onImportIni,
    this.onExportIni,
    this.onSaveNamedProfile,
    this.lastDebugLog = '',
    this.onClearDebugLog,
    this.profiles = const [],
    this.onDeleteProfile,
    this.onRenameProfile,
    this.onCollectDiagnostics,
    this.onTrimMemoryNow,
    this.onCleanDiskIconCache,
    this.onReextractIconsManually,
    this.onStartWindowDrag,
  });

  @override
  State<RocketDockSettingsDialog> createState() => _RocketDockSettingsDialogState();
}

class _RocketDockSettingsDialogState extends State<RocketDockSettingsDialog> {
  int _selectedTab = 0;
  late DockSettings _draft;

  static const _tabs = [
    (title: 'Общие', icon: Icons.tune_rounded, color: Color(0xFF8E8E93)),
    (title: 'Значки', icon: Icons.grid_view_rounded, color: Color(0xFFFF9F0A)),
    (title: 'Положение', icon: Icons.dock_rounded, color: Color(0xFF0A84FF)),
    (title: 'Стиль', icon: Icons.palette_rounded, color: Color(0xFFBF5AF2)),
    (title: 'Реакция', icon: Icons.animation_rounded, color: Color(0xFF30D158)),
    (title: 'О программе', icon: Icons.info_rounded, color: Color(0xFF5AC8FA)),
  ];

  static const _themes = [
    'macOS Sonoma Glass',
    'VisionOS Crystal',
    'CrystalXP.net',
    'Classic Metal 1.3.5',
    'Dark Obsidian',
  ];

  static const _fonts = [
    'Segoe UI',
    'Arial',
    'Tahoma',
    'Consolas',
    'Verdana',
  ];

  static const _swatches = [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFF0A84FF),
    Color(0xFF30D158),
    Color(0xFFFF9F0A),
    Color(0xFFFF453A),
    Color(0xFFBF5AF2),
    Color(0xFFFFD60A),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.initialSettings.copy();
  }

  void _resetAllDefaults() {
    setState(() {
      _draft = DockSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 740,
        height: 580,
        decoration: BoxDecoration(
          color: const Color(0xF71E1E22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 36, offset: const Offset(0, 16)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                width: 196,
                decoration: BoxDecoration(
                  color: const Color(0xFF26262B).withOpacity(0.92),
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.10), width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                      child: Row(
                        children: [
                          _trafficLight(const Color(0xFFFF5F57), () => Navigator.pop(context, null)),
                          const SizedBox(width: 8),
                          _trafficLight(const Color(0xFFFEBC2E), null),
                          const SizedBox(width: 8),
                          _trafficLight(const Color(0xFF28C840), null),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset(
                              'assets/app_icon.png',
                              width: 32,
                              height: 32,
                              errorBuilder: (_, __, ___) => const Icon(Icons.rocket_launch_rounded, color: Color(0xFF0A84FF), size: 28),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RocketDock',
                                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Настройки панели',
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _tabs.length,
                        itemBuilder: (ctx, i) {
                          final t = _tabs[i];
                          final selected = _selectedTab == i;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = i),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF0A84FF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: selected ? Colors.white.withOpacity(0.24) : t.color,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(t.icon, color: Colors.white, size: 14.5),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        t.title,
                                        style: TextStyle(
                                          color: selected ? Colors.white : Colors.white.withOpacity(0.88),
                                          fontSize: 13,
                                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    GestureDetector(
                      onPanStart: (_) => widget.onStartWindowDrag?.call(),
                      child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C20),
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _tabs[_selectedTab].title,
                            style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF30D158).withOpacity(0.4)),
                            ),
                            child: const Text(
                              'Portable • Settings.ini',
                              style: TextStyle(color: Color(0xFF30D158), fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: _buildTabContent(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C20),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                      ),
                      child: Row(
                        children: [
                          _macSecondaryButton('По умолчанию', _resetAllDefaults),
                          const SizedBox(width: 8),
                          _macSecondaryButton('Сбросить значки', () {
                            widget.onResetDefaultItems();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Значки панели восстановлены по умолчанию')),
                            );
                          }),
                          const Spacer(),
                          _macSecondaryButton('Отмена', () => Navigator.pop(context, null)),
                          const SizedBox(width: 10),
                          _macPrimaryButton('OK', () => Navigator.pop(context, _draft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trafficLight(Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26, width: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _macSecondaryButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.11),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.7),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _macPrimaryButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2B95FF), Color(0xFF007AFF)],
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: [BoxShadow(color: const Color(0xFF0A84FF).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _macGroupCard(List<Widget> children, {String? header}) {
    final spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(Divider(height: 1, thickness: 0.7, color: Colors.white.withOpacity(0.08), indent: 14, endIndent: 14));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              header.toUpperCase(),
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF28282E),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withOpacity(0.09), width: 0.8),
          ),
          child: Column(children: spaced),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _macSwitchRow(String title, bool value, ValueChanged<bool>? onChanged, {String? subtitle}) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.w400),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.82,
            child: CupertinoSwitch(
              value: value,
              activeColor: const Color(0xFF30D158),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macDropdownRow<T>(String title, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withOpacity(0.14), width: 0.7),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isDense: true,
                value: value,
                dropdownColor: const Color(0xFF2C2C32),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                icon: const Icon(Icons.unfold_more_rounded, size: 15, color: Colors.white70),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String readout,
    required ValueChanged<double>? onChanged,
  }) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  readout,
                  style: TextStyle(
                    color: enabled ? const Color(0xFF64D2FF) : Colors.white38,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
                activeTrackColor: const Color(0xFF0A84FF),
                inactiveTrackColor: Colors.white.withOpacity(0.16),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildGeneralTab();
      case 1:
        return _buildIconsTab();
      case 2:
        return _buildPositionTab();
      case 3:
        return _buildStyleTab();
      case 4:
        return _buildBehaviorTab();
      case 5:
        return _buildAboutTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGeneralTab() {
    return Column(
      children: [
        _macGroupCard([
          _macDropdownRow<String>(
            'Язык интерфейса',
            _draft.language,
            const [
              DropdownMenuItem(value: 'Русский', child: Text('Русский')),
              DropdownMenuItem(value: 'English', child: Text('English')),
            ],
            (v) => setState(() => _draft.language = v ?? 'Русский'),
          ),
          _macSwitchRow(
            'Запускать панель при старте системы',
            _draft.startWithWindows,
            (v) => setState(() => _draft.startWithWindows = v),
          ),
          _macSwitchRow(
            'Сохранять настройки в файле "Settings.ini"',
            _draft.saveInSettingsIni,
            (v) => setState(() => _draft.saveInSettingsIni = v),
            subtitle: 'Портативный режим рядом с исполняемым файлом',
          ),
          if (widget.onImportIni != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Импорт из классического RocketDock (.ini)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        Text('Загрузить значки, команды, разделители и настройки из Settings.ini', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _macSecondaryButton('Импорт .ini...', () async {
                        await widget.onImportIni!();
                        if (mounted) Navigator.pop(context, null);
                      }),
                      if (widget.onExportIni != null) ...[
                        const SizedBox(width: 6),
                        _macSecondaryButton('Экспорт .ini...', () async {
                          await widget.onExportIni!();
                        }),
                      ],
                      if (widget.onSaveNamedProfile != null) ...[
                        const SizedBox(width: 6),
                        _macSecondaryButton('В профиль', () async {
                          await widget.onSaveNamedProfile!();
                        }),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          _macSwitchRow(
            'Сворачивать в трей при закрытии окна',
            _draft.minimizeToTrayOnClose,
            (v) => setState(() => _draft.minimizeToTrayOnClose = v),
          ),
        ], header: 'Система и портативность'),
        if (widget.profiles.isNotEmpty)
          _macGroupCard(
            widget.profiles.map((pf) {
              final pName = pf.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.ini\$', caseSensitive: false), '');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.layers_rounded, size: 15, color: Color(0xFF64D2FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(pName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                    ),
                    if (widget.onRenameProfile != null)
                      _macSecondaryButton('Переименовать', () async {
                        final ctrl = TextEditingController(text: pName);
                        final newName = await showDialog<String>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: const Color(0xFF26262C),
                            title: const Text('Имя профиля', style: TextStyle(color: Colors.white, fontSize: 15)),
                            content: TextField(
                              controller: ctrl,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx, null), child: const Text('Отмена')),
                              ElevatedButton(onPressed: () => Navigator.pop(dCtx, ctrl.text), child: const Text('OK')),
                            ],
                          ),
                        );
                        if (newName != null && newName.trim().isNotEmpty) {
                          await widget.onRenameProfile!(pf.path, newName.trim());
                          setState(() {});
                        }
                      }),
                    if (widget.onDeleteProfile != null) ...[
                      const SizedBox(width: 6),
                      _macSecondaryButton('Удалить', () async {
                        await widget.onDeleteProfile!(pf.path);
                        setState(() {});
                      }),
                    ],
                  ],
                ),
              );
            }).toList(),
            header: 'Сохранённые профили (profiles/)',
          ),
        _macGroupCard([
          _macSwitchRow(
            'Закрепить значки (защита от случайных нажатий и сдвига)',
            _draft.lockIcons,
            (v) => setState(() => _draft.lockIcons = v),
            subtitle: 'Блокирует перетаскивание и удаление значков',
          ),
          _macSwitchRow(
            'Защита от случайных нажатий',
            _draft.preventAccidentalClicks,
            (v) => setState(() => _draft.preventAccidentalClicks = v),
            subtitle: 'Игнорирует мимолётные клики и случайные двойные нажатия',
          ),
          _macSliderRow(
            label: 'Порог защиты от случайного клика',
            value: _draft.accidentalClickGuardMs.toDouble(),
            min: 120,
            max: 800,
            readout: '${_draft.accidentalClickGuardMs}ms',
            onChanged: _draft.preventAccidentalClicks
                ? (v) => setState(() => _draft.accidentalClickGuardMs = v.round())
                : null,
          ),
          _macSwitchRow(
            'Помещать минимизированные окна в панель',
            _draft.minimizeWindowsToDock,
            (v) => setState(() => _draft.minimizeWindowsToDock = v),
          ),
          _macSwitchRow(
            'Отключить анимацию сворачивания',
            _draft.disableMinimizeAnimation,
            _draft.minimizeWindowsToDock ? (v) => setState(() => _draft.disableMinimizeAnimation = v) : null,
          ),
          _macSwitchRow(
            'Отмечать в панели уже запущенные приложения',
            _draft.indicateRunningApps,
            (v) => setState(() => _draft.indicateRunningApps = v),
          ),
          _macSwitchRow(
            'Активировать запущенное приложение вместо запуска нового',
            _draft.activateRunningInstance,
            (v) => setState(() => _draft.activateRunningInstance = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Профиль «Минимум ОЗУ»', style: TextStyle(color: Colors.white, fontSize: 13)),
                      Text('Включает экономичный режим, отключает лишние виджеты и сжимает Working Set', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                _macSecondaryButton('Минимум ОЗУ', () {
                  setState(() {
                    _draft.ecoDesktopMode = true;
                    _draft.showClockAndDesktopWidgets = false;
                    _draft.showHardwareTelemetryWidgets = false;
                    _draft.showExtraSystemWidgets = false;
                    _draft.hoverZoomMode = HoverZoomMode.none;
                    _draft.clickEffect = ClickAttentionEffect.none;
                  });
                  widget.onTrimMemoryNow?.call();
                }),
              ],
            ),
          ),
          _macSwitchRow(
            'Экономичный режим (без датчиков, часов и фонового сканирования)',
            _draft.ecoDesktopMode,
            (v) => setState(() => _draft.ecoDesktopMode = v),
            subtitle: 'Отключает фоновые таймеры и опрос окон; анимация и кнопки питания сохраняются',
          ),
          _macSwitchRow(
            'Авто-экономичный режим при работе от батареи',
            _draft.autoEcoOnBattery,
            (v) => setState(() => _draft.autoEcoOnBattery = v),
            subtitle: 'Автоматически экономит заряд ноутбука при отключении сети',
          ),
          _macSwitchRow(
            'Замораживать панель при полноэкранных играх и видео',
            _draft.autoPauseOnFullscreen,
            (v) => setState(() => _draft.autoPauseOnFullscreen = v),
            subtitle: 'Приостанавливает фоновые опросы, когда активное окно развёрнуто на весь экран',
          ),
          _macSwitchRow(
            'Глобальный хоткей Ctrl+Alt+R (Win32)',
            _draft.globalHotkeysEnabled,
            (v) => setState(() => _draft.globalHotkeysEnabled = v),
            subtitle: 'Регистрирует системный хоткей переключения панели',
          ),
          _macSwitchRow(
            'Spotlight-поиск по названию и пути (Ctrl+F)',
            _draft.spotlightCommandSearch,
            (v) => setState(() => _draft.spotlightCommandSearch = v),
            subtitle: 'Ищет также по целевому пути и команде запуска',
          ),
          _macSwitchRow(
            'Показывать номера 1..9 на значках быстрого запуска',
            _draft.showQuickLaunchBadges,
            (v) => setState(() => _draft.showQuickLaunchBadges = v),
            subtitle: 'Подсказка номера слота для Alt + 1..9',
          ),
          _macSwitchRow(
            'Быстрый запуск значков по Alt + 1..9',
            _draft.altNumberQuickLaunch,
            (v) => setState(() => _draft.altNumberQuickLaunch = v),
            subtitle: 'Запускает 1–9 закреплённые программы с клавиатуры',
          ),
          _macSwitchRow(
            'Показывать виджеты «Часы» и «Рабочие столы»',
            _draft.showClockAndDesktopWidgets,
            (v) => setState(() => _draft.showClockAndDesktopWidgets = v),
            subtitle: 'Отключение останавливает таймер часов в простое',
          ),
          _macSwitchRow(
            'Показывать датчики «ОЗУ», «Температура» и «CPU»',
            _draft.showHardwareTelemetryWidgets,
            (v) => setState(() => _draft.showHardwareTelemetryWidgets = v),
            subtitle: 'Отключение снижает фоновую нагрузку на процессор',
          ),
          _macSwitchRow(
            'Показывать виджеты сети, громкости и батареи',
            _draft.showExtraSystemWidgets,
            (v) => setState(() => _draft.showExtraSystemWidgets = v),
          ),
          _macSwitchRow(
            'Показывать значки питания (Сон, Блокировка, Перезагрузка, Выключение)',
            _draft.showPowerActionIcons,
            (v) => setState(() => _draft.showPowerActionIcons = v),
          ),
          _macSwitchRow(
            'В стеке папок сначала показывать папки',
            _draft.sortFoldersFirstInStack,
            (v) => setState(() => _draft.sortFoldersFirstInStack = v),
          ),
        ], header: 'Защита нажатий и окна'),
      ],
    );
  }

  Widget _buildIconsTab() {
    return Column(
      children: [
        _macGroupCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Expanded(child: Text('Качество отображения', style: TextStyle(color: Colors.white, fontSize: 13))),
                CupertinoSlidingSegmentedControl<IconRenderQuality>(
                  groupValue: _draft.iconQuality,
                  backgroundColor: Colors.black.withOpacity(0.32),
                  thumbColor: const Color(0xFF484852),
                  children: const {
                    IconRenderQuality.low: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Низкое', style: TextStyle(fontSize: 12))),
                    IconRenderQuality.medium: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Среднее', style: TextStyle(fontSize: 12))),
                    IconRenderQuality.high: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Высокое', style: TextStyle(fontSize: 12))),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _draft.iconQuality = v);
                  },
                ),
              ],
            ),
          ),
          _macSliderRow(
            label: 'Степень непрозрачности',
            value: _draft.iconOpacity * 100,
            min: 50,
            max: 100,
            readout: '${(_draft.iconOpacity * 100).round()}%',
            onChanged: (v) => setState(() => _draft.iconOpacity = v / 100.0),
          ),
          _macSwitchRow(
            'Делать увеличенный значок полностью непрозрачным',
            _draft.fullOpacityOnHover,
            (v) => setState(() => _draft.fullOpacityOnHover = v),
          ),
          _macSliderRow(
            label: 'Первоначальный размер значка',
            value: _draft.baseIconSize,
            min: 16,
            max: 128,
            readout: '${_draft.baseIconSize.round()}px',
            onChanged: (v) => setState(() => _draft.baseIconSize = v),
          ),
          if (widget.onReextractIconsManually != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Принудительное извлечение иконок', style: TextStyle(color: Colors.white, fontSize: 13)),
                        Text('Заново вытягивает иконки напрямую из программ и ярлыков и обновляет кэш', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  _macSecondaryButton('Переизвлечь из программ', () async {
                    final count = await widget.onReextractIconsManually!();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Обновлено иконок из программ: $count')),
                      );
                      setState(() {});
                    }
                  }),
                ],
              ),
            ),
        ], header: 'Размер и рендеринг'),
        _macGroupCard([
          _macDropdownRow<HoverZoomMode>(
            'Увеличение при наведении мыши',
            _draft.hoverZoomMode,
            const [
              DropdownMenuItem(value: HoverZoomMode.none, child: Text('Без увеличения')),
              DropdownMenuItem(value: HoverZoomMode.bubble, child: Text('Увеличение "Пузырем"')),
              DropdownMenuItem(value: HoverZoomMode.plateau, child: Text('Увеличение "Плато"')),
            ],
            (v) => setState(() => _draft.hoverZoomMode = v ?? HoverZoomMode.bubble),
          ),
          _macSliderRow(
            label: 'Увеличение размера значков на',
            value: _draft.zoomDeltaPx,
            min: 1,
            max: 128,
            readout: '+${_draft.zoomDeltaPx.round()}px',
            onChanged: _draft.hoverZoomMode == HoverZoomMode.none ? null : (v) => setState(() => _draft.zoomDeltaPx = v),
          ),
          _macSliderRow(
            label: 'Количество соседних значков в волне',
            value: _draft.neighborCount.toDouble(),
            min: 2,
            max: 10,
            readout: '${_draft.neighborCount}',
            onChanged: _draft.hoverZoomMode == HoverZoomMode.none ? null : (v) => setState(() => _draft.neighborCount = v.round()),
          ),
          _macSliderRow(
            label: 'Скорость увеличения значков',
            value: _draft.zoomDurationMs,
            min: 100,
            max: 500,
            readout: '${_draft.zoomDurationMs.round()}ms',
            onChanged: _draft.hoverZoomMode == HoverZoomMode.none ? null : (v) => setState(() => _draft.zoomDurationMs = v),
          ),
        ], header: 'Анимация увеличения'),
      ],
    );
  }

  Widget _buildPositionTab() {
    return Column(
      children: [
        _macGroupCard([
          _macDropdownRow<int>(
            'Монитор',
            _draft.monitorIndex.clamp(0, 3),
            const [
              DropdownMenuItem(value: 0, child: Text('Монитор 1 (Основной)')),
              DropdownMenuItem(value: 1, child: Text('Монитор 2')),
              DropdownMenuItem(value: 2, child: Text('Монитор 3')),
              DropdownMenuItem(value: 3, child: Text('Монитор 4')),
            ],
            (v) => setState(() => _draft.monitorIndex = v ?? 0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Expanded(child: Text('Сторона экрана', style: TextStyle(color: Colors.white, fontSize: 13))),
                CupertinoSlidingSegmentedControl<DockEdge>(
                  groupValue: _draft.screenEdge,
                  backgroundColor: Colors.black.withOpacity(0.32),
                  thumbColor: const Color(0xFF484852),
                  children: const {
                    DockEdge.top: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Сверху', style: TextStyle(fontSize: 11.5))),
                    DockEdge.bottom: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Снизу', style: TextStyle(fontSize: 11.5))),
                    DockEdge.left: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Слева', style: TextStyle(fontSize: 11.5))),
                    DockEdge.right: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Справа', style: TextStyle(fontSize: 11.5))),
                  },
                  onValueChanged: (v) {
                    if (v != null) setState(() => _draft.screenEdge = v);
                  },
                ),
              ],
            ),
          ),
          _macSwitchRow(
            'Закрепить панель к выбранной стороне экрана',
            _draft.pinToScreenEdge,
            (v) => setState(() => _draft.pinToScreenEdge = v),
            subtitle: 'Фиксирует док на краю экрана и запрещает случайное перетаскивание мышью',
          ),
          _macDropdownRow<DockLayering>(
            'Располагать панель',
            _draft.layering,
            const [
              DropdownMenuItem(value: DockLayering.onDesktop, child: Text('На Рабочем Столе')),
              DropdownMenuItem(value: DockLayering.normal, child: Text('Обычное')),
              DropdownMenuItem(value: DockLayering.alwaysOnTop, child: Text('Поверх всех окон')),
            ],
            (v) => setState(() => _draft.layering = v ?? DockLayering.normal),
          ),
        ], header: 'Привязка к сторонам экрана'),
        _macGroupCard([
          _macSliderRow(
            label: 'Смещение вдоль стороны экрана',
            value: _draft.edgeCenterOffsetPercent,
            min: -100,
            max: 100,
            readout: '${_draft.edgeCenterOffsetPercent.round()}%',
            onChanged: (v) => setState(() => _draft.edgeCenterOffsetPercent = v),
          ),
          _macSliderRow(
            label: 'Отступ от стороны экрана',
            value: _draft.edgeDistancePx,
            min: -15,
            max: 128,
            readout: '${_draft.edgeDistancePx.round()}px',
            onChanged: (v) => setState(() => _draft.edgeDistancePx = v),
          ),
          _macSliderRow(
            label: 'Количество рядов значков',
            value: _draft.rowCount.toDouble(),
            min: 1,
            max: 3,
            readout: '${_draft.rowCount}',
            onChanged: (v) => setState(() => _draft.rowCount = v.round()),
          ),
        ], header: 'Отступы и сетка'),
      ],
    );
  }

  Widget _buildStyleTab() {
    final shadowColor = Color(_draft.labelShadowColorValue).withOpacity(_draft.labelShadowOpacity);
    final outlineColor = Color(_draft.labelOutlineColorValue).withOpacity(_draft.labelOutlineOpacity);

    return Column(
      children: [
        _macGroupCard([
          _macDropdownRow<String>(
            'Тема оформления',
            _themes.contains(_draft.themeName) ? _draft.themeName : _themes.first,
            _themes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            (v) => setState(() => _draft.themeName = v ?? 'macOS Sonoma Glass'),
          ),
          _macSliderRow(
            label: 'Степень непрозрачности панели',
            value: _draft.panelOpacity * 100,
            min: 0,
            max: 100,
            readout: '${(_draft.panelOpacity * 100).round()}%',
            onChanged: (v) => setState(() => _draft.panelOpacity = v / 100.0),
          ),
          _macSwitchRow(
            'Не показывать подписи к значкам',
            _draft.hideIconLabels,
            (v) => setState(() => _draft.hideIconLabels = v),
          ),
        ], header: 'Оформление панели'),
        _macGroupCard([
          _macDropdownRow<String>(
            'Шрифт подписей',
            _fonts.contains(_draft.labelFontFamily) ? _draft.labelFontFamily : 'Segoe UI',
            _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontFamily: f)))).toList(),
            _draft.hideIconLabels ? null : (v) => setState(() => _draft.labelFontFamily = v ?? 'Segoe UI'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Цвет тени', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: _swatches.map((c) {
                          final active = _draft.labelShadowColorValue == c.value;
                          return GestureDetector(
                            onTap: () => setState(() => _draft.labelShadowColorValue = c.value),
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: active ? const Color(0xFF0A84FF) : Colors.white38, width: active ? 2.2 : 1),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      const Text('Цвет обводки', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: _swatches.map((c) {
                          final active = _draft.labelOutlineColorValue == c.value;
                          return GestureDetector(
                            onTap: () => setState(() => _draft.labelOutlineColorValue = c.value),
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: active ? const Color(0xFF0A84FF) : Colors.white38, width: active ? 2.2 : 1),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 190,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Предпросмотр',
                        style: TextStyle(
                          fontFamily: _draft.labelFontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2.8
                            ..color = outlineColor,
                        ),
                      ),
                      Text(
                        'Предпросмотр',
                        style: TextStyle(
                          fontFamily: _draft.labelFontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: shadowColor, blurRadius: 4, offset: const Offset(1.5, 2.0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _macSliderRow(
            label: 'Непрозрачность обводки',
            value: _draft.labelOutlineOpacity * 100,
            min: 0,
            max: 100,
            readout: '${(_draft.labelOutlineOpacity * 100).round()}%',
            onChanged: _draft.hideIconLabels ? null : (v) => setState(() => _draft.labelOutlineOpacity = v / 100.0),
          ),
          _macSliderRow(
            label: 'Непрозрачность тени',
            value: _draft.labelShadowOpacity * 100,
            min: 0,
            max: 100,
            readout: '${(_draft.labelShadowOpacity * 100).round()}%',
            onChanged: _draft.hideIconLabels ? null : (v) => setState(() => _draft.labelShadowOpacity = v / 100.0),
          ),
        ], header: 'Подписи значков'),
      ],
    );
  }

  Widget _buildBehaviorTab() {
    return Column(
      children: [
        _macGroupCard([
          _macDropdownRow<ClickAttentionEffect>(
            'Эффект при выборе значка',
            _draft.clickEffect,
            const [
              DropdownMenuItem(value: ClickAttentionEffect.none, child: Text('Нет')),
              DropdownMenuItem(value: ClickAttentionEffect.bounce, child: Text('Подпрыгивание')),
              DropdownMenuItem(value: ClickAttentionEffect.pulse, child: Text('Пульсация')),
              DropdownMenuItem(value: ClickAttentionEffect.spin, child: Text('Вращение')),
            ],
            (v) => setState(() => _draft.clickEffect = v ?? ClickAttentionEffect.bounce),
          ),
          _macSwitchRow(
            'Звуковой отклик при нажатии',
            _draft.soundEffectsEnabled,
            (v) => setState(() => _draft.soundEffectsEnabled = v),
          ),
        ], header: 'Отклик при клике'),
        _macGroupCard([
          _macSwitchRow(
            'Автоматически прятать панель',
            _draft.autoHide,
            (v) => setState(() => _draft.autoHide = v),
          ),
          _macSliderRow(
            label: 'Прятать панель в течение',
            value: _draft.autoHideDurationMs,
            min: 0,
            max: 1000,
            readout: '${_draft.autoHideDurationMs.round()}ms',
            onChanged: _draft.autoHide ? (v) => setState(() => _draft.autoHideDurationMs = v) : null,
          ),
          _macSliderRow(
            label: 'Прятать панель через',
            value: _draft.autoHideDelayMs,
            min: 0,
            max: 2000,
            readout: '${_draft.autoHideDelayMs.round()}ms',
            onChanged: _draft.autoHide ? (v) => setState(() => _draft.autoHideDurationMs = v) : null,
          ),
        ], header: 'Автоскрытие'),
        _macGroupCard([
          _macSwitchRow(
            'При активации панели, выводить ее поверх всех окон',
            _draft.popupOnMouseover,
            (v) => setState(() => _draft.popupOnMouseover = v),
          ),
          _macSliderRow(
            label: 'Задержка перед выводом поверх окон',
            value: _draft.popupDelayMs,
            min: 0,
            max: 1000,
            readout: '${_draft.popupDelayMs.round()}ms',
            onChanged: _draft.popupOnMouseover ? (v) => setState(() => _draft.popupDelayMs = v) : null,
          ),
        ], header: 'Всплывание при наведении'),
      ],
    );
  }

  Widget _buildAboutTab() {
    return Column(
      children: [
        _macGroupCard([
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/app_icon.png', width: 56, height: 56, errorBuilder: (_, __, ___) => const Icon(Icons.rocket_launch_rounded, size: 48)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RocketDock Portable macOS Edition', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text('Версия 2.6.3 • Movable Settings & Normal Z-Order', style: TextStyle(color: Color(0xFF64D2FF), fontSize: 12.5, fontWeight: FontWeight.w500)),
                      SizedBox(height: 3),
                      Text('Чёткие иконки • 2D-наведение по рядам • Импорт Settings.ini', style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
        _macGroupCard([
          _infoRow('Папка программы', PortableStorage.appDir),
          _infoRow('Файл конфигурации', PortableStorage.iniFile.path),
          _infoRow('Кэш HD-иконок', PortableStorage.iconsCacheDir.path),
          _infoRow('Элементов на панели', '${widget.itemCount}'),
        ], header: 'Инф. для отладки'),
        _macGroupCard([
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Монитор нагрузки и процессов', style: TextStyle(color: Color(0xFF30D158), fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (widget.onTrimMemoryNow != null)
                      _macSecondaryButton('Сжать ОЗУ', () {
                        widget.onTrimMemoryNow!();
                        setState(() {});
                      }),
                    if (widget.onCleanDiskIconCache != null) ...[
                      const SizedBox(width: 6),
                      _macSecondaryButton('Очистить кэш', () async {
                        final msg = await widget.onCleanDiskIconCache!();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          setState(() {});
                        }
                      }),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    widget.onCollectDiagnostics != null
                        ? widget.onCollectDiagnostics!()
                        : 'Диагностика недоступна.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontFamily: 'Consolas', height: 1.4),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _macSecondaryButton('Обновить', () => setState(() {})),
                    const SizedBox(width: 6),
                    if (widget.onCollectDiagnostics != null)
                      _macSecondaryButton('Скопировать диагностику', () {
                        Clipboard.setData(ClipboardData(text: widget.onCollectDiagnostics!()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Сводка диагностики скопирована в буфер обмена')),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ], header: 'Ресурсы и процессы'),
        _macGroupCard([
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Диагностика импорта INI', style: TextStyle(color: Color(0xFF64D2FF), fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (widget.onClearDebugLog != null)
                      _macSecondaryButton('Очистить лог', () {
                        widget.onClearDebugLog!();
                        setState(() {});
                      }),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    widget.lastDebugLog.isEmpty
                        ? 'Лог импорта пока пуст. Нажмите «Импорт .ini...» в разделе «Общие».'
                        : widget.lastDebugLog,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontFamily: 'Consolas', height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ], header: 'Отладка импорта'),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 145, child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ),
    );
  }
}
