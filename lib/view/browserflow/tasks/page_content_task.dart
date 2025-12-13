import 'dart:io';
import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;
import '../utils/browser_utils.dart';

Future<void> pageContentTask(
  List<String> urls,
  pup.Until untilConf,
  BuildContext context, {
  required Function(int, String) onProgress,
}) async {
  final savefold = await selectDirectory();
  String _savef = savefold ?? "savedHtml";
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

    await page.goto(url, wait: untilConf);

    // Try the provided helper, fallback to evaluate if needed
    String html;
    try {
      html = await page.content;
    } catch (_) {
      html = await page.evaluate<String>('document.documentElement.outerHTML');
    }

    final String tit = await page.title ?? '';
    final sanitizedTitle = tit.toLowerCase().trim().replaceAll(
      RegExp(r"[^a-z0-9_\-]+"),
      "-",
    );
    final filePath =
        '$_savef/_page_${sanitizedTitle.isEmpty ? indrun.toString() : sanitizedTitle}_$indrun.html';
    await File(filePath).writeAsString(html);
    indrun = indrun + 1;
  }

  await browser.close();
}
