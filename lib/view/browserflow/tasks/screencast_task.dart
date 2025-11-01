import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:puppeteer/puppeteer.dart' as pup;
import '../utils/browser_utils.dart';

/// Records a short screencast (animated GIF) for each URL.
///
/// Behavior mirrors other tasks in this module:
/// - Prompts for an output directory
/// - Launches (desktop) or connects (Android) to Chrome
/// - Navigates with the provided wait rule
/// - Starts a DevTools screencast, collects frames for [durationSeconds]
/// - Encodes frames into a GIF and saves per-URL
Future<void> screencastTask(
  List<String> urls,
  pup.Until untilConf,
  int maxWidth,
  int maxHeight,
      int durationSeconds,

  BuildContext context, {
  required Function(int, String) onProgress,

}) async {
  final savefold = await selectDirectory();
  String _savef = savefold ?? "savedScreencast";

  var browser;
  if (!Platform.isAndroid) {
    browser = await pup.puppeteer.launch();
  } else {
    final config = await showBrowserConfigDialog(context);
    if (config == null) {
      return; // User cancelled
    }

    browser = await pup.puppeteer.connect(
      browserUrl: config['browserUrl'],
      browserWsEndpoint: config['browserWsEndpoint'],
      defaultViewport: config['defaultViewport'],
      ignoreHttpsErrors: true,
    );
  }

  int indrun = 1;
  var page = await browser.newPage();

  for (final url in urls) {
    onProgress(indrun, url);

    await page.goto(
      url,
      wait: untilConf,
    );

    // Collect frames via DevTools screencast
    image.Image? animation;
    final sub = page.devTools.page.onScreencastFrame.listen((event) {
      try {
        final bytes = base64.decode(event.data);
        final frame = image.decodePng(bytes);
        if (frame != null) {
          if (animation == null) {
            animation = frame;
          } else {
            animation!.addFrame(frame);
          }
        }
      } catch (_) {
        // Ignore malformed frames
      }
    });

    // Optionally speed up CSS animations to capture more frames
    try {
      await page.devTools.animation.setPlaybackRate(240);
    } catch (_) {
      // Not critical if this fails
    }

    await page.devTools.page.startScreencast(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );

    await Future.delayed(Duration(seconds: durationSeconds));
    await page.devTools.page.stopScreencast();

    // Give a short moment to flush remaining frames
    await Future.delayed(const Duration(milliseconds: 200));
    await sub.cancel();

    final String tit = await page.title ?? '';
        final sanitizedTitle = tit.toLowerCase().trim().replaceAll(RegExp(r"[^a-z0-9_\-]+"), "-");

    final file = File('$_savef/_screencast_$sanitizedTitle-$indrun.gif');
    if (animation != null) {
      final gifBytes = image.GifEncoder().encode(animation!);
      await file.writeAsBytes(gifBytes);
    } else {
      // If no frames captured, create an empty file to signal attempt
      await file.writeAsBytes(const <int>[]);
    }

    indrun = indrun + 1;
  }

  await browser.close();
}