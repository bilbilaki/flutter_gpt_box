// lib/services/screengot_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import '../models/native_response.dart';

// Adjust this import to where your ffigen binding file resides.
import '../bindings/screengot_bindings.dart';

class ScreenGotService {
  static final ScreenGotService _instance = ScreenGotService._internal();
  factory ScreenGotService() => _instance;
  ScreenGotService._internal();

  late final ffi.DynamicLibrary _dylib;
  late final ScreenGot _native;

  ReceivePort? _receivePort;
  int? _nativePort;

  // Pending completers keyed by op string. FIFO queue to match responses in arrival order.
  final Map<String, Queue<Completer<NativeResponse>>> _pending = {};

  // Unsolicited/native events broadcast (hook events, logs, etc.)
  final StreamController<NativeResponse> _eventsController =
      StreamController.broadcast();
  Stream<NativeResponse> get events => _eventsController.stream;

  bool _initialized = false;

  // default timeout for waiting a response from native for an op
  Duration responseTimeout = const Duration(seconds: 6);

  /// Initialize and load the native library.
  /// libPath defaults to 'native/linux/screengot.so' — adjust for platform/packaging.
  Future<void> init({String libPath = 'native/linux/screengot.so'}) async {
    if (_initialized) return;
    _dylib = ffi.DynamicLibrary.open(libPath);
    _native = ScreenGot(_dylib);

    // Initialize Dart API table in native side (must be called before native posts messages)
    _native.BridgeInit(ffi.NativeApi.initializeApiDLData);

    // create receive port and listen
    _receivePort = ReceivePort();
    _receivePort!.listen(_handleNativeMessage);
    _nativePort = _receivePort!.sendPort.nativePort;

    // register the port in native side
    _native.RegisterPort(_nativePort!);

    _initialized = true;
  }

  /// Cleanup and unregister port
  void dispose() {
    if (!_initialized) return;
    try {
      _native.UnregisterPort();
    } catch (_) {}
    _receivePort?.close();
    _eventsController.close();
    _initialized = false;
  }

void _handleNativeMessage(dynamic raw) {
    final resp = NativeResponse.fromMessage(raw);

    bool tryCompleteByKey(String key) {
      final q = _pending[key];
      if (q != null && q.isNotEmpty) {
        final c = _pending[key]!.removeFirst();
        if (_pending[key]!.isEmpty) _pending.remove(key);
        if (!c.isCompleted) c.complete(resp);
        return true;
      }
      return false;
    }

    // 1) Try normal JSON op-based completion
    final op = resp.op;
    if (op != null && op.isNotEmpty) {
      if (tryCompleteByKey(op)) return;
    } else if (resp.data is String) {
      // 2) Try plain string ack completion (exact or prefix match)
      final s = resp.data as String;
      if (tryCompleteByKey(s)) return; // exact match
      for (final key in _pending.keys.toList()) {
        if (s.startsWith(key)) {
          if (tryCompleteByKey(key)) return;
        }
      }
    }

    // 3) Unsolicited/broadcast event
    _eventsController.add(resp);
  }


  // internal helper: call native function (immediate) and wait for op response
  Future<NativeResponse> _callAndWait(String op, void Function() call) {
    final completer = Completer<NativeResponse>();
    _pending
        .putIfAbsent(op, () => Queue<Completer<NativeResponse>>())
        .add(completer);
    try {
      call();
    } catch (e) {
      // remove from queue
      final q = _pending[op];
      if (q != null) {
        q.removeWhere((c) => c == completer);
        if (q.isEmpty) _pending.remove(op);
      }
      completer.completeError(e);
      return completer.future;
    }
    return completer.future.timeout(
      responseTimeout,
      onTimeout: () {
        // remove this completer from queue if still present
        final q = _pending[op];
        if (q != null) {
          q.removeWhere((c) => c == completer);
          if (q.isEmpty) _pending.remove(op);
        }
        throw TimeoutException('Timeout waiting for op=$op');
      },
    );
  }

  // ---------- High-level wrappers ----------
  // Each of these calls the corresponding function in the ffigen binding and waits for the op result.
  // For functions that return task IDs (MoveSmoothStart, etc.) we return int immediately.

  Future<NativeResponse> move(int x, int y, {int port = 0}) {
    return _callAndWait('move', () {
      _native.Move(x, y, port);
    });
  }

  Future<NativeResponse> moveRelative(int x, int y, {int port = 0}) {
    return _callAndWait('move_relative', () {
      _native.MoveRelative(x, y, port);
    });
  }

  Future<NativeResponse> click(
    String button, {
    bool dbl = false,
    int port = 0,
  }) {
    final ptr = button.toNativeUtf8();
    return _callAndWait('click', () {
      try {
        _native.Click(ptr.cast(), dbl ? 1 : 0, port);
      } finally {
        calloc.free(ptr);
      }
    });
  }

  Future<NativeResponse> toggle(String button, String? dir, {int port = 0}) {
    final bptr = button.toNativeUtf8();
    final dptr = dir == null ? ffi.nullptr : dir.toNativeUtf8();
    return _callAndWait('toggle', () {
      try {
        _native.Toggle(bptr.cast(), dptr.cast(), port);
      } finally {
        calloc.free(bptr);
        if (dptr != ffi.nullptr) calloc.free(dptr);
      }
    });
  }

  Future<NativeResponse> scroll(int x, int y, {int port = 0}) {
    return _callAndWait('scroll', () {
      _native.Scroll(x, y, port);
    });
  }

  Future<NativeResponse> scrollDir(int amount, String dir, {int port = 0}) {
    final dptr = dir.toNativeUtf8();
    return _callAndWait('scrolldir', () {
      try {
        _native.ScrollDir(amount, dptr.cast(), port);
      } finally {
        calloc.free(dptr);
      }
    });
  }

  Future<NativeResponse> getLocation({int port = 0}) {
    return _callAndWait('location', () {
      _native.GetLocation(port);
    });
  }

  Future<NativeResponse> setMouseSleep(int ms, {int port = 0}) {
    return _callAndWait('set_mouse_sleep', () {
      _native.SetMouseSleep(ms, port);
    });
  }

  Future<NativeResponse> milliSleep(int ms, {int port = 0}) {
    return _callAndWait('milli_sleep', () {
      _native.MilliSleep(ms, port);
    });
  }

  // cancellable actions returning task id
  int moveSmoothStart(int x, int y, {int port = 0}) {
    return _native.MoveSmoothStart(x, y, port);
  }

  int dragSmoothStart(int x, int y, {int port = 0}) {
    return _native.DragSmoothStart(x, y, port);
  }

  int scrollSmoothStart(int x, int y, {int port = 0}) {
    return _native.ScrollSmoothStart(x, y, port);
  }

  Future<NativeResponse> stopTask(int taskId, {int port = 0}) {
    return _callAndWait('stop', () {
      _native.StopTask(taskId, port);
    });
  }

  // typing/key functions
  Future<NativeResponse> typeStr(String s, {int port = 0}) {
    final ptr = s.toNativeUtf8();
    return _callAndWait('type_str', () {
      try {
        _native.TypeStr(ptr.cast(), port);
      } finally {
        calloc.free(ptr);
      }
    });
  }

  Future<NativeResponse> typeStrWithInts(
    String s,
    int a1,
    int a2, {
    int port = 0,
  }) {
    final ptr = s.toNativeUtf8();
    return _callAndWait('type_str_with_ints', () {
      try {
        _native.TypeStrWithInts(ptr.cast(), a1, a2, port);
      } finally {
        calloc.free(ptr);
      }
    });
  }

  Future<NativeResponse> sleep(int seconds, {int port = 0}) {
    return _callAndWait('sleep', () {
      _native.Sleep(seconds, port);
    });
  }

  Future<NativeResponse> setKeySleep(int ms, {int port = 0}) {
    return _callAndWait('set_key_sleep', () {
      _native.SetKeySleep(ms, port);
    });
  }

  Future<NativeResponse> keyTap(String key, {String? mods, int port = 0}) {
    final kptr = key.toNativeUtf8();
    final mptr = mods == null ? ffi.nullptr : mods.toNativeUtf8();
    return _callAndWait('key_tap', () {
      try {
        _native.KeyTap(kptr.cast(), mptr.cast(), port);
      } finally {
        calloc.free(kptr);
        if (mptr != ffi.nullptr) calloc.free(mptr);
      }
    });
  }

  Future<NativeResponse> keyTapArr(
    String key,
    String modsJson, {
    int port = 0,
  }) {
    final kptr = key.toNativeUtf8();
    final mptr = modsJson.toNativeUtf8();
    return _callAndWait('key_tap_arr', () {
      try {
        _native.KeyTapArr(kptr.cast(), mptr.cast(), port);
      } finally {
        calloc.free(kptr);
        calloc.free(mptr);
      }
    });
  }

  Future<NativeResponse> keyToggle(
    String key, {
    String? direction,
    int port = 0,
  }) {
    final kptr = key.toNativeUtf8();
    final dptr = direction == null ? ffi.nullptr : direction.toNativeUtf8();
    return _callAndWait('key_toggle', () {
      try {
        _native.KeyToggle(kptr.cast(), dptr.cast(), port);
      } finally {
        calloc.free(kptr);
        if (dptr != ffi.nullptr) calloc.free(dptr);
      }
    });
  }

  Future<NativeResponse> writeAll(String text, {int port = 0}) {
    final ptr = text.toNativeUtf8();
    return _callAndWait('write_all', () {
      try {
        _native.WriteAll(ptr.cast(), port);
      } finally {
        calloc.free(ptr);
      }
    });
  }

  Future<NativeResponse> readAll({int port = 0}) {
    return _callAndWait('read_all', () {
      _native.ReadAll(port);
    });
  }

  Future<int> typeStrStart(String s, {int port = 0}) async {
    final ptr = s.toNativeUtf8();
    try {
      final tid = _native.TypeStrStart(ptr.cast(), port);
      return tid;
    } finally {
      calloc.free(ptr);
    }
  }

  // screen / image / capture functions
  Future<NativeResponse> getPixelColor(int x, int y, {int port = 0}) {
    return _callAndWait('get_pixel_color', () {
      _native.GetPixelColor(x, y, port);
    });
  }

  Future<NativeResponse> getScreenSize({int port = 0}) {
    return _callAndWait('get_screen_size', () {
      _native.GetScreenSize(port);
    });
  }

  Future<NativeResponse> captureScreenSave(
    int x,
    int y,
    int w,
    int h,
    String? path, {
    int port = 0,
  }) {
    final pptr = path == null ? ffi.nullptr : path.toNativeUtf8();
    return _callAndWait('capture_screen_save', () {
      try {
        _native.CaptureScreenSave(x, y, w, h, pptr.cast(), port);
      } finally {
        if (pptr != ffi.nullptr) calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> captureScreenBase64(
    int x,
    int y,
    int w,
    int h, {
    int port = 0,
  }) {
    return _callAndWait('capture_screen_base64', () {
      _native.CaptureScreenBase64(x, y, w, h, port);
    });
  }

  Future<NativeResponse> displaysNum({int port = 0}) {
    return _callAndWait('displays_num', () {
      _native.DisplaysNum(port);
    });
  }

  Future<NativeResponse> getDisplayBounds(int index, {int port = 0}) {
    return _callAndWait('get_display_bounds', () {
      _native.GetDisplayBounds(index, port);
    });
  }

  Future<NativeResponse> captureDisplaySave(
    int index,
    String? path, {
    int port = 0,
  }) {
    final pptr = path == null ? ffi.nullptr : path.toNativeUtf8();
    return _callAndWait('capture_display_save', () {
      try {
        _native.CaptureDisplaySave(index, pptr.cast(), port);
      } finally {
        if (pptr != ffi.nullptr) calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> captureDisplayRegionSave(
    int index,
    int x,
    int y,
    int w,
    int h,
    String? path, {
    int port = 0,
  }) {
    final pptr = path == null ? ffi.nullptr : path.toNativeUtf8();
    return _callAndWait('capture_display_region_save', () {
      try {
        _native.CaptureDisplayRegionSave(index, x, y, w, h, pptr.cast(), port);
      } finally {
        if (pptr != ffi.nullptr) calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> saveImageJpeg(
    String path,
    int quality, {
    int port = 0,
  }) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('save_image_jpeg', () {
      try {
        _native.SaveImageJpeg(pptr.cast(), quality, port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> saveImagePNGFromCaptureImg(
    String path, {
    int port = 0,
  }) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('save_image_png_from_capture', () {
      try {
        _native.SaveImagePNGFromCaptureImg(pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  // bitmap / find helpers
  Future<NativeResponse> captureScreenBitmapSave(
    int x,
    int y,
    int w,
    int h,
    String path, {
    int port = 0,
  }) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('capture_bitmap_save', () {
      try {
        _native.CaptureScreenBitmapSave(x, y, w, h, pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> findBitmapFromCapture(
    int x,
    int y,
    int w,
    int h, {
    int port = 0,
  }) {
    return _callAndWait('find_bitmap_from_capture', () {
      _native.FindBitmapFromCapture(x, y, w, h, port);
    });
  }

  Future<NativeResponse> findAllBitmapFromCapture(
    int x,
    int y,
    int w,
    int h, {
    int port = 0,
  }) {
    return _callAndWait('find_all_bitmap_from_capture', () {
      _native.FindAllBitmapFromCapture(x, y, w, h, port);
    });
  }

  Future<NativeResponse> moveToFoundBitmap(
    int x,
    int y,
    int w,
    int h, {
    int port = 0,
  }) {
    return _callAndWait('move_to_found_bitmap', () {
      _native.MoveToFoundBitmap(x, y, w, h, port);
    });
  }

  Future<NativeResponse> saveBitmapToFile(
    int x,
    int y,
    int w,
    int h,
    String path, {
    int port = 0,
  }) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('save_bitmap_to_file', () {
      try {
        _native.SaveBitmapToFile(x, y, w, h, pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  // save capture helpers
  Future<NativeResponse> saveCaptureRegion(
    String path,
    int x,
    int y,
    int w,
    int h, {
    int port = 0,
  }) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('save_capture_region', () {
      try {
        _native.SaveCaptureRegion(pptr.cast(), x, y, w, h, port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> saveCaptureFull(String path, {int port = 0}) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('save_capture_full', () {
      try {
        _native.SaveCaptureFull(pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

Future<NativeResponse> gcvFindImgFile(
    String tpl,
    String target, {
    int flag = 0,
    int port = 0,
  }) {
    final tptr = tpl.toNativeUtf8();
    final uptr = target.toNativeUtf8();
    return _callAndWait('gcv_find_all_img_file', () {
      try {
        _native.GcvFindAllImgFile(tptr.cast(), uptr.cast(), port);
      } finally {
        calloc.free(tptr);
        calloc.free(uptr);
      }
    });
  }
  Future<NativeResponse> gcvFindAllImgFile(
    String tpl,
    String target, {
    int port = 0,
  }) {
    final tptr = tpl.toNativeUtf8();
    final uptr = target.toNativeUtf8();
    return _callAndWait('gcv_find_all_img_file', () {
      try {
        _native.GcvFindAllImgFile(tptr.cast(), uptr.cast(), port);
      } finally {
        calloc.free(tptr);
        calloc.free(uptr);
      }
    });
  }
  // Awaited wrappers for smooth operations (use native Start + wait for op)
  Future<NativeResponse> moveSmooth(int x, int y, {int port = 0}) {
    return _callAndWait('move_smooth', () {
      _native.MoveSmoothStart(x, y, port);
    });
  }

  Future<NativeResponse> dragSmoothTo(int x, int y, {int port = 0}) {
    return _callAndWait('drag_smooth', () {
      _native.DragSmoothStart(x, y, port);
    });
  }

  Future<NativeResponse> scrollSmooth(int x, int y, {int port = 0}) {
    return _callAndWait('scroll_smooth', () {
      _native.ScrollSmoothStart(x, y, port);
    });
  }

  Future<NativeResponse> gcvFindImgFilesDecoded(
    String tpl,
    String target, {
    int port = 0,
  }) {
    final tptr = tpl.toNativeUtf8();
    final uptr = target.toNativeUtf8();
    return _callAndWait('gcv_find_all_img_files_decoded', () {
      try {
        _native.GcvFindAllImgFilesDecoded(tptr.cast(), uptr.cast(), port);
      } finally {
        calloc.free(tptr);
        calloc.free(uptr);
      }
    });
  }


  Future<NativeResponse> gcvFindAllImgFilesDecoded(
    String tpl,
    String target, {
    int port = 0,
  }) {
    final tptr = tpl.toNativeUtf8();
    final uptr = target.toNativeUtf8();
    return _callAndWait('gcv_find_all_img_files_decoded', () {
      try {
        _native.GcvFindAllImgFilesDecoded(tptr.cast(), uptr.cast(), port);
      } finally {
        calloc.free(tptr);
        calloc.free(uptr);
      }
    });
  }

  Future<NativeResponse> gcvFindXFromFile(
    String tpl,
    String target, {
    int port = 0,
  }) {
    final tptr = tpl.toNativeUtf8();
    final uptr = target.toNativeUtf8();
    return _callAndWait('gcv_find_x_from_file', () {
      try {
        _native.GcvFindXFromFile(tptr.cast(), uptr.cast(), port);
      } finally {
        calloc.free(tptr);
        calloc.free(uptr);
      }
    });
  }

  Future<NativeResponse> bitmapOpenFind(String path, {int port = 0}) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('bitmap_open_find', () {
      try {
        _native.BitmapOpenFind(pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> bitmapFindAllFromFile(String path, {int port = 0}) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('bitmap_find_all_from_file', () {
      try {
        _native.BitmapFindAllFromFile(pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  Future<NativeResponse> moveToFoundFromFile(String path, {int port = 0}) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('move_to_found_from_file', () {
      try {
        _native.MoveToFoundFromFile(pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }

  // ---- hooks ----

  Future<NativeResponse> hookRegisterCombo(
    String modsComma,
    String key, {
    int port = 0,
  }) {
    final mptr = modsComma.toNativeUtf8();
    final kptr = key.toNativeUtf8();
    return _callAndWait('registered-hotkey', () {
      try {
        _native.HookRegisterCombo(mptr.cast(), kptr.cast(), port);
      } finally {
        calloc.free(mptr);
        calloc.free(kptr);
      }
    });
  }

  /// Start hook loop; waits for the initial "hook_started" message (which native code sends after starting).
  Future<NativeResponse> hookStart({int port = 0}) {
    return _callAndWait('hook_started', () {
      _native.HookStart(port);
    });
  }

  void hookStop() {
    _native.HookStop();
  }

  Future<NativeResponse> hookAddEvent(String name, {int port = 0}) {
    final nptr = name.toNativeUtf8();
    return _callAndWait('add_event', () {
      try {
        _native.HookAddEvent(nptr.cast(), port);
      } finally {
        calloc.free(nptr);
      }
    });
  }

  // Future<NativeResponse> hookAddEvents(String commaSeparated, {int port = 0}) {
  //   final nptr = commaSeparated.toNativeUtf8();
  //   return _callAndWait('add_events', () {
  //     try {
  //       _native.HookAddEvents(nptr.cast(), port);
  //     } finally {
  //       calloc.free(nptr);
  //     }
  //   });
  // }

  Future<NativeResponse> decodeAndReportImageSize(String path, {int port = 0}) {
    final pptr = path.toNativeUtf8();
    return _callAndWait('decode_image_size', () {
      try {
        _native.DecodeAndReportImageSize(pptr.cast(), port);
      } finally {
        calloc.free(pptr);
      }
    });
  }
}
