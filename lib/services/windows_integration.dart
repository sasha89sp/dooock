import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

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

final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external _Rect rcMonitor;
  external _Rect rcWork;
  @Uint32()
  external int dwFlags;
}

final class _ShFileInfoW extends Struct {
  @IntPtr()
  external int hIcon;
  @Int32()
  external int iIcon;
  @Uint32()
  external int dwAttributes;
  @Array(260)
  external Array<Uint16> szDisplayName;
  @Array(80)
  external Array<Uint16> szTypeName;
}

final class _IconInfo extends Struct {
  @Int32()
  external int fIcon;
  @Uint32()
  external int xHotspot;
  @Uint32()
  external int yHotspot;
  @IntPtr()
  external int hbmMask;
  @IntPtr()
  external int hbmColor;
}

final class _Bitmap extends Struct {
  @Int32()
  external int bmType;
  @Int32()
  external int bmWidth;
  @Int32()
  external int bmHeight;
  @Int32()
  external int bmWidthBytes;
  @Uint16()
  external int bmPlanes;
  @Uint16()
  external int bmBitsPixel;
  external Pointer<Void> bmBits;
}

final class _BitmapInfoHeader extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

typedef _MonitorEnumProcNative = Int32 Function(IntPtr hMonitor, IntPtr hdcMonitor, Pointer<_Rect> lprcMonitor, IntPtr dwData);
typedef _EnumDisplayMonitorsNative = Int32 Function(IntPtr hdc, Pointer<_Rect> lprcClip, Pointer<NativeFunction<_MonitorEnumProcNative>> lpfnEnum, IntPtr dwData);
typedef _EnumDisplayMonitorsDart = int Function(int hdc, Pointer<_Rect> lprcClip, Pointer<NativeFunction<_MonitorEnumProcNative>> lpfnEnum, int dwData);

typedef _GetMonitorInfoWNative = Int32 Function(IntPtr hMonitor, Pointer<_MonitorInfo> lpmi);
typedef _GetMonitorInfoWDart = int Function(int hMonitor, Pointer<_MonitorInfo> lpmi);

typedef _GetForegroundWindowNative = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

typedef _GetWindowRectNative = Int32 Function(IntPtr hwnd, Pointer<_Rect> lpRect);
typedef _GetWindowRectDart = int Function(int hwnd, Pointer<_Rect> lpRect);

typedef _MonitorFromWindowNative = IntPtr Function(IntPtr hwnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hwnd, int dwFlags);

typedef _SHGetFileInfoWNative = IntPtr Function(Pointer<Utf16> pszPath, Uint32 dwFileAttributes, Pointer<_ShFileInfoW> psfi, Uint32 cbFileInfo, Uint32 uFlags);
typedef _SHGetFileInfoWDart = int Function(Pointer<Utf16> pszPath, int dwFileAttributes, Pointer<_ShFileInfoW> psfi, int cbFileInfo, int uFlags);

typedef _GetIconInfoNative = Int32 Function(IntPtr hIcon, Pointer<_IconInfo> piconinfo);
typedef _GetIconInfoDart = int Function(int hIcon, Pointer<_IconInfo> piconinfo);

typedef _GetObjectWNative = Int32 Function(IntPtr h, Int32 c, Pointer<Void> pv);
typedef _GetObjectWDart = int Function(int h, int c, Pointer<Void> pv);

typedef _GetDCNative = IntPtr Function(IntPtr hwnd);
typedef _GetDCDart = int Function(int hwnd);

typedef _ReleaseDCNative = Int32 Function(IntPtr hwnd, IntPtr hdc);
typedef _ReleaseDCDart = int Function(int hwnd, int hdc);

typedef _GetDIBitsNative = Int32 Function(IntPtr hdc, IntPtr hbm, Uint32 start, Uint32 cLines, Pointer<Uint8> lpvBits, Pointer<_BitmapInfoHeader> lpbmi, Uint32 usage);
typedef _GetDIBitsDart = int Function(int hdc, int hbm, int start, int cLines, Pointer<Uint8> lpvBits, Pointer<_BitmapInfoHeader> lpbmi, int usage);

typedef _DeleteObjectNative = Int32 Function(IntPtr ho);
typedef _DeleteObjectDart = int Function(int ho);

typedef _WaveOutGetVolumeNative = Int32 Function(IntPtr hwo, Pointer<Uint32> pdwVolume);
typedef _WaveOutGetVolumeDart = int Function(int hwo, Pointer<Uint32> pdwVolume);

typedef _RegisterHotKeyNative = Int32 Function(IntPtr hWnd, Int32 id, Uint32 fsModifiers, Uint32 vk);
typedef _RegisterHotKeyDart = int Function(int hWnd, int id, int fsModifiers, int vk);

typedef _UnregisterHotKeyNative = Int32 Function(IntPtr hWnd, Int32 id);
typedef _UnregisterHotKeyDart = int Function(int hWnd, int id);

final class _MsgStruct extends Struct {
  @IntPtr()
  external int hwnd;
  @Uint32()
  external int message;
  @IntPtr()
  external int wParam;
  @IntPtr()
  external int lParam;
  @Uint32()
  external int time;
  @Int32()
  external int ptX;
  @Int32()
  external int ptY;
}

typedef _PeekMessageWNative = Int32 Function(
  Pointer<_MsgStruct> lpMsg,
  IntPtr hWnd,
  Uint32 wMsgFilterMin,
  Uint32 wMsgFilterMax,
  Uint32 wRemoveMsg,
);
typedef _PeekMessageWDart = int Function(
  Pointer<_MsgStruct> lpMsg,
  int hWnd,
  int wMsgFilterMin,
  int wMsgFilterMax,
  int wRemoveMsg,
);

typedef _GetAsyncKeyStateNative = Int16 Function(Int32 vKey);
typedef _GetAsyncKeyStateDart = int Function(int vKey);

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
  static _DestroyIconDart? _destroyIcon;
  static _GetCurrentProcessDart? _getCurrentProcess;
  static _SetProcessWorkingSetSizeDart? _setProcessWorkingSetSize;
  static _GetProcessMemoryInfoDart? _getProcessMemoryInfo;
  static _EnumDisplayMonitorsDart? _enumDisplayMonitors;
  static _GetMonitorInfoWDart? _getMonitorInfoW;
  static _GetForegroundWindowDart? _getForegroundWindow;
  static _GetWindowRectDart? _getWindowRect;
  static _MonitorFromWindowDart? _monitorFromWindow;
  static _SHGetFileInfoWDart? _shGetFileInfoW;
  static _GetIconInfoDart? _getIconInfo;
  static _GetObjectWDart? _getObjectW;
  static _GetDCDart? _getDC;
  static _ReleaseDCDart? _releaseDC;
  static _GetDIBitsDart? _getDIBits;
  static _DeleteObjectDart? _deleteObject;
  static _WaveOutGetVolumeDart? _waveOutGetVolume;
  static _RegisterHotKeyDart? _registerHotKey;
  static _UnregisterHotKeyDart? _unregisterHotKey;
  static bool _hotkeysRegistered = false;
  static _PeekMessageWDart? _peekMessageW;
  static _GetAsyncKeyStateDart? _getAsyncKeyState;
  static DateTime _lastGlobalHotkeyFire = DateTime.fromMillisecondsSinceEpoch(0);

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
        _enumDisplayMonitors = _user32!.lookupFunction<_EnumDisplayMonitorsNative, _EnumDisplayMonitorsDart>('EnumDisplayMonitors');
        _getMonitorInfoW = _user32!.lookupFunction<_GetMonitorInfoWNative, _GetMonitorInfoWDart>('GetMonitorInfoW');
        _getForegroundWindow = _user32!.lookupFunction<_GetForegroundWindowNative, _GetForegroundWindowDart>('GetForegroundWindow');
        _getWindowRect = _user32!.lookupFunction<_GetWindowRectNative, _GetWindowRectDart>('GetWindowRect');
        _monitorFromWindow = _user32!.lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>('MonitorFromWindow');
        _getIconInfo = _user32!.lookupFunction<_GetIconInfoNative, _GetIconInfoDart>('GetIconInfo');
        _getDC = _user32!.lookupFunction<_GetDCNative, _GetDCDart>('GetDC');
        _releaseDC = _user32!.lookupFunction<_ReleaseDCNative, _ReleaseDCDart>('ReleaseDC');
        _registerHotKey = _user32!.lookupFunction<_RegisterHotKeyNative, _RegisterHotKeyDart>('RegisterHotKey');
        _unregisterHotKey = _user32!.lookupFunction<_UnregisterHotKeyNative, _UnregisterHotKeyDart>('UnregisterHotKey');
        _peekMessageW = _user32!.lookupFunction<_PeekMessageWNative, _PeekMessageWDart>('PeekMessageW');
        _getAsyncKeyState = _user32!.lookupFunction<_GetAsyncKeyStateNative, _GetAsyncKeyStateDart>('GetAsyncKeyState');
      } catch (_) {}
      try {
        final winmm = DynamicLibrary.open('winmm.dll');
        _waveOutGetVolume = winmm.lookupFunction<_WaveOutGetVolumeNative, _WaveOutGetVolumeDart>('waveOutGetVolume');
      } catch (_) {}
      try {
        final gdi32 = DynamicLibrary.open('gdi32.dll');
        _getObjectW = gdi32.lookupFunction<_GetObjectWNative, _GetObjectWDart>('GetObjectW');
        _getDIBits = gdi32.lookupFunction<_GetDIBitsNative, _GetDIBitsDart>('GetDIBits');
        _deleteObject = gdi32.lookupFunction<_DeleteObjectNative, _DeleteObjectDart>('DeleteObject');
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

  static final List<({int left, int top, int width, int height, bool isPrimary})> _monitorsCache = [];

  static int _monitorEnumCallback(int hMonitor, int hdcMonitor, Pointer<_Rect> lprcMonitor, int dwData) {
    if (_getMonitorInfoW == null) return 1;
    final info = calloc<_MonitorInfo>();
    try {
      info.ref.cbSize = sizeOf<_MonitorInfo>();
      if (_getMonitorInfoW!(hMonitor, info) != 0) {
        final w = info.ref.rcWork;
        final isPrimary = (info.ref.dwFlags & 1) != 0;
        _monitorsCache.add((
          left: w.left,
          top: w.top,
          width: w.right - w.left,
          height: w.bottom - w.top,
          isPrimary: isPrimary,
        ));
      }
    } finally {
      calloc.free(info);
    }
    return 1;
  }

  /// Enumerates connected Windows displays and returns work-area bounds for [monitorIndex]
  static ({int left, int top, int width, int height})? getMonitorWorkArea(int monitorIndex) {
    if (!Platform.isWindows || !_ensureFfi() || _enumDisplayMonitors == null) return null;
    _monitorsCache.clear();
    final cb = Pointer.fromFunction<_MonitorEnumProcNative>(_monitorEnumCallback, 0);
    _enumDisplayMonitors!(0, nullptr, cb, 0);
    if (_monitorsCache.isEmpty) return null;
    // Sort primary monitor first so index 0 is always Primary
    _monitorsCache.sort((a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0));
    final idx = monitorIndex.clamp(0, _monitorsCache.length - 1);
    final m = _monitorsCache[idx];
    return (left: m.left, top: m.top, width: m.width, height: m.height);
  }

  static int getMonitorCount() {
    getMonitorWorkArea(0);
    return _monitorsCache.isEmpty ? 1 : _monitorsCache.length;
  }

  /// Detects if a foreground third-party window covers its entire monitor (fullscreen game / video)
  static bool isForegroundAppFullscreen() {
    if (!Platform.isWindows || !_ensureFfi()) return false;
    if (_getForegroundWindow == null || _getWindowRect == null || _monitorFromWindow == null || _getMonitorInfoW == null) {
      return false;
    }
    final hwnd = _getForegroundWindow!();
    if (hwnd == 0) return false;

    final pidPtr = calloc<Uint32>();
    try {
      _getWindowThreadProcessId!(hwnd, pidPtr);
      if (pidPtr.value == pid) return false;
    } finally {
      calloc.free(pidPtr);
    }

    final winRect = calloc<_Rect>();
    final monInfo = calloc<_MonitorInfo>();
    try {
      if (_getWindowRect!(hwnd, winRect) == 0) return false;
      final hMon = _monitorFromWindow!(hwnd, 2);
      if (hMon == 0) return false;
      monInfo.ref.cbSize = sizeOf<_MonitorInfo>();
      if (_getMonitorInfoW!(hMon, monInfo) == 0) return false;

      final m = monInfo.ref.rcMonitor;
      final w = winRect.ref;
      return w.left <= m.left && w.top <= m.top && w.right >= m.right && w.bottom >= m.bottom;
    } catch (_) {
      return false;
    } finally {
      calloc.free(winRect);
      calloc.free(monInfo);
    }
  }

  /// Pure Win32 FFI icon extractor (SHGetFileInfoW + GetDIBits -> 32-bit BGRA BMP, 0 PowerShell processes)
  static String? extractNativeIconBmp(String filePath) {
    if (!Platform.isWindows || !_ensureFfi()) return null;
    if (_shGetFileInfoW == null || _getIconInfo == null || _getObjectW == null || _getDIBits == null || _getDC == null || _releaseDC == null) {
      return null;
    }
    final sw = Stopwatch()..start();
    final cacheDir = PortableStorage.iconsCacheDir;
    final hash = filePath.hashCode.abs().toString();
    final outPath = '${cacheDir.path}${Platform.pathSeparator}icon_native_$hash.bmp';
    if (File(outPath).existsSync()) return outPath;

    final pathPtr = filePath.toNativeUtf16();
    final shfi = calloc<_ShFileInfoW>();
    final iconInfo = calloc<_IconInfo>();
    final bmpStruct = calloc<_Bitmap>();
    final bih = calloc<_BitmapInfoHeader>();
    int hIcon = 0;
    int hdc = 0;

    try {
      // SHGFI_ICON (0x100) | SHGFI_LARGEICON (0x0)
      final res = _shGetFileInfoW!(pathPtr, 0, shfi, sizeOf<_ShFileInfoW>(), 0x000000100);
      hIcon = shfi.ref.hIcon;
      if (res == 0 || hIcon == 0) return null;

      if (_getIconInfo!(hIcon, iconInfo) == 0) return null;
      final hbmColor = iconInfo.ref.hbmColor;
      if (hbmColor == 0) return null;

      if (_getObjectW!(hbmColor, sizeOf<_Bitmap>(), bmpStruct.cast<Void>()) == 0) return null;
      final width = bmpStruct.ref.bmWidth;
      final height = bmpStruct.ref.bmHeight.abs();
      if (width <= 0 || height <= 0 || width > 512 || height > 512) return null;

      final imageSize = width * height * 4;
      bih.ref.biSize = sizeOf<_BitmapInfoHeader>();
      bih.ref.biWidth = width;
      bih.ref.biHeight = height;
      bih.ref.biPlanes = 1;
      bih.ref.biBitCount = 32;
      bih.ref.biCompression = 0; // BI_RGB
      bih.ref.biSizeImage = imageSize;

      hdc = _getDC!(0);
      final pixels = calloc<Uint8>(imageSize);
      try {
        final lines = _getDIBits!(hdc, hbmColor, 0, height, pixels, bih, 0);
        if (lines == 0) return null;

        final fileSize = 54 + imageSize;
        final header = BytesBuilder(copy: false);
        header.add([0x42, 0x4D]); // 'BM'
        header.add(_u32(fileSize));
        header.add(_u32(0));
        header.add(_u32(54));
        header.add(_u32(40));
        header.add(_i32(width));
        header.add(_i32(height));
        header.add(_u16(1));
        header.add(_u16(32));
        header.add(_u32(0));
        header.add(_u32(imageSize));
        header.add(_i32(0));
        header.add(_i32(0));
        header.add(_u32(0));
        header.add(_u32(0));

        final rawView = pixels.asTypedList(imageSize);
        final rgbaBytes = Uint8List(imageSize);
        int anyAlpha = 0;
        for (int i = 0; i < imageSize; i += 4) {
          if (rawView[i + 3] != 0) {
            anyAlpha++;
            break;
          }
        }
        // Flip bottom-up DIB rows to top-down for standard BMP decoders & normalize alpha
        final rowBytes = width * 4;
        for (int y = 0; y < height; y++) {
          final srcRow = (height - 1 - y) * rowBytes;
          final dstRow = y * rowBytes;
          for (int x = 0; x < rowBytes; x += 4) {
            final b = rawView[srcRow + x];
            final g = rawView[srcRow + x + 1];
            final r = rawView[srcRow + x + 2];
            final a = anyAlpha > 0 ? rawView[srcRow + x + 3] : ((b | g | r) == 0 ? 0 : 255);
            rgbaBytes[dstRow + x] = b;
            rgbaBytes[dstRow + x + 1] = g;
            rgbaBytes[dstRow + x + 2] = r;
            rgbaBytes[dstRow + x + 3] = a;
          }
        }
        // Store negative biHeight so top-down pixel order is explicit
        final topDownHeader = BytesBuilder(copy: false);
        topDownHeader.add([0x42, 0x4D]); // 'BM'
        topDownHeader.add(_u32(fileSize));
        topDownHeader.add(_u32(0));
        topDownHeader.add(_u32(54));
        topDownHeader.add(_u32(40));
        topDownHeader.add(_i32(width));
        topDownHeader.add(_i32(-height));
        topDownHeader.add(_u16(1));
        topDownHeader.add(_u16(32));
        topDownHeader.add(_u32(0));
        topDownHeader.add(_u32(imageSize));
        topDownHeader.add(_i32(0));
        topDownHeader.add(_i32(0));
        topDownHeader.add(_u32(0));
        topDownHeader.add(_u32(0));

        final outBytes = Uint8List(fileSize);
        outBytes.setAll(0, topDownHeader.takeBytes());
        outBytes.setAll(54, rgbaBytes);
        File(outPath).writeAsBytesSync(outBytes, flush: false);

        sw.stop();
        recordActivity('Win32 FFI иконка (без PowerShell): ${filePath.split(RegExp(r'[/\]')).last}', durationMs: sw.elapsedMilliseconds);
        return outPath;
      } finally {
        calloc.free(pixels);
      }
    } catch (_) {
      return null;
    } finally {
      if (hdc != 0) _releaseDC!(0, hdc);
      if (iconInfo.ref.hbmColor != 0 && _deleteObject != null) _deleteObject!(iconInfo.ref.hbmColor);
      if (iconInfo.ref.hbmMask != 0 && _deleteObject != null) _deleteObject!(iconInfo.ref.hbmMask);
      if (hIcon != 0 && _destroyIcon != null) _destroyIcon!(hIcon);
      calloc.free(pathPtr);
      calloc.free(shfi);
      calloc.free(iconInfo);
      calloc.free(bmpStruct);
      calloc.free(bih);
    }
  }


  /// Returns real Windows system wave output volume (0..100) via winmm waveOutGetVolume
  static int getSystemVolumePercent() {
    if (!Platform.isWindows || !_ensureFfi() || _waveOutGetVolume == null) return 65;
    final volPtr = calloc<Uint32>();
    try {
      if (_waveOutGetVolume!(0, volPtr) == 0) {
        final raw = volPtr.value;
        final left = raw & 0xFFFF;
        final right = (raw >> 16) & 0xFFFF;
        final avg = ((left + right) * 0.5) / 65535.0 * 100.0;
        return avg.round().clamp(0, 100);
      }
    } catch (_) {
    } finally {
      calloc.free(volPtr);
    }
    return 65;
  }

  /// Registers global Ctrl+Alt+R hotkey (MOD_CONTROL=0x2 | MOD_ALT=0x1, VK_R=0x52)
  static bool registerGlobalToggleHotkey() {
    if (!Platform.isWindows || !_ensureFfi() || _registerHotKey == null) return false;
    if (_hotkeysRegistered) return true;
    try {
      final ok = _registerHotKey!(0, 9001, 0x0002 | 0x0001, 0x52) != 0;
      _hotkeysRegistered = ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static void unregisterGlobalToggleHotkey() {
    if (!Platform.isWindows || !_ensureFfi() || _unregisterHotKey == null) return;
    if (!_hotkeysRegistered) return;
    try {
      _unregisterHotKey!(0, 9001);
    } catch (_) {}
    _hotkeysRegistered = false;
  }


  /// Checks if global Ctrl+Alt+R hotkey fired via WM_HOTKEY or async key state (debounced 400ms)
  static bool pollGlobalToggleHotkeyTriggered() {
    if (!Platform.isWindows || !_ensureFfi() || !_hotkeysRegistered) return false;
    final now = DateTime.now();
    if (now.difference(_lastGlobalHotkeyFire).inMilliseconds < 400) return false;

    bool fired = false;
    if (_peekMessageW != null) {
      final msg = calloc<_MsgStruct>();
      try {
        // WM_HOTKEY = 0x0312, PM_REMOVE = 0x0001
        while (_peekMessageW!(msg, 0, 0x0312, 0x0312, 0x0001) != 0) {
          if (msg.ref.wParam == 9001) {
            fired = true;
          }
        }
      } catch (_) {
      } finally {
        calloc.free(msg);
      }
    }

    if (!fired && _getAsyncKeyState != null) {
      try {
        final ctrlDown = (_getAsyncKeyState!(0x11) & 0x8000) != 0;
        final altDown = (_getAsyncKeyState!(0x12) & 0x8000) != 0;
        final rDown = (_getAsyncKeyState!(0x52) & 0x8000) != 0;
        if (ctrlDown && altDown && rDown) {
          fired = true;
        }
      } catch (_) {}
    }

    if (fired) {
      _lastGlobalHotkeyFire = now;
    }
    return fired;
  }

  static bool get isGlobalHotkeyRegistered => _hotkeysRegistered;

  static List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  static List<int> _u32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  static List<int> _i32(int v) => _u32(v);

}
