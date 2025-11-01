import 'dart:io';
import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;
import '../utils/browser_utils.dart';

Future<void> generatePDFTask(
  List<String> urls,
  pup.Until untilConf,
  BuildContext context, {
  required Function(int, String) onProgress,
}) async {
  final savefold = await selectDirectory();
  String _savef = savefold ?? "savedPdf";
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

    await page.emulateMediaType(pup.MediaType.screen);
    final String tit = await page.title ?? '';

    await page.pdf(
      format: pup.PaperFormat.a4,
      printBackground: true,
      pageRanges: '1',
      output: File('$_savef/_resultPdf_${tit.toLowerCase().trim()}_$indrun.pdf').openWrite(),
    );
    indrun = indrun + 1;
  }

  await browser.close();
}
