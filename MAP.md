# MAP.md

- Точка входа: `lib/main.dart` (`RocketDockApp`, `DockScreen`, `_DockScreenState`, `_warmUpIconCache`, `_reextractAllIconsManually`, `_runWithExpandedWindow`, `_applyWindowProperties`, `_openFolderStack`, `_isEffectiveEcoMode`, `_resolveEnvPath`, `_quickLaunchSlotForItem`, `_launchQuickSlot`, `_buildDiagnosticsSummary`, `_scheduleIdleWorkingSetTrim`, `_buildSizedFileImage`, `_getFilteredItems`, `_pauseBackgroundTimers`, `_clearImageCache`, `_wakePhysicsTicker`, `_scheduleDebouncedSave`, `_saveToProfilesDir`).
- Контракты данных: `DockSettings`, `DockItemData`, `IniImportResult` (`lib/models/dock_models.dart`, `lib/services/portable_storage.dart`).
- Платформенный слой Windows: `NativeHardwareTelemetry`, `WindowsIntegration` (`showNativeContextMenu`, `NativeMenuEntry`), `PortableStorage`.
- Настройки: `RocketDockSettingsDialog` (`lib/widgets/settings_dialog.dart`).
