import 'dart:io';
import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;
import '../utils/browser_utils.dart';

Future<void> screenshotFullPageTask(
  List<String> urls,
  pup.Until untilConf,
  pup.Device? device,
  BuildContext context, {
  required Function(int, String) onProgress,
}) async {
  final savefold = await selectDirectory();
  String _savef = savefold ?? "savedScreenShot";
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

    if (device != null) {
      await page.emulate(device);
    }

    await page.goto(
      url,
      wait: untilConf,
    );

    final String tit = await page.title ?? '';
    var screenshot = await page.screenshot(fullPage: true);

    await File('$_savef/_screenshot_${tit.toLowerCase().trim()}_$indrun.png').writeAsBytes(screenshot);
    indrun = indrun + 1;
  }

  await browser.close();
}
