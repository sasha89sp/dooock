# MAP.md

- Точка входа: `lib/main.dart` (`RocketDockApp`, `DockScreen`, `_buildDiagnosticsSummary`, `_scheduleIdleWorkingSetTrim`, `_buildSizedFileImage`, `_getFilteredItems`, `_pauseBackgroundTimers`, `_clearImageCache`, `_wakePhysicsTicker`, `_scheduleDebouncedSave`, `_saveToProfilesDir`, поиск `Ctrl+F`, стек папок, меню ПКМ, хоткей `Ctrl+Alt+R`).
- Контракты данных: `DockSettings` (`ecoDesktopMode`, `showClockAndDesktopWidgets`, `showHardwareTelemetryWidgets`, `showExtraSystemWidgets`, `showPowerActionIcons`, `sortFoldersFirstInStack`), `DockItemData`, `IniImportResult` (`lib/models/dock_models.dart`, `lib/services/portable_storage.dart`).
- Платформенный слой Windows: `NativeHardwareTelemetry` (`GetSystemPowerStatus` / RAM / CPU / Temp без PowerShell), `WindowsIntegration` (`getProcessMemoryInfo` / `trimProcessWorkingSet` / `recordActivity` / `ExtractIconExW` / `DestroyIcon` / окна / запуск), `PortableStorage` (`cleanOrphanedIconCache`, `profilesDir`, импорт и экспорт `.ini`).
- Настройки: `RocketDockSettingsDialog` (`lib/widgets/settings_dialog.dart`).
