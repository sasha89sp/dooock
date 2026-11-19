# ROOT_MAP.md

- `lib/main.dart` — точка входа (`main`, `DockScreen`), 120fps анимация/наведение, поиск значков, стек папок, перетаскивание значков и разделителей, меню ПКМ и хоткеи.
- `lib/models/dock_models.dart` — модели `DockSettings` и `DockItemData`.
- `lib/services/` — `portable_storage.dart` (портативное хранилище, импорт и экспорт `.ini`), `native_telemetry.dart` (телеметрия), `windows_integration.dart` (запуск и иконки).
- `lib/widgets/settings_dialog.dart` — модальное окно настроек `RocketDockSettingsDialog`.
- `assets/` — иконки приложения (`app_icon.ico`, `app_icon.png`).
- `.github/workflows/` — CI/CD workflow (`windows-build.yml`).
