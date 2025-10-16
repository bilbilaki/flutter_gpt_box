// lib/image_capture_service.dart (CORRECTED & ENHANCED)

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screengot/services/screengot_service.dart';
import 'package:window_manager/window_manager.dart';


// Represents the state during the cropping operation
enum CroppingState { idle, selectingStart, selectingEnd, complete }

class ImageCaptureService extends ChangeNotifier {
  final ScreenGotService _nativeBridge = ScreenGotService();

  CroppingState state = CroppingState.idle;
  Uint8List? fullScreenshotData;
  Uint8List? croppedImage;

  // Actual pixel dimensions of the full captured screenshot
  int capturedWidth = 0;
  int capturedHeight = 0;

  // Cropping coordinates (relative to the top-left of the captured image)
  Point<int>? startPoint;
  Point<int>? endPoint;

  // Status for display
  String status = 'Ready';
  String? savedFilePath;
  String? croppedInfo;

  // --- Window Control Functions (Requires window_manager package) ---

  Future<void> _minimizeWindow() async {
    try {
      if (await windowManager.isMinimized()) return;
      await windowManager.minimize();
      // Wait slightly for minimization to complete
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      status = 'Error minimizing window: $e';
      notifyListeners();
    }
  }

  Future<void> _maximizeWindow() async {
    try {
      await windowManager.restore();
    } catch (e) {
      status = 'Error restoring window: $e';
      notifyListeners();
    }
  }

  // --- Main Capture Flow ---

  Future<void> captureFullScreen() async {
    if (state != CroppingState.idle) {
      status = 'Still processing previous operation.';
      notifyListeners();
      return;
    }

    status = 'Minimizing window...';
    notifyListeners();

    await _minimizeWindow();

    status = 'Getting screen size...';
    notifyListeners();

    try {
      final sizeResponse = await _nativeBridge.getScreenSize();
      if (!sizeResponse.success) {
        throw Exception(sizeResponse.error ?? 'Failed to get screen size.');
      }
      final size = sizeResponse.data as Map<String, dynamic>;
      final w = size['width'] as int;
      final h = size['height'] as int;

      capturedWidth = w;
      capturedHeight = h;
String pp='/home/nss/Documents/WC/screengot2/png64.png';
      status = 'Screen size ($w x $h). Taking full screenshot...';
      notifyListeners();

      // Capture the full screen (0, 0, W, H)
      final response = await _nativeBridge.saveImageJpeg(pp,100);

      if (!response.success) {
        throw Exception(response.error ?? 'Screenshot failed.');
      }
final byte = await File(pp).readAsBytes();

      // *** FIX: Decode Base64 here ***
      fullScreenshotData = byte;

      status = 'Screenshot taken. Restoring window...';
await File(pp).delete();
    } catch (e) {
      status = 'Capture error: $e';
      fullScreenshotData = null;
    }

    await _maximizeWindow();

    if (fullScreenshotData != null) {
      status =
          'Screenshot loaded. Click on the image to select the start point.';
      state = CroppingState.selectingStart;
    } else {
      state = CroppingState.idle;
    }
    notifyListeners();
  }

  // --- Cropping Interaction ---
  // localPosition is the raw Offset (Flutter pixels) on the image widget.
  // widgetWidth/Height is the dimensions of the Flutter Image widget rendering the full screenshot.

  Point<int> _scaleToPixels(
    Offset localPosition,
    double widgetWidth,
    double widgetHeight,
  ) {
    if (capturedWidth == 0 || capturedHeight == 0) return const Point(0, 0);

    // Calculate scaling factor from UI size back to captured pixel size
    final scaleX = capturedWidth / widgetWidth;
    final scaleY = capturedHeight / widgetHeight;

    final px = (localPosition.dx * scaleX).round().clamp(0, capturedWidth);
    final py = (localPosition.dy * scaleY).round().clamp(0, capturedHeight);

    return Point(px, py);
  }

  void handlePointerDown(
    Offset localPosition,
    double imageWidth,
    double imageHeight,
  ) {
    if (state != CroppingState.selectingStart) return;

    startPoint = _scaleToPixels(localPosition, imageWidth, imageHeight);
    endPoint = startPoint;
    state = CroppingState.selectingEnd;
    notifyListeners();
  }

  void handlePointerMove(
    Offset localPosition,
    double imageWidth,
    double imageHeight,
  ) {
    if (state != CroppingState.selectingEnd || startPoint == null) return;

    endPoint = _scaleToPixels(localPosition, imageWidth, imageHeight);
    notifyListeners();
  }

  void handlePointerUp(
    Offset localPosition,
    double imageWidth,
    double imageHeight,
  ) {
    if (state != CroppingState.selectingEnd ||
        startPoint == null ||
        endPoint == null)
      return;

    // Finalize end point
    endPoint = _scaleToPixels(localPosition, imageWidth, imageHeight);

    // Determine final crop rectangle in PIXELS
    final x1 = min(startPoint!.x, endPoint!.x);
    final y1 = min(startPoint!.y, endPoint!.y);
    final x2 = max(startPoint!.x, endPoint!.x);
    final y2 = max(startPoint!.y, endPoint!.y);

    final croppedW = x2 - x1;
    final croppedH = y2 - y1;

    if (croppedW < 10 || croppedH < 10) {
      status =
          'Selection ($croppedW x $croppedH) too small (min 10x10). Try again.';
      startPoint = null;
      endPoint = null;
      state = CroppingState.selectingStart;
      notifyListeners();
      return;
    }

    _cropAndSave(x1, y1, croppedW, croppedH);
  }

  // --- Cropping and Saving ---

  Future<void> _cropAndSave(int x, int y, int w, int h) async {
    status = 'Cropping and saving region ($x, $y, $w x $h)...';
    notifyListeners();
String pp = '/home/nss/Documents/WC/screengot2/png64.png';

    try {
      // Use the Go bridge to perform capture specifically for the cropped region
      final response = await _nativeBridge.captureScreenBitmapSave(x, y, w, h,pp);

      if (!response.success) {
        throw Exception(response.error ?? 'Cropping capture failed.');
      }

final byte = await File(pp).readAsBytes();

      // *** FIX: Decode Base64 here ***

      croppedImage = byte;

      // Save to a file
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/cropped_$timestamp.png';

      await File(filePath).writeAsBytes(croppedImage!);

      savedFilePath = filePath;
      // Position includes x, y, and the z component of the screen (which is 0 in 2D)
      croppedInfo = 'Position: (x:$x, y:$y, z:0) | Size: ($w x $h)';

      status = 'Crop successful and saved to: $filePath';
    } catch (e) {
      status = 'Crop/Save error: $e';
    } finally {
      state = CroppingState.complete;
      startPoint = null;
      endPoint = null;
      notifyListeners();
    }
  }

  void reset() {
    fullScreenshotData = null;
    croppedImage = null;
    startPoint = null;
    endPoint = null;
    savedFilePath = null;
    croppedInfo = null;
    capturedWidth = 0;
    capturedHeight = 0;
    state = CroppingState.idle;
    status = 'Ready to capture.';
    notifyListeners();
  }

  // Returns the selection rectangle in CAPTURED PIXEL COORDINATES
  Rect? get selectionRectPixels {
    if (startPoint == null || endPoint == null) return null;

    final start = startPoint!;
    final end = endPoint!;

    final left = min(start.x, end.x);
    final top = min(start.y, end.y);
    final right = max(start.x, end.x);
    final bottom = max(start.y, end.y);

    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
  }
}
