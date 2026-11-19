import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'portable_storage.dart';

typedef _EnumWindowsProcNative = Int32 Function(IntPtr hwnd, IntPtr lParam);
typedef _EnumWindowsNative = Int32 Function(Pointer<NativeFunction<_EnumWindowsProcNative>> lpEnumFunc, IntPtr lParam);
typedef _EnumWindowsDart = int Function(Pointer<NativeFunction<_EnumWindowsProcNative>> lpEnumFunc, int lParam);

typedef _IsWindowVisibleNative = Int32 Function(IntPtr hwnd);
typedef _IsWindowVisibleDart = int Function(int hwnd);

typedef _GetWindowThreadProcessIdNative = Uint32 Function(IntPtr hwnd, Pointer<Uint32> lpdwProcessId);
typedef _GetWindowThreadProcessIdDart = int Function(int hwnd, Pointer<Uint32> lpdwProcessId);

typedef _OpenProcessNative = IntPtr Function(Uint32 dwDesiredAccess, Int32 bInheritHandle, Uint32 dwProcessId);
typedef _OpenProcessDart = int Function(int dwDesiredAccess, int bInheritHandle, int dwProcessId);

typedef _QueryFullProcessImageNameWNative = Int32 Function(
  IntPtr hProcess,
  Uint32 dwFlags,
  Pointer<Utf16> lpExeName,
  Pointer<Uint32> lpdwSize,
);
typedef _QueryFullProcessImageNameWDart = int Function(
  int hProcess,
  int dwFlags,
  Pointer<Utf16> lpExeName,
  Pointer<Uint32> lpdwSize,
);

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

typedef _SetForegroundWindowNative = Int32 Function(IntPtr hwnd);
typedef _SetForegroundWindowDart = int Function(int hwnd);

typedef _ShowWindowNative = Int32 Function(IntPtr hwnd, Int32 nCmdShow);
typedef _ShowWindowDart = int Function(int hwnd, int nCmdShow);

typedef _IsIconicNative = Int32 Function(IntPtr hwnd);
typedef _IsIconicDart = int Function(int hwnd);

typedef _ExtractIconExWNative = Uint32 Function(
  Pointer<Utf16> lpszFile,
  Int32 nIconIndex,
  Pointer<IntPtr> phiconLarge,
  Pointer<IntPtr> phiconSmall,
  Uint32 nIcons,
);
typedef _ExtractIconExWDart = int Function(
  Pointer<Utf16> lpszFile,
  int nIconIndex,
  Pointer<IntPtr> phiconLarge,
  Pointer<IntPtr> phiconSmall,
  int nIcons,
);

typedef _DestroyIconNative = Int32 Function(IntPtr hIcon);
typedef _DestroyIconDart = int Function(int hIcon);

typedef _GetCurrentProcessNative = IntPtr Function();
typedef _GetCurrentProcessDart = int Function();

typedef _SetProcessWorkingSetSizeNative = Int32 Function(
  IntPtr hProcess,
  IntPtr dwMinimumWorkingSetSize,
  IntPtr dwMaximumWorkingSetSize,
);
typedef _SetProcessWorkingSetSizeDart = int Function(
  int hProcess,
  int dwMinimumWorkingSetSize,
  int dwMaximumWorkingSetSize,
);

final class _ProcessMemoryCounters extends Struct {
  @Uint32()
  external int cb;

  @Uint32()
  external int pageFaultCount;

  @IntPtr()
  external int peakWorkingSetSize;

  @IntPtr()
  external int workingSetSize;

  @IntPtr()
  external int quotaPeakPagedPoolUsage;

  @IntPtr()
  external int quotaPagedPoolUsage;

  @IntPtr()
  external int quotaPeakNonPagedPoolUsage;

  @IntPtr()
  external int quotaNonPagedPoolUsage;

  @IntPtr()
  external int pagefileUsage;

  @IntPtr()
  external int peakPagefileUsage;
}

typedef _GetProcessMemoryInfoNative = Int32 Function(
  IntPtr process,
  Pointer<_ProcessMemoryCounters> ppsmemCounters,
  Uint32 cb,
);
typedef _GetProcessMemoryInfoDart = int Function(
  int process,
  Pointer<_ProcessMemoryCounters> ppsmemCounters,
  int cb,
);

class WindowsIntegration {
  static const String _runRegKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _appRegName = 'RocketDockPortable';

  static DynamicLibrary? _user32;
  static DynamicLibrary? _kernel32;
  static _EnumWindowsDart? _enumWindows;
  static _IsWindowVisibleDart? _isWindowVisible;
  static _GetWindowThreadProcessIdDart? _getWindowThreadProcessId;
  static _OpenProcessDart? _openProcess;
  static _QueryFullProcessImageNameWDart? _queryFullProcessImageNameW;
  static _CloseHandleDart? _closeHandle;
  static _SetForegroundWindowDart? _setForegroundWindow;
  static _ShowWindowDart? _showWindow;
  static _IsIconicDart? _isIconic;
  static _ExtractIconExWDart? _extractIconExW;
  static _DestroyIconDart? _destroyIcon;
  static _GetCurrentProcessDart? _getCurrentProcess;
  static _SetProcessWorkingSetSizeDart? _setProcessWorkingSetSize;
  static _GetProcessMemoryInfoDart? _getProcessMemoryInfo;

  static int windowScanCount = 0;
  static int lastWindowScanMicros = 0;
  static int totalWindowScanMicros = 0;
  static final List<String> _activityLog = [];

  static void recordActivity(String entry, {int? durationMs}) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final suffix = durationMs != null ? ' (${durationMs}ms)' : '';
    _activityLog.insert(0, '[$ts] $entry$suffix');
    if (_activityLog.length > 30) {
      _activityLog.removeRange(30, _activityLog.length);
    }
  }

  static List<String> getActivityLog() => List<String>.unmodifiable(_activityLog);

  static final Map<String, int> _visibleHwndByExe = {};
  static final Set<String> _runningExeSet = {};

  static bool _ensureFfi() {
    if (!Platform.isWindows) return false;
    if (_user32 != null && _kernel32 != null) return true;
    try {
      _user32 = DynamicLibrary.open('user32.dll');
      _kernel32 = DynamicLibrary.open('kernel32.dll');

      _enumWindows = _user32!.lookupFunction<_EnumWindowsNative, _EnumWindowsDart>('EnumWindows');
      _isWindowVisible = _user32!.lookupFunction<_IsWindowVisibleNative, _IsWindowVisibleDart>('IsWindowVisible');
      _getWindowThreadProcessId = _user32!.lookupFunction<_GetWindowThreadProcessIdNative, _GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');
      _setForegroundWindow = _user32!.lookupFunction<_SetForegroundWindowNative, _SetForegroundWindowDart>('SetForegroundWindow');
      _showWindow = _user32!.lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow');
      _isIconic = _user32!.lookupFunction<_IsIconicNative, _IsIconicDart>('IsIconic');
      _destroyIcon = _user32!.lookupFunction<_DestroyIconNative, _DestroyIconDart>('DestroyIcon');
      try {
        final shell32 = DynamicLibrary.open('shell32.dll');
        _extractIconExW = shell32.lookupFunction<_ExtractIconExWNative, _ExtractIconExWDart>('ExtractIconExW');
      } catch (_) {}

      _openProcess = _kernel32!.lookupFunction<_OpenProcessNative, _OpenProcessDart>('OpenProcess');
      _queryFullProcessImageNameW = _kernel32!.lookupFunction<_QueryFullProcessImageNameWNative, _QueryFullProcessImageNameWDart>('QueryFullProcessImageNameW');
      _closeHandle = _kernel32!.lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
      try {
        _getCurrentProcess = _kernel32!.lookupFunction<_GetCurrentProcessNative, _GetCurrentProcessDart>('GetCurrentProcess');
        _setProcessWorkingSetSize = _kernel32!.lookupFunction<_SetProcessWorkingSetSizeNative, _SetProcessWorkingSetSizeDart>('SetProcessWorkingSetSize');
      } catch (_) {}
      try {
        _getProcessMemoryInfo = _kernel32!.lookupFunction<_GetProcessMemoryInfoNative, _GetProcessMemoryInfoDart>('K32GetProcessMemoryInfo');
      } catch (_) {
        try {
          final psapi = DynamicLibrary.open('psapi.dll');
          _getProcessMemoryInfo = psapi.lookupFunction<_GetProcessMemoryInfoNative, _GetProcessMemoryInfoDart>('GetProcessMemoryInfo');
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static int _enumWindowsCallback(int hwnd, int lParam) {
    if (_isWindowVisible == null || _isWindowVisible!(hwnd) == 0) return 1;
    final pidPtr = calloc<Uint32>();
    try {
      _getWindowThreadProcessId!(hwnd, pidPtr);
      final pid = pidPtr.value;
      if (pid != 0) {
        final hProc = _openProcess!(0x1000, 0, pid);
        if (hProc != 0) {
          final buf = calloc<Uint16>(260).cast<Utf16>();
          final sizePtr = calloc<Uint32>()..value = 260;
          try {
            if (_queryFullProcessImageNameW!(hProc, 0, buf, sizePtr) != 0) {
              final fullPath = buf.toDartString();
              if (fullPath.isNotEmpty) {
                final exeName = fullPath.split(RegExp(r'[/\\]')).last.toLowerCase();
                _runningExeSet.add(exeName);
                _visibleHwndByExe.putIfAbsent(exeName, () => hwnd);
              }
            }
          } finally {
            calloc.free(buf);
            calloc.free(sizePtr);
            _closeHandle!(hProc);
          }
        }
      }
    } finally {
      calloc.free(pidPtr);
    }
    return 1;
  }

  static Set<String> scanVisibleRunningApps() {
    if (!_ensureFfi() || _enumWindows == null) return {};
    final sw = Stopwatch()..start();
    _runningExeSet.clear();
    _visibleHwndByExe.clear();

    final cb = Pointer.fromFunction<_EnumWindowsProcNative>(_enumWindowsCallback, 0);
    _enumWindows!(cb, 0);
    sw.stop();
    windowScanCount++;
    lastWindowScanMicros = sw.elapsedMicroseconds;
    totalWindowScanMicros += lastWindowScanMicros;
    return Set<String>.from(_runningExeSet);
  }

  static Future<void> setStartWithWindows(bool enable) async {
    if (!Platform.isWindows) return;
    try {
      recordActivity(enable ? 'reg.exe (автозапуск: вкл)' : 'reg.exe (автозапуск: выкл)');
      if (enable) {
        final exePath = Platform.resolvedExecutable;
        await Process.run(
          'reg',
          ['add', _runRegKey, '/v', _appRegName, '/t', 'REG_SZ', '/d', '"$exePath"', '/f'],
          runInShell: false,
        );
      } else {
        await Process.run(
          'reg',
          ['delete', _runRegKey, '/v', _appRegName, '/f'],
          runInShell: false,
        );
      }
    } catch (_) {}
  }

  static List<String> _splitArgs(String rawArgs) {
    final trimmed = rawArgs.trim();
    if (trimmed.isEmpty) return const [];
    final parts = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < trimmed.length; i++) {
      final ch = trimmed[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ' ' && !inQuotes) {
        if (buf.isNotEmpty) {
          parts.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }

  static Future<void> activateOrLaunch({
    required String targetPath,
    String arguments = '',
    String workingDirectory = '',
    required bool activateExisting,
  }) async {
    final target = targetPath.trim();
    if (target.isEmpty || !Platform.isWindows) return;

    final lower = target.toLowerCase();
    if (activateExisting && lower.endsWith('.exe')) {
      final exeName = target.split(RegExp(r'[/\\]')).last.toLowerCase();
      scanVisibleRunningApps();
      final hwnd = _visibleHwndByExe[exeName];
      if (hwnd != null && hwnd != 0 && _setForegroundWindow != null) {
        if (_isIconic != null && _isIconic!(hwnd) != 0 && _showWindow != null) {
          _showWindow!(hwnd, 9);
        }
        _setForegroundWindow!(hwnd);
        return;
      }
    }

    if (lower.endsWith('.exe') && await File(target).exists()) {
      final workDir = workingDirectory.trim().isNotEmpty
          ? workingDirectory.trim()
          : File(target).parent.path;
      final argsList = _splitArgs(arguments);
      recordActivity('Запуск EXE: ${target.split(RegExp(r'[/\\]')).last}');
      await Process.start(
        target,
        argsList,
        workingDirectory: Directory(workDir).existsSync() ? workDir : null,
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      return;
    }

    recordActivity('explorer.exe -> $target');
    await Process.start(
      'explorer.exe',
      [target],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
  }



  /// Returns current process Working Set and Private Bytes in MB via Win32 GetProcessMemoryInfo
  static ({double workingSetMb, double privateBytesMb}) getProcessMemoryInfo() {
    if (!Platform.isWindows || !_ensureFfi()) {
      return (workingSetMb: 0.0, privateBytesMb: 0.0);
    }
    if (_getCurrentProcess == null || _getProcessMemoryInfo == null) {
      return (workingSetMb: 0.0, privateBytesMb: 0.0);
    }
    final ptr = calloc<_ProcessMemoryCounters>();
    try {
      final cbSize = sizeOf<_ProcessMemoryCounters>();
      ptr.ref.cb = cbSize;
      final hProc = _getCurrentProcess!();
      if (hProc != 0 && _getProcessMemoryInfo!(hProc, ptr, cbSize) != 0) {
        final wsMb = ptr.ref.workingSetSize / (1024.0 * 1024.0);
        final privMb = ptr.ref.pagefileUsage / (1024.0 * 1024.0);
        return (workingSetMb: wsMb, privateBytesMb: privMb);
      }
    } catch (_) {
    } finally {
      calloc.free(ptr);
    }
    return (workingSetMb: 0.0, privateBytesMb: 0.0);
  }

  /// Trims unused working-set memory pages back to Windows OS
  static void trimProcessWorkingSet() {
    if (!Platform.isWindows || !_ensureFfi()) return;
    if (_getCurrentProcess == null || _setProcessWorkingSetSize == null) return;
    try {
      final hProc = _getCurrentProcess!();
      if (hProc != 0) {
        _setProcessWorkingSetSize!(hProc, -1, -1);
      }
    } catch (_) {}
  }

  /// Fast native FFI probe for icons in .exe / .dll / .ico files without spawning a shell
  static bool canExtractNativeIcon(String filePath) {
    if (!Platform.isWindows || !_ensureFfi() || _extractIconExW == null || filePath.isEmpty) {
      return false;
    }
    final pathPtr = filePath.toNativeUtf16();
    final largePtr = calloc<IntPtr>();
    final smallPtr = calloc<IntPtr>();
    try {
      final count = _extractIconExW!(pathPtr, 0, largePtr, smallPtr, 1);
      if (largePtr.value != 0 && _destroyIcon != null) {
        _destroyIcon!(largePtr.value);
      }
      if (smallPtr.value != 0 && _destroyIcon != null) {
        _destroyIcon!(smallPtr.value);
      }
      return count > 0;
    } catch (_) {
      return false;
    } finally {
      calloc.free(pathPtr);
      calloc.free(largePtr);
      calloc.free(smallPtr);
    }
  }

  static Future<String?> extractJumboIcon(String filePath, {required bool enabled}) async {
    if (!Platform.isWindows || !enabled || filePath.isEmpty) return null;
    try {
      final lower = filePath.toLowerCase();
      if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.bmp')) {
        return filePath;
      }
      final cacheDir = PortableStorage.iconsCacheDir;
      final hash = filePath.hashCode.abs().toString();
      final outPath = '${cacheDir.path}${Platform.pathSeparator}icon_hd_$hash.png';
      if (await File(outPath).exists()) {
        return outPath;
      }

      final escapedIn = filePath.replaceAll("'", "''");
      final escapedOut = outPath.replaceAll("'", "''");
      final psScript = '''
Add-Type -AssemblyName System.Drawing
\$src = @'
using System;
using System.Runtime.InteropServices;
public class JumboIcon {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct SHFILEINFO {
    public IntPtr hIcon;
    public int iIcon;
    public uint dwAttributes;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
    public string szDisplayName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
    public string szTypeName;
  }
  [ComImport, Guid("46EB5926-582E-4017-9FDF-E8998DAA0950"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  public interface IImageList {
    int Add(IntPtr hbmImage, IntPtr hbmMask, ref int pi);
    int ReplaceIcon(int i, IntPtr hicon, ref int pi);
    int SetOverlayImage(int iImage, int iOverlay);
    int Replace(int i, IntPtr hbmImage, IntPtr hbmMask);
    int AddMasked(IntPtr hbmImage, int crMask, ref int pi);
    int Draw(IntPtr pimldp);
    int Remove(int i);
    int GetIcon(int i, int flags, ref IntPtr picon);
  }
  [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr SHGetFileInfo(string pszPath, uint dwFileAttributes, ref SHFILEINFO psfi, uint cbFileInfo, uint uFlags);
  [DllImport("shell32.dll", EntryPoint = "#727")]
  public static extern int SHGetImageList(int iImageList, ref Guid riid, out IImageList ppv);
  [DllImport("user32.dll")]
  public static extern bool DestroyIcon(IntPtr hIcon);
  public static IntPtr Get256Icon(string path) {
    SHFILEINFO shfi = new SHFILEINFO();
    SHGetFileInfo(path, 0, ref shfi, (uint)Marshal.SizeOf(shfi), 0x4000);
    Guid iid = new Guid("46EB5926-582E-4017-9FDF-E8998DAA0950");
    IImageList iml;
    if (SHGetImageList(0x4, ref iid, out iml) == 0 && iml != null) {
      IntPtr hIcon = IntPtr.Zero;
      iml.GetIcon(shfi.iIcon, 1, ref hIcon);
      if (hIcon != IntPtr.Zero) return hIcon;
    }
    return IntPtr.Zero;
  }
}
'@
Add-Type -TypeDefinition \$src -ErrorAction SilentlyContinue
\$path = '$escapedIn'
if (\$path.ToLower().EndsWith('.lnk')) {
  \$shell = New-Object -ComObject WScript.Shell
  \$shortcut = \$shell.CreateShortcut(\$path)
  if (\$shortcut.TargetPath -and (Test-Path \$shortcut.TargetPath)) {
    \$path = \$shortcut.TargetPath
  }
}
if (Test-Path \$path) {
  \$hIcon = [JumboIcon]::Get256Icon(\$path)
  if (\$hIcon -ne [IntPtr]::Zero) {
    \$ico = [System.Drawing.Icon]::FromHandle(\$hIcon)
    \$bmp = \$ico.ToBitmap()
    \$bmp.Save('$escapedOut', [System.Drawing.Imaging.ImageFormat]::Png)
    \$bmp.Dispose()
    \$ico.Dispose()
    [JumboIcon]::DestroyIcon(\$hIcon) | Out-Null
  } else {
    \$icon = [System.Drawing.Icon]::ExtractAssociatedIcon(\$path)
    if (\$icon -ne \$null) {
      \$bmp = \$icon.ToBitmap()
      \$bmp.Save('$escapedOut', [System.Drawing.Imaging.ImageFormat]::Png)
      \$bmp.Dispose()
      \$icon.Dispose()
    }
  }
}
''';
      final psSw = Stopwatch()..start();
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', psScript],
      );
      psSw.stop();
      recordActivity('powershell.exe (иконка: ${filePath.split(RegExp(r'[/\\]')).last})', durationMs: psSw.elapsedMilliseconds);
      if (result.exitCode == 0 && await File(outPath).exists()) {
        return outPath;
      }
    } catch (_) {}
    return null;
  }
}
