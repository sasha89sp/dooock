import 'package:flutter/material.dart';

enum DockEdge { top, bottom, left, right }

enum DockLayering { onDesktop, normal, alwaysOnTop }

enum IconRenderQuality { low, medium, high }

enum HoverZoomMode { none, bubble, plateau }

enum ClickAttentionEffect { none, bounce, pulse, spin }

class DockSettings {
  String language;
  bool startWithWindows;
  bool saveInSettingsIni;
  bool minimizeWindowsToDock;
  bool disableMinimizeAnimation;
  bool indicateRunningApps;
  bool activateRunningInstance;
  bool lockIcons;
  bool preventAccidentalClicks;
  int accidentalClickGuardMs;
  bool minimizeToTrayOnClose;

  IconRenderQuality iconQuality;
  double iconOpacity;
  bool fullOpacityOnHover;
  double baseIconSize;
  HoverZoomMode hoverZoomMode;
  double zoomDeltaPx;
  int neighborCount;
  double zoomDurationMs;

  int monitorIndex;
  DockEdge screenEdge;
  bool pinToScreenEdge;
  DockLayering layering;
  double edgeCenterOffsetPercent;
  double edgeDistancePx;

  String themeName;
  double panelOpacity;
  bool hideIconLabels;
  String labelFontFamily;
  double labelFontSize;
  bool labelFontBold;
  int labelShadowColorValue;
  int labelOutlineColorValue;
  double labelOutlineOpacity;
  double labelShadowOpacity;

  ClickAttentionEffect clickEffect;
  bool autoHide;
  double autoHideDurationMs;
  double autoHideDelayMs;
  bool popupOnMouseover;
  double popupDelayMs;

  bool soundEffectsEnabled;
  bool autoExtractExeIcons;
  int rowCount;
  bool ecoDesktopMode;
  bool autoEcoOnBattery;
  bool autoPauseOnFullscreen;
  bool altNumberQuickLaunch;
  bool showClockAndDesktopWidgets;
  bool showHardwareTelemetryWidgets;
  bool showExtraSystemWidgets;
  bool showPowerActionIcons;
  bool sortFoldersFirstInStack;

  DockSettings({
    this.language = 'Русский',
    this.startWithWindows = false,
    this.saveInSettingsIni = true,
    this.minimizeWindowsToDock = false,
    this.disableMinimizeAnimation = true,
    this.indicateRunningApps = true,
    this.activateRunningInstance = true,
    this.lockIcons = false,
    this.preventAccidentalClicks = true,
    this.accidentalClickGuardMs = 260,
    this.minimizeToTrayOnClose = true,
    this.iconQuality = IconRenderQuality.high,
    this.iconOpacity = 1.0,
    this.fullOpacityOnHover = true,
    this.baseIconSize = 46.0,
    this.hoverZoomMode = HoverZoomMode.bubble,
    this.zoomDeltaPx = 24.0,
    this.neighborCount = 3,
    this.zoomDurationMs = 180.0,
    this.monitorIndex = 0,
    this.screenEdge = DockEdge.bottom,
    this.pinToScreenEdge = true,
    this.layering = DockLayering.normal,
    this.edgeCenterOffsetPercent = 0.0,
    this.edgeDistancePx = 8.0,
    this.themeName = 'macOS Sonoma Glass',
    this.panelOpacity = 0.90,
    this.hideIconLabels = false,
    this.labelFontFamily = 'Segoe UI',
    this.labelFontSize = 12.5,
    this.labelFontBold = true,
    this.labelShadowColorValue = 0xFF000000,
    this.labelOutlineColorValue = 0xFF000000,
    this.labelOutlineOpacity = 0.45,
    this.labelShadowOpacity = 0.35,
    this.clickEffect = ClickAttentionEffect.bounce,
    this.autoHide = false,
    this.autoHideDurationMs = 220.0,
    this.autoHideDelayMs = 250.0,
    this.popupOnMouseover = false,
    this.popupDelayMs = 350.0,
    this.soundEffectsEnabled = true,
    this.autoExtractExeIcons = true,
    this.rowCount = 1,
    this.ecoDesktopMode = false,
    this.autoEcoOnBattery = true,
    this.autoPauseOnFullscreen = true,
    this.altNumberQuickLaunch = true,
    this.showClockAndDesktopWidgets = true,
    this.showHardwareTelemetryWidgets = true,
    this.showExtraSystemWidgets = true,
    this.showPowerActionIcons = true,
    this.sortFoldersFirstInStack = true,
  });

  DockSettings copy() => DockSettings.fromMap(toMap());

  FilterQuality get filterQuality {
    switch (iconQuality) {
      case IconRenderQuality.low:
        return FilterQuality.low;
      case IconRenderQuality.medium:
        return FilterQuality.medium;
      case IconRenderQuality.high:
        return FilterQuality.high;
    }
  }

  Map<String, dynamic> toMap() => {
        'language': language,
        'startWithWindows': startWithWindows,
        'saveInSettingsIni': saveInSettingsIni,
        'minimizeWindowsToDock': minimizeWindowsToDock,
        'disableMinimizeAnimation': disableMinimizeAnimation,
        'indicateRunningApps': indicateRunningApps,
        'activateRunningInstance': activateRunningInstance,
        'lockIcons': lockIcons,
        'preventAccidentalClicks': preventAccidentalClicks,
        'accidentalClickGuardMs': accidentalClickGuardMs,
        'minimizeToTrayOnClose': minimizeToTrayOnClose,
        'iconQuality': iconQuality.name,
        'iconOpacity': iconOpacity,
        'fullOpacityOnHover': fullOpacityOnHover,
        'baseIconSize': baseIconSize,
        'hoverZoomMode': hoverZoomMode.name,
        'zoomDeltaPx': zoomDeltaPx,
        'neighborCount': neighborCount,
        'zoomDurationMs': zoomDurationMs,
        'monitorIndex': monitorIndex,
        'screenEdge': screenEdge.name,
        'pinToScreenEdge': pinToScreenEdge,
        'layering': layering.name,
        'edgeCenterOffsetPercent': edgeCenterOffsetPercent,
        'edgeDistancePx': edgeDistancePx,
        'themeName': themeName,
        'panelOpacity': panelOpacity,
        'hideIconLabels': hideIconLabels,
        'labelFontFamily': labelFontFamily,
        'labelFontSize': labelFontSize,
        'labelFontBold': labelFontBold,
        'labelShadowColorValue': labelShadowColorValue,
        'labelOutlineColorValue': labelOutlineColorValue,
        'labelOutlineOpacity': labelOutlineOpacity,
        'labelShadowOpacity': labelShadowOpacity,
        'clickEffect': clickEffect.name,
        'autoHide': autoHide,
        'autoHideDurationMs': autoHideDurationMs,
        'autoHideDelayMs': autoHideDelayMs,
        'popupOnMouseover': popupOnMouseover,
        'popupDelayMs': popupDelayMs,
        'soundEffectsEnabled': soundEffectsEnabled,
        'autoExtractExeIcons': autoExtractExeIcons,
        'rowCount': rowCount,
        'ecoDesktopMode': ecoDesktopMode,
        'autoEcoOnBattery': autoEcoOnBattery,
        'autoPauseOnFullscreen': autoPauseOnFullscreen,
        'altNumberQuickLaunch': altNumberQuickLaunch,
        'showClockAndDesktopWidgets': showClockAndDesktopWidgets,
        'showHardwareTelemetryWidgets': showHardwareTelemetryWidgets,
        'showExtraSystemWidgets': showExtraSystemWidgets,
        'showPowerActionIcons': showPowerActionIcons,
        'sortFoldersFirstInStack': sortFoldersFirstInStack,
      };

  factory DockSettings.fromMap(Map<String, dynamic> m) {
    T enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
      if (raw is String) {
        for (final v in values) {
          if (v.name == raw) return v;
        }
      }
      return fallback;
    }

    return DockSettings(
      language: m['language'] as String? ?? 'Русский',
      startWithWindows: m['startWithWindows'] as bool? ?? false,
      saveInSettingsIni: m['saveInSettingsIni'] as bool? ?? true,
      minimizeWindowsToDock: m['minimizeWindowsToDock'] as bool? ?? false,
      disableMinimizeAnimation: m['disableMinimizeAnimation'] as bool? ?? true,
      indicateRunningApps: m['indicateRunningApps'] as bool? ?? true,
      activateRunningInstance: m['activateRunningInstance'] as bool? ?? true,
      lockIcons: m['lockIcons'] as bool? ?? false,
      preventAccidentalClicks: m['preventAccidentalClicks'] as bool? ?? true,
      accidentalClickGuardMs: ((m['accidentalClickGuardMs'] as num?)?.toInt() ?? 260).clamp(120, 800),
      minimizeToTrayOnClose: m['minimizeToTrayOnClose'] as bool? ?? true,
      iconQuality: enumByName(IconRenderQuality.values, m['iconQuality'], IconRenderQuality.high),
      iconOpacity: ((m['iconOpacity'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 1.0),
      fullOpacityOnHover: m['fullOpacityOnHover'] as bool? ?? true,
      baseIconSize: ((m['baseIconSize'] as num?)?.toDouble() ?? 46.0).clamp(16.0, 128.0),
      hoverZoomMode: enumByName(HoverZoomMode.values, m['hoverZoomMode'], HoverZoomMode.bubble),
      zoomDeltaPx: ((m['zoomDeltaPx'] as num?)?.toDouble() ?? 24.0).clamp(1.0, 128.0),
      neighborCount: ((m['neighborCount'] as num?)?.toInt() ?? 3).clamp(2, 10),
      zoomDurationMs: ((m['zoomDurationMs'] as num?)?.toDouble() ?? 180.0).clamp(100.0, 500.0),
      monitorIndex: (m['monitorIndex'] as num?)?.toInt() ?? 0,
      screenEdge: enumByName(DockEdge.values, m['screenEdge'], DockEdge.bottom),
      pinToScreenEdge: m['pinToScreenEdge'] as bool? ?? true,
      layering: enumByName(DockLayering.values, m['layering'], DockLayering.normal),
      edgeCenterOffsetPercent: ((m['edgeCenterOffsetPercent'] as num?)?.toDouble() ?? 0.0).clamp(-100.0, 100.0),
      edgeDistancePx: ((m['edgeDistancePx'] as num?)?.toDouble() ?? 8.0).clamp(-15.0, 128.0),
      themeName: m['themeName'] as String? ?? 'macOS Sonoma Glass',
      panelOpacity: ((m['panelOpacity'] as num?)?.toDouble() ?? 0.90).clamp(0.0, 1.0),
      hideIconLabels: m['hideIconLabels'] as bool? ?? false,
      labelFontFamily: m['labelFontFamily'] as String? ?? 'Segoe UI',
      labelFontSize: ((m['labelFontSize'] as num?)?.toDouble() ?? 12.5).clamp(9.0, 24.0),
      labelFontBold: m['labelFontBold'] as bool? ?? true,
      labelShadowColorValue: (m['labelShadowColorValue'] as num?)?.toInt() ?? 0xFF000000,
      labelOutlineColorValue: (m['labelOutlineColorValue'] as num?)?.toInt() ?? 0xFF000000,
      labelOutlineOpacity: ((m['labelOutlineOpacity'] as num?)?.toDouble() ?? 0.45).clamp(0.0, 1.0),
      labelShadowOpacity: ((m['labelShadowOpacity'] as num?)?.toDouble() ?? 0.35).clamp(0.0, 1.0),
      clickEffect: enumByName(ClickAttentionEffect.values, m['clickEffect'], ClickAttentionEffect.bounce),
      autoHide: m['autoHide'] as bool? ?? false,
      autoHideDurationMs: ((m['autoHideDurationMs'] as num?)?.toDouble() ?? 220.0).clamp(0.0, 1000.0),
      autoHideDelayMs: ((m['autoHideDelayMs'] as num?)?.toDouble() ?? 250.0).clamp(0.0, 2000.0),
      popupOnMouseover: m['popupOnMouseover'] as bool? ?? false,
      popupDelayMs: ((m['popupDelayMs'] as num?)?.toDouble() ?? 350.0).clamp(0.0, 1000.0),
      soundEffectsEnabled: m['soundEffectsEnabled'] as bool? ?? true,
      autoExtractExeIcons: m['autoExtractExeIcons'] as bool? ?? true,
      rowCount: ((m['rowCount'] as num?)?.toInt() ?? 1).clamp(1, 3),
      ecoDesktopMode: m['ecoDesktopMode'] as bool? ?? false,
      autoEcoOnBattery: m['autoEcoOnBattery'] as bool? ?? true,
      autoPauseOnFullscreen: m['autoPauseOnFullscreen'] as bool? ?? true,
      altNumberQuickLaunch: m['altNumberQuickLaunch'] as bool? ?? true,
      showClockAndDesktopWidgets: m['showClockAndDesktopWidgets'] as bool? ?? true,
      showHardwareTelemetryWidgets: m['showHardwareTelemetryWidgets'] as bool? ?? true,
      showExtraSystemWidgets: m['showExtraSystemWidgets'] as bool? ?? true,
      showPowerActionIcons: m['showPowerActionIcons'] as bool? ?? true,
      sortFoldersFirstInStack: m['sortFoldersFirstInStack'] as bool? ?? true,
    );
  }
}

class DockItemData {
  String id;
  String title;
  String iconName;
  String customIconPath;
  String targetPath;
  String arguments;
  String workingDirectory;
  bool isRunning;
  bool isFolderStack;
  bool isSeparator;
  bool isHardwareWidget;
  String hardwareType;
  bool isWidgetPlugin;
  String widgetType;
  bool isPowerAction;
  String powerType;

  DockItemData({
    required this.id,
    required this.title,
    required this.iconName,
    required this.targetPath,
    this.customIconPath = '',
    this.arguments = '',
    this.workingDirectory = '',
    this.isRunning = false,
    this.isFolderStack = false,
    this.isSeparator = false,
    this.isHardwareWidget = false,
    this.hardwareType = '',
    this.isWidgetPlugin = false,
    this.widgetType = '',
    this.isPowerAction = false,
    this.powerType = '',
  });

  String get processImageName {
    if (targetPath.isEmpty || isSeparator || isFolderStack || isPowerAction || isHardwareWidget || isWidgetPlugin) {
      return '';
    }
    final clean = targetPath.trim();
    if (clean.toLowerCase().endsWith('.exe')) {
      final segs = clean.split(RegExp(r'[/\\]'));
      return segs.last.toLowerCase();
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'iconName': iconName,
        'customIconPath': customIconPath,
        'targetPath': targetPath,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
        'isRunning': isRunning,
        'isFolderStack': isFolderStack,
        'isSeparator': isSeparator,
        'isHardwareWidget': isHardwareWidget,
        'hardwareType': hardwareType,
        'isWidgetPlugin': isWidgetPlugin,
        'widgetType': widgetType,
        'isPowerAction': isPowerAction,
        'powerType': powerType,
      };

  factory DockItemData.fromJson(Map<String, dynamic> json) => DockItemData(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? 'App',
        iconName: json['iconName'] ?? 'custom',
        customIconPath: json['customIconPath'] ?? '',
        targetPath: json['targetPath'] ?? '',
        arguments: json['arguments'] ?? '',
        workingDirectory: json['workingDirectory'] ?? '',
        isRunning: json['isRunning'] ?? false,
        isFolderStack: json['isFolderStack'] ?? false,
        isSeparator: json['isSeparator'] ?? false,
        isHardwareWidget: json['isHardwareWidget'] ?? false,
        hardwareType: json['hardwareType'] ?? '',
        isWidgetPlugin: json['isWidgetPlugin'] ?? false,
        widgetType: json['widgetType'] ?? '',
        isPowerAction: json['isPowerAction'] ?? false,
        powerType: json['powerType'] ?? '',
      );
}
