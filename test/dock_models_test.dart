import 'package:flutter_test/flutter_test.dart';
import 'package:roket_dok/models/dock_models.dart';
import 'package:roket_dok/services/portable_storage.dart';

void main() {
  test('DockSettings serialization and copy preserve all fields', () {
    final original = DockSettings(
      baseIconSize: 52.0,
      ecoDesktopMode: true,
      autoEcoOnBattery: false,
      autoPauseOnFullscreen: true,
      altNumberQuickLaunch: true,
      globalHotkeysEnabled: true,
      spotlightCommandSearch: true,
      monitorIndex: 1,
    );

    final restored = DockSettings.fromMap(original.toMap());
    expect(restored.baseIconSize, 52.0);
    expect(restored.ecoDesktopMode, true);
    expect(restored.autoEcoOnBattery, false);
    expect(restored.autoPauseOnFullscreen, true);
    expect(restored.altNumberQuickLaunch, true);
    expect(restored.globalHotkeysEnabled, true);
    expect(restored.spotlightCommandSearch, true);
    expect(restored.monitorIndex, 1);
  });

  test('PortableStorage parses classic RocketDock INI format with env vars', () {
    const ini = '''
[Software\RocketDock]
IconMin=48
IconMax=80
Side=1
Monitor=2

[Software\RocketDock\Icons]
Count=2
0-Title=Блокнот
0-Command="%SystemRoot%\System32\notepad.exe"
1-IsSeparator=1
''';
    final res = PortableStorage.parseIniString(
      ini,
      baseSettings: DockSettings(),
      sourceLabel: 'test.ini',
    );
    expect(res, isNotNull);
    expect(res!.importedCount, 2);
    expect(res.settings.baseIconSize, 48.0);
    expect(res.settings.monitorIndex, 1);
    expect(res.items[0].title, 'Блокнот');
    expect(res.items[0].targetPath.contains('notepad.exe'), true);
    expect(res.items[1].isSeparator, true);
  });
}
