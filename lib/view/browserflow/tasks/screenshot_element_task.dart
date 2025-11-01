import 'dart:io';
import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;
import '../utils/browser_utils.dart';

Future<void> screenshotElementTask(
  List<String> urls,
  String selector,
  pup.Until untilConf,
  BuildContext context, {
  required Function(int, String) onProgress,
}) async {
  final savefold = await selectDirectory();
  String _savef = savefold ?? "savedElementShot";
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

      final element = await page.$(selector);
    if (element == null) {
      indrun = indrun + 1;
      continue;
    }

    final String tit = await page.title ?? '';
    final bytes = await element.screenshot();
    await File('$_savef/_element_${tit.toLowerCase().trim()}_$indrun.png').writeAsBytes(bytes);
    indrun = indrun + 1;
  }

  await browser.close();
}
