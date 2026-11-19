# MAP.md

- Точка входа: `lib/main.dart` (`RocketDockApp`, `DockScreen`, `_DockScreenState`, `_runWithExpandedWindow` (без принудительного `alwaysOnTop` и с перетаскиванием окна настроек), `_isEffectiveEcoMode`, `_reextractAllIconsManually`, `_resolveEnvPath`, `_warmUpIconCache`, `_quickLaunchSlotForItem`, `_launchQuickSlot` (`Alt+1..9`), `_buildDiagnosticsSummary`, `_scheduleIdleWorkingSetTrim`, `_buildSizedFileImage`, `_getFilteredItems`, `_pauseBackgroundTimers`, `_clearImageCache`, `_wakePhysicsTicker`, `_scheduleDebouncedSave`, `_saveToProfilesDir`, поиск `Ctrl+F`, стек папок, меню ПКМ, меню трея, хоткей `Ctrl+Alt+R`).
- Контракты данных: `DockSettings`, `DockItemData`, `IniImportResult` (`lib/models/dock_models.dart`, `lib/services/portable_storage.dart`).
- Платформенный слой Windows: `NativeHardwareTelemetry`, `WindowsIntegration`, `PortableStorage`.
- Настройки: `RocketDockSettingsDialog` (`lib/widgets/settings_dialog.dart`, поддерживает перетаскивание окна через `onStartWindowDrag`).
