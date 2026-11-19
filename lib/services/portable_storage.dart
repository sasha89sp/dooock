import 'dart:convert';
import 'dart:io';

import '../models/dock_models.dart';

class IniImportResult {
  final DockSettings settings;
  final List<DockItemData> items;
  final int importedCount;
  final String debugLog;

  const IniImportResult({
    required this.settings,
    required this.items,
    required this.importedCount,
    required this.debugLog,
  });
}

class PortableStorage {
  static String get appDir {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      if (Directory(exeDir).existsSync()) {
        return exeDir;
      }
    } catch (_) {}
    return Directory.current.path;
  }

  static File get iniFile => File('$appDir${Platform.pathSeparator}Settings.ini');
  static File get jsonFile => File('$appDir${Platform.pathSeparator}config.json');
  static File get importDebugLogFile => File('$appDir${Platform.pathSeparator}ini_import_debug.log');

  static Directory get iconsCacheDir {
    final dir = Directory('$appDir${Platform.pathSeparator}icons_cache');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  static Future<IniImportResult?> load() async {
    try {
      if (await iniFile.exists()) {
        final bytes = await iniFile.readAsBytes();
        final decoded = _decodeBytesSmart(bytes);
        final parsed = parseIniString(
          decoded.text,
          baseSettings: DockSettings(),
          sourceLabel: '${iniFile.path} (${decoded.encoding})',
        );
        if (parsed != null) return parsed;
      }
      if (await jsonFile.exists()) {
        final raw = await jsonFile.readAsString();
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          final settings = DockSettings.fromMap(map['settings'] is Map<String, dynamic> ? map['settings'] : map);
          final rawItems = map['items'];
          final items = rawItems is List
              ? rawItems.whereType<Map<String, dynamic>>().map(DockItemData.fromJson).toList()
              : <DockItemData>[];
          return IniImportResult(
            settings: settings,
            items: items,
            importedCount: items.length,
            debugLog: 'Загружен JSON: ${jsonFile.path}, элементов: ${items.length}',
          );
        }
      }
    } catch (e) {
      await _writeDebugLog('Ошибка автозагрузки: $e');
    }
    return null;
  }

  static Future<IniImportResult?> importFromExternalIni(
    String iniPath, {
    required DockSettings currentSettings,
  }) async {
    final logBuf = StringBuffer();
    logBuf.writeln('=== RocketDock INI Import Debug ===');
    logBuf.writeln('Файл: $iniPath');
    try {
      final file = File(iniPath);
      final exists = await file.exists();
      logBuf.writeln('Существует: $exists');
      if (!exists) {
        logBuf.write('Причина: файл не найден по указанному пути.');
        await _writeDebugLog(logBuf.toString());
        return null;
      }

      final bytes = await file.readAsBytes();
      logBuf.writeln('Размер файла: ${bytes.length} байт');
      if (bytes.isEmpty) {
        logBuf.write('Причина: файл пустой (0 байт).');
        await _writeDebugLog(logBuf.toString());
        return null;
      }

      final decoded = _decodeBytesSmart(bytes);
      logBuf.writeln('Кодировка: ${decoded.encoding}, строк: ${decoded.text.split(RegExp(r'\r?\n')).length}');

      final parsed = parseIniString(
        decoded.text,
        baseSettings: currentSettings,
        sourceLabel: '$iniPath (${decoded.encoding})',
        extraTrace: logBuf.toString(),
      );

      if (parsed == null) {
        logBuf.write('Причина: парсер не нашёл валидных секций RocketDock ([Software\\RocketDock], [Software\\RocketDock\\Icons], [RocketDock] или [Items]).');
        await _writeDebugLog(logBuf.toString());
        return null;
      }

      await _writeDebugLog(parsed.debugLog);
      return parsed;
    } catch (e, st) {
      logBuf.writeln('Исключение при чтении/парсинге: $e');
      logBuf.writeln(st);
      await _writeDebugLog(logBuf.toString());
      return null;
    }
  }

  static Future<void> _writeDebugLog(String text) async {
    try {
      await importDebugLogFile.writeAsString(text);
    } catch (_) {}
  }

  static ({String text, String encoding}) _decodeBytesSmart(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return (text: _decodeUtf16Le(bytes.sublist(2)), encoding: 'UTF-16 LE BOM');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return (text: _decodeUtf16Be(bytes.sublist(2)), encoding: 'UTF-16 BE BOM');
    }
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return (text: utf8.decode(bytes.sublist(3), allowMalformed: true), encoding: 'UTF-8 BOM');
    }
    int zeroOdd = 0;
    final sampleLen = bytes.length < 200 ? bytes.length : 200;
    for (int i = 1; i < sampleLen; i += 2) {
      if (bytes[i] == 0) zeroOdd++;
    }
    if (sampleLen >= 10 && zeroOdd > (sampleLen ~/ 4) * 0.6) {
      return (text: _decodeUtf16Le(bytes), encoding: 'UTF-16 LE');
    }

    try {
      return (text: utf8.decode(bytes, allowMalformed: false), encoding: 'UTF-8');
    } catch (_) {
      return (text: _decodeWindows1251(bytes), encoding: 'Windows-1251');
    }
  }

  static String _decodeUtf16Le(List<int> bytes) {
    final chars = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      if (code != 0) chars.add(code);
    }
    return String.fromCharCodes(chars);
  }

  static String _decodeUtf16Be(List<int> bytes) {
    final chars = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final code = (bytes[i] << 8) | bytes[i + 1];
      if (code != 0) chars.add(code);
    }
    return String.fromCharCodes(chars);
  }

  static String _decodeWindows1251(List<int> bytes) {
    const cp1251High = <int, int>{
      0x80: 0x0402, 0x81: 0x0403, 0x82: 0x201A, 0x83: 0x0453, 0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021,
      0x88: 0x20AC, 0x89: 0x2030, 0x8A: 0x0409, 0x8B: 0x2039, 0x8C: 0x040A, 0x8D: 0x040C, 0x8E: 0x040B, 0x8F: 0x040F,
      0x90: 0x0452, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
      0x99: 0x2122, 0x9A: 0x0459, 0x9B: 0x203A, 0x9C: 0x045A, 0x9D: 0x045C, 0x9E: 0x045B, 0x9F: 0x045F,
      0xA0: 0x00A0, 0xA1: 0x040E, 0xA2: 0x045E, 0xA3: 0x0408, 0xA4: 0x00A4, 0xA5: 0x0490, 0xA6: 0x00A6, 0xA7: 0x00A7,
      0xA8: 0x0401, 0xA9: 0x00A9, 0xAA: 0x0404, 0xAB: 0x00AB, 0xAC: 0x00AC, 0xAD: 0x00AD, 0xAE: 0x00AE, 0xAF: 0x0407,
      0xB0: 0x00B0, 0xB1: 0x00B1, 0xB2: 0x0406, 0xB3: 0x0456, 0xB4: 0x0491, 0xB5: 0x00B5, 0xB6: 0x00B6, 0xB7: 0x00B7,
      0xB8: 0x0451, 0xB9: 0x2116, 0xBA: 0x0454, 0xBB: 0x00BB, 0xBC: 0x0458, 0xBD: 0x0405, 0xBE: 0x0455, 0xBF: 0x0457,
    };
    final out = <int>[];
    for (final b in bytes) {
      if (b < 0x80) {
        out.add(b);
      } else if (b >= 0xC0 && b <= 0xFF) {
        out.add(0x0410 + (b - 0xC0));
      } else if (cp1251High.containsKey(b)) {
        out.add(cp1251High[b]!);
      } else {
        out.add(b);
      }
    }
    return String.fromCharCodes(out);
  }



  static Directory get profilesDir {
    final dir = Directory('$appDir${Platform.pathSeparator}profiles');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  static Future<List<File>> listSavedProfiles() async {
    try {
      final dir = profilesDir;
      if (!await dir.exists()) return const [];
      final files = await dir
          .list()
          .where((e) => e is File && e.path.toLowerCase().endsWith('.ini'))
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      return files;
    } catch (_) {
      return const [];
    }
  }


  static Future<({int removedFiles, double freedKb})> cleanOrphanedIconCache(Set<String> activePaths) async {
    int removed = 0;
    int freedBytes = 0;
    try {
      final dir = iconsCacheDir;
      if (!await dir.exists()) return (removedFiles: 0, freedKb: 0.0);
      final normalizedActive = activePaths.map((p) => p.toLowerCase()).toSet();
      await for (final entity in dir.list()) {
        if (entity is File) {
          if (!normalizedActive.contains(entity.path.toLowerCase())) {
            try {
              final len = await entity.length();
              await entity.delete();
              removed++;
              freedBytes += len;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return (removedFiles: removed, freedKb: freedBytes / 1024.0);
  }



  static Future<bool> deleteProfileFile(String profilePath) async {
    try {
      final f = File(profilePath);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<File?> renameProfileFile(String profilePath, String newBaseName) async {
    try {
      final cleaned = newBaseName.trim().replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
      if (cleaned.isEmpty) return null;
      final f = File(profilePath);
      if (!await f.exists()) return null;
      final dirPath = f.parent.path;
      final targetName = cleaned.toLowerCase().endsWith('.ini') ? cleaned : '$cleaned.ini';
      final targetPath = '$dirPath${Platform.pathSeparator}$targetName';
      if (targetPath.toLowerCase() == f.path.toLowerCase()) return f;
      final renamed = await f.rename(targetPath);
      return renamed;
    } catch (_) {
      return null;
    }
  }

  static Future<IniImportResult?> loadProfileFromFile(
    String profilePath, {
    required DockSettings baseSettings,
  }) async {
    try {
      final file = File(profilePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final decoded = _decodeBytesSmart(bytes);
      return parseIniString(
        decoded.text,
        baseSettings: baseSettings,
        sourceLabel: '${file.path} (${decoded.encoding})',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exportProfileIni(
    String targetPath,
    DockSettings settings,
    List<DockItemData> items,
  ) async {
    try {
      final file = File(targetPath);
      await file.writeAsString(_serializeIni(settings, items));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> save(DockSettings settings, List<DockItemData> items) async {
    try {
      if (settings.saveInSettingsIni) {
        await iniFile.writeAsString(_serializeIni(settings, items));
      }
      const encoder = JsonEncoder.withIndent('  ');
      await jsonFile.writeAsString(encoder.convert({
        'portable': true,
        'version': '2.5.8',
        'settings': settings.toMap(),
        'items': items.map((e) => e.toJson()).toList(),
      }));
    } catch (_) {}
  }

  static String _serializeIni(DockSettings s, List<DockItemData> items) {
    final buf = StringBuffer();
    buf.writeln('; RocketDock Portable Settings.ini');
    buf.writeln('[RocketDock]');
    final map = s.toMap();
    map.forEach((k, v) {
      buf.writeln('$k=$v');
    });
    buf.writeln();
    buf.writeln('[Items]');
    buf.writeln('Count=${items.length}');
    for (int i = 0; i < items.length; i++) {
      buf.writeln('Item_$i=${jsonEncode(items[i].toJson())}');
    }
    return buf.toString();
  }

  static IniImportResult? parseIniString(
    String raw, {
    required DockSettings baseSettings,
    String sourceLabel = 'memory',
    String? extraTrace,
  }) {
    final trace = StringBuffer();
    if (extraTrace != null && extraTrace.isNotEmpty) {
      trace.write(extraTrace);
    } else {
      trace.writeln('=== RocketDock INI Parse Trace ===');
      trace.writeln('Источник: $sourceLabel');
    }

    try {
      final settingsMap = <String, dynamic>{};
      final v2Items = <DockItemData>[];
      final classicIconProps = <int, Map<String, String>>{};
      int classicCount = 0;
      int skippedLines = 0;
      int parsedKeyValues = 0;
      bool isClassicRocketDock = false;
      final sectionsSeen = <String>{};

      String section = '';
      final lines = raw.split(RegExp(r'\r?\n'));
      for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
        final trimmed = lines[lineIdx].trim();
        if (trimmed.isEmpty || trimmed.startsWith(';') || trimmed.startsWith('#')) {
          continue;
        }
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          section = trimmed.substring(1, trimmed.length - 1).trim();
          sectionsSeen.add(section);
          if (section.toLowerCase().contains('rocketdock')) {
            isClassicRocketDock = true;
          }
          continue;
        }
        final eq = trimmed.indexOf('=');
        if (eq <= 0) {
          skippedLines++;
          continue;
        }
        final key = trimmed.substring(0, eq).trim();
        final val = trimmed.substring(eq + 1).trim();
        parsedKeyValues++;

        final lowerSection = section.toLowerCase();
        if (lowerSection == 'rocketdock') {
          if (val == 'true') {
            settingsMap[key] = true;
          } else if (val == 'false') {
            settingsMap[key] = false;
          } else if (int.tryParse(val) != null) {
            settingsMap[key] = int.parse(val);
          } else if (double.tryParse(val) != null) {
            settingsMap[key] = double.parse(val);
          } else {
            settingsMap[key] = val;
          }
        } else if (lowerSection == 'items' && key.toLowerCase().startsWith('item_')) {
          final decoded = jsonDecode(val);
          if (decoded is Map<String, dynamic>) {
            v2Items.add(DockItemData.fromJson(decoded));
          }
        } else if (lowerSection == r'software\rocketdock') {
          isClassicRocketDock = true;
          _mapClassicSettingKey(key, val, settingsMap);
        } else if (lowerSection == r'software\rocketdock\icons') {
          isClassicRocketDock = true;
          if (key.toLowerCase() == 'count') {
            classicCount = int.tryParse(val) ?? 0;
          } else {
            final dashIdx = key.indexOf('-');
            if (dashIdx > 0) {
              final idx = int.tryParse(key.substring(0, dashIdx));
              final prop = key.substring(dashIdx + 1);
              if (idx != null) {
                classicIconProps.putIfAbsent(idx, () => <String, String>{})[prop] = val;
              }
            }
          }
        } else if (section.isEmpty && key.toLowerCase().endsWith('-command')) {
          isClassicRocketDock = true;
          final dashIdx = key.indexOf('-');
          final idx = int.tryParse(key.substring(0, dashIdx));
          if (idx != null) {
            classicIconProps.putIfAbsent(idx, () => <String, String>{})['Command'] = val;
          }
        }
      }

      trace.writeln('Найдено секций: ${sectionsSeen.isEmpty ? "(нет)" : sectionsSeen.join(", ")}');
      trace.writeln('Разобрано пар ключ=значение: $parsedKeyValues, пропущено строк: $skippedLines');

      if (isClassicRocketDock || classicIconProps.isNotEmpty) {
        final mergedMap = baseSettings.toMap()..addAll(settingsMap);
        final parsedSettings = DockSettings.fromMap(mergedMap);
        final iniDir = sourceLabel.contains(Platform.pathSeparator)
            ? File(sourceLabel.split(' (').first).parent.path
            : appDir;
        final importedItems = _convertClassicIcons(classicIconProps, classicCount, trace, iniDir: iniDir);
        trace.writeln('Итог импорта (Classic INI): ${importedItems.length} элементов (Count=$classicCount).');
        return IniImportResult(
          settings: parsedSettings,
          items: importedItems,
          importedCount: importedItems.length,
          debugLog: trace.toString(),
        );
      }

      if (settingsMap.isEmpty && v2Items.isEmpty) {
        trace.writeln('Результат: секции RocketDock не найдены.');
        return null;
      }
      final mergedMap = baseSettings.toMap()..addAll(settingsMap);
      trace.writeln('Итог импорта (v2 INI): ${v2Items.length} элементов.');
      return IniImportResult(
        settings: DockSettings.fromMap(mergedMap),
        items: v2Items,
        importedCount: v2Items.length,
        debugLog: trace.toString(),
      );
    } catch (e, st) {
      trace.writeln('Ошибка разбора INI: $e');
      trace.writeln(st);
      return null;
    }
  }

  static void _mapClassicSettingKey(String key, String val, Map<String, dynamic> out) {
    final intVal = int.tryParse(val);
    switch (key) {
      case 'Theme':
        if (val.isNotEmpty) out['themeName'] = val;
        break;
      case 'ThemeOpacity':
        if (intVal != null) out['panelOpacity'] = (intVal / 100.0).clamp(0.0, 1.0);
        break;
      case 'IconOpacity':
        if (intVal != null) out['iconOpacity'] = (intVal / 100.0).clamp(0.5, 1.0);
        break;
      case 'FontSize':
        if (intVal != null) out['labelFontSize'] = intVal.abs().toDouble().clamp(9.0, 24.0);
        break;
      case 'FontFlags':
        if (intVal != null) out['labelFontBold'] = (intVal & 1) != 0;
        break;
      case 'FontName':
        if (val.isNotEmpty) out['labelFontFamily'] = val;
        break;
      case 'FontOutlineOpacity':
        if (intVal != null) out['labelOutlineOpacity'] = (intVal / 100.0).clamp(0.0, 1.0);
        break;
      case 'FontShadowOpacity':
        if (intVal != null) out['labelShadowOpacity'] = (intVal / 100.0).clamp(0.0, 1.0);
        break;
      case 'IconMin':
        if (intVal != null) out['baseIconSize'] = intVal.toDouble().clamp(16.0, 128.0);
        break;
      case 'IconMax':
        if (intVal != null && out['baseIconSize'] != null) {
          final base = (out['baseIconSize'] as double);
          out['zoomDeltaPx'] = (intVal.toDouble() - base).clamp(4.0, 128.0);
        }
        break;
      case 'ZoomTicks':
        if (intVal != null) out['zoomDurationMs'] = intVal.toDouble().clamp(100.0, 500.0);
        break;
      case 'AutoHideTicks':
        if (intVal != null) out['autoHideDurationMs'] = intVal.toDouble().clamp(0.0, 1000.0);
        break;
      case 'AutoHideDelay':
        if (intVal != null) out['autoHideDelayMs'] = intVal.toDouble().clamp(0.0, 2000.0);
        break;
      case 'PopupDelay':
        if (intVal != null) out['popupDelayMs'] = intVal.toDouble().clamp(0.0, 1000.0);
        break;
      case 'IconQuality':
        if (intVal != null) {
          out['iconQuality'] = intVal <= 0
              ? IconRenderQuality.low.name
              : (intVal == 1 ? IconRenderQuality.medium.name : IconRenderQuality.high.name);
        }
        break;
      case 'HideLabels':
        if (intVal != null) out['hideIconLabels'] = intVal != 0;
        break;
      case 'ZoomOpaque':
        if (intVal != null) out['fullOpacityOnHover'] = intVal != 0;
        break;
      case 'LockIcons':
        if (intVal != null) out['lockIcons'] = intVal != 0;
        break;
      case 'AutoHide':
        if (intVal != null) out['autoHide'] = intVal != 0;
        break;
      case 'ManageWindows':
        if (intVal != null) out['minimizeWindowsToDock'] = intVal != 0;
        break;
      case 'DisableMinAnimation':
        if (intVal != null) out['disableMinimizeAnimation'] = intVal != 0;
        break;
      case 'ShowRunning':
        if (intVal != null) out['indicateRunningApps'] = intVal != 0;
        break;
      case 'OpenRunning':
        if (intVal != null) out['activateRunningInstance'] = intVal != 0;
        break;
      case 'HoverFX':
        if (intVal != null) {
          out['hoverZoomMode'] = intVal == 0 ? HoverZoomMode.none.name : HoverZoomMode.bubble.name;
        }
        break;
      case 'zOrderMode':
        if (intVal != null) {
          out['layering'] = intVal == 2
              ? DockLayering.alwaysOnTop.name
              : (intVal == 1 ? DockLayering.onDesktop.name : DockLayering.normal.name);
        }
        break;
      case 'IconActivationFX':
        if (intVal != null) {
          out['clickEffect'] = intVal == 0 ? ClickAttentionEffect.none.name : ClickAttentionEffect.bounce.name;
        }
        break;
      case 'Monitor':
        if (intVal != null) out['monitorIndex'] = (intVal - 1).clamp(0, 3);
        break;
      case 'Side':
        if (intVal != null) {
          switch (intVal) {
            case 0:
              out['screenEdge'] = DockEdge.top.name;
              break;
            case 1:
              out['screenEdge'] = DockEdge.bottom.name;
              break;
            case 2:
              out['screenEdge'] = DockEdge.left.name;
              break;
            case 3:
              out['screenEdge'] = DockEdge.right.name;
              break;
          }
        }
        break;
      case 'Offset':
        if (intVal != null) out['edgeCenterOffsetPercent'] = intVal.toDouble().clamp(-100.0, 100.0);
        break;
      case 'vOffset':
        if (intVal != null) out['edgeDistancePx'] = intVal.toDouble().clamp(-15.0, 128.0);
        break;
    }
  }

  static String _expandEnvVars(String input) {
    var out = input.trim();
    if (out.length >= 2 && out.startsWith('"') && out.endsWith('"')) {
      out = out.substring(1, out.length - 1).trim();
    }
    if (!out.contains('%')) return out;
    return out.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
      final key = m.group(1) ?? '';
      final envVal = Platform.environment[key] ??
          Platform.environment[key.toUpperCase()] ??
          Platform.environment[key.toLowerCase()];
      return envVal ?? m.group(0)!;
    });
  }

  static List<DockItemData> _convertClassicIcons(
    Map<int, Map<String, String>> propsMap,
    int count,
    StringBuffer trace, {
    String iniDir = '',
  }) {
    final result = <DockItemData>[];
    final maxIdx = count > 0
        ? count
        : (propsMap.keys.isEmpty ? 0 : (propsMap.keys.reduce((a, b) => a > b ? a : b) + 1));

    int sepCount = 0;
    int missingCmdCount = 0;

    for (int i = 0; i < maxIdx; i++) {
      final p = propsMap[i];
      if (p == null) continue;

      final isSep = (p['IsSeparator'] ?? '0') == '1';
      if (isSep) {
        sepCount++;
        result.add(DockItemData(
          id: 'ini_sep_$i',
          title: 'Разделитель',
          iconName: '',
          targetPath: '',
          isSeparator: true,
        ));
        continue;
      }

      final rawTitle = _expandEnvVars(p['Title'] ?? '');
      final rawCmd = _expandEnvVars(p['Command'] ?? '');
      final rawArgs = _expandEnvVars(p['Arguments'] ?? '');
      final rawWorkDir = _expandEnvVars(p['WorkingDirectory'] ?? '');
      final rawFileName = _expandEnvVars(p['FileName'] ?? '');

      if (rawCmd.isEmpty) {
        missingCmdCount++;
      }

      String cleanIconFile = rawFileName;
      final qIdx = cleanIconFile.indexOf('?');
      if (qIdx != -1) {
        cleanIconFile = cleanIconFile.substring(0, qIdx).trim();
      }

      String mappedTarget = rawCmd;
      String mappedIcon = 'custom';
      bool isFolder = false;

      if (rawCmd.toLowerCase() == '[recyclebin]') {
        mappedTarget = 'shell:RecycleBinFolder';
        mappedIcon = 'recycle';
      } else if (rawCmd.startsWith('::{')) {
        mappedTarget = 'shell:$rawCmd';
        mappedIcon = 'explorer';
      } else if (rawCmd.isNotEmpty && !rawCmd.toLowerCase().endsWith('.exe') && !rawCmd.contains('.')) {
        isFolder = true;
        mappedIcon = 'folder';
      }

      final title = rawTitle.isNotEmpty
          ? rawTitle
          : (mappedTarget.isNotEmpty
              ? mappedTarget.split(RegExp(r'[/\\]')).last.replaceAll(RegExp(r'\.exe$', caseSensitive: false), '')
              : 'Элемент $i');

      String customImg = '';
      if (cleanIconFile.isNotEmpty) {
        String candidate = cleanIconFile;
        if (!candidate.contains(':') && !candidate.startsWith(r'\\') && iniDir.isNotEmpty) {
          final relCandidate = '$iniDir${Platform.pathSeparator}$candidate';
          if (File(relCandidate).existsSync()) {
            candidate = relCandidate;
          }
        }
        final lowerImg = candidate.toLowerCase();
        if ((lowerImg.endsWith('.png') ||
                lowerImg.endsWith('.jpg') ||
                lowerImg.endsWith('.jpeg') ||
                lowerImg.endsWith('.bmp')) &&
            File(candidate).existsSync()) {
          customImg = candidate;
        }
      }

      result.add(DockItemData(
        id: 'ini_item_${i}_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        iconName: mappedIcon,
        customIconPath: customImg,
        targetPath: mappedTarget,
        arguments: rawArgs,
        workingDirectory: rawWorkDir,
        isFolderStack: isFolder,
      ));
    }

    trace.writeln('Детали иконок: разделителей=$sepCount, без Command=$missingCmdCount, всего импортировано=${result.length}');
    return result;
  }
}
