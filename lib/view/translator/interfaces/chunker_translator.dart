import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gpt_box/view/translator/docx_to_text_src.dart';
import 'package:gpt_box/view/translator/interfaces/configuration_interface.dart';
import 'package:gpt_box/view/translator/services/ocr.dart';
import 'package:gpt_box/view/translator/utils/colors.dart';
import 'package:gpt_box/view/translator/widgets/language_picker.dart';
import 'package:gpt_box/view/widget/chunker_interface.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:tiktoken/tiktoken.dart' as tk;

import '../../../main.dart';

part '../widgets/chunking_input.dart';

// UI and Chunking Parameters
ChunkingMethod selectedChunkingMethod = ChunkingMethod.lines;
final TextEditingController linesPerChunkController = TextEditingController(
  text: '10',
);
final TextEditingController wordsPerChunkController = TextEditingController(
  text: '100',
);
final TextEditingController charactersPerChunkController =
    TextEditingController(text: '1000');
final TextEditingController regexPatternController = TextEditingController(
  text: r'\n\n+',
);
final TextEditingController overlapController = TextEditingController(
  text: '0',
);
final TextEditingController targetLanguageController = TextEditingController(
  text: selectedDialogLanguage.name,
);

// Translation State

// Live token/cost and monitor

class ChunkerInterfaceand extends StatefulWidget {
  const ChunkerInterfaceand({super.key});

  @override
  State<ChunkerInterfaceand> createState() => _ChunkerInterfaceandState();
}

class _ChunkerInterfaceandState extends State<ChunkerInterfaceand> {
  // File and Content State

  final TranslationService translationService = TranslationService();
  late final tk.Tiktoken enc;
  List<String> chunks = [];
  List<String?>? translatedChunks;
  bool isTranslating = false;
  double translationProgress = 0.0;
  String? fileName;
  String originalFileContent =
      'Select a text file to display its content here.';
  String chunkedContent = 'Chunked content will appear here after processing.';
  String translatedContent = 'Translated content will appear here.';
  int inputTokens = 0;
  int outputTokens = 0;
  int lastResultTokens = 0;
  double usageCost = 0.0; // $ per 1K tokens math
  int rpmThisMinute = 0;
  int tpmThisMinute = 0;
  Timer? minuteTimer;
  bool monitoring = false;
  bool ocr = false;
    final GeminiOcrService _ocrService = GeminiOcrService();
  bool isOcrEnabled = false; // The state for the OCR checkbox
  List<PlatformFile> selectedFilesForOcr = [];
  bool isOcrProcessing = false;
  double ocrProgress = 0.0;
  @override
  void initState() {
    super.initState();
    enc = encoderForModel(translatorConfig.modelId);
  }

  @override
  void dispose() {
   linesPerChunkController.dispose();
    wordsPerChunkController.dispose();
    charactersPerChunkController.dispose();
    regexPatternController.dispose();
    overlapController.dispose();
    targetLanguageController.dispose();
    minuteTimer?.cancel();
    super.dispose();
  }

  tk.Tiktoken encoderForModel(String modelId) {
    final String enc =
        (modelId.contains('gpt-4.1') ||
            modelId.contains('gpt-4o') ||
            modelId.contains('o1'))
        ? 'o200k_base'
        : 'cl100k_base';
    return tk.getEncoding(enc);
  }

  int _countTokens(String text) => text.isEmpty ? 0 : enc.encode(text).length;

  void _recomputeUsageCost() {
    final double inCost = translatorConfig.inputCost;
    final double outCost = translatorConfig.outputCost;
    usageCost =
        (inputTokens / 1000000.0 * inCost) +
        (outputTokens / 1000000.0 * outCost);
  }

  Future<String> extractTextFromPdfBytes(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  void showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade600,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> pickFile(result) async {
    try {
      PlatformFile pf = result.files.single;
      fileName = pf.name;

      String content = '';
      final ext = (pf.extension ?? '').toLowerCase();

      if (ext == 'pdf' && ocr == false) {
        if (pf.bytes != null) {
          content = await extractTextFromPdfBytes(pf.bytes!);
        } else if (pf.readStream != null) {
          // stream into bytes for PDF
          final builder = BytesBuilder();
          await for (final chunk in pf.readStream!) {
            builder.add(chunk);
          }
          content = await extractTextFromPdfBytes(builder.takeBytes());
        } else if (pf.path != null) {
          final bytes = await File(pf.path!).readAsBytes();
          content = await extractTextFromPdfBytes(bytes);
        } else {
          throw Exception('No readable data for selected PDF.');
        }
      } else if (ext == 'doc' || ext == 'docx') {
        if (pf.bytes != null) {
          content = docxToText(pf.bytes!);
        } else if (pf.readStream != null) {
          // stream into bytes for PDF
          final builder = BytesBuilder();
          await for (final chunk in pf.readStream!) {
            builder.add(chunk);
          }
          content = docxToText(builder.takeBytes());
        } else if (pf.path != null) {
          final bytes = await File(pf.path!).readAsBytes();
          content = docxToText(bytes);
        } else {
          throw Exception('No readable data for selected Doc or Docx.');
        }
      }  else {
        if (pf.path != null) {
          // Prefer file path when available (fast and memory-safe)
          content = await File(pf.path!).readAsString();
        } else if (pf.readStream != null) {
          // Stream-decode text safely for huge files
          content = await pf.readStream!.transform(utf8.decoder).join();
        } else if (pf.bytes != null) {
          content = utf8.decode(pf.bytes!, allowMalformed: true);
        } else {
          throw Exception('No readable data for selected text file.');
        }
      }
      setState(() {
        originalFileContent = content;
        chunkedContent = 'Press "Chunk Text" to process.';
        translatedContent = 'Translate chunks to see the result.';
        chunks = [];
        translatedChunks = null;
        translationProgress = 0.0;

        // Live update tokens from input immediately
        inputTokens = _countTokens(originalFileContent);
        outputTokens = 0;
        lastResultTokens = 0;
        _recomputeUsageCost();
      });
    } catch (e) {
      showSnack('Error picking or reading file: $e', error: true);
    }
  }

  void _performChunking() {
    try {
      if (originalFileContent.isEmpty ||
          originalFileContent ==
              'Select a text file to display its content here.') {
        showSnack('Please select a file first.', error: true);
        return;
      }

      chunks = TextChunkerService.chunkText(
        originalContent: originalFileContent,
        method: selectedChunkingMethod,
        linesPerChunk: int.tryParse(linesPerChunkController.text) ?? 10,
        wordsPerChunk: int.tryParse(wordsPerChunkController.text) ?? 100,
        charactersPerChunk:
            int.tryParse(charactersPerChunkController.text) ?? 1000,
        regexPattern: regexPatternController.text,
        overlap: int.tryParse(overlapController.text) ?? 0,
      );

      setState(() {
        chunkedContent = chunks
            .asMap()
            .entries
            .map((e) => '--- Chunk ${e.key + 1} ---\n${e.value}')
            .join('\n\n');
        translatedContent = 'Ready to translate ${chunks.length} chunks.';
        translatedChunks = null;
        translationProgress = 0.0;

        // Input tokens as sum over chunks for better accuracy
        inputTokens = chunks.fold<int>(0, (sum, c) => sum + _countTokens(c));
        outputTokens = 0;
        lastResultTokens = 0;
        _recomputeUsageCost();
      });
    } catch (e) {
      showSnack('Error during chunking: $e', error: true);
    }
  }
    Future<void> _performOcr() async {
    if (selectedFilesForOcr.isEmpty) {
      showSnack('No files selected for OCR.', error: true);
      return;
    }
    // Note: Ensure your config page saves the Gemini API Key to translatorConfig.apiKey
    if (translatorConfig.apiKey.isEmpty) {
      showSnack('Gemini API key is not set in the configuration.',
          error: true);
      return;
    }

    setState(() {
      isOcrProcessing = true;
      ocrProgress = 0.0;
      originalFileContent =
          'Starting OCR process with Gemini for ${selectedFilesForOcr.length} files...';
      chunkedContent = '';
      translatedContent = '';
    });

    try {
      final String combinedText = await _ocrService.processFiles(
        files: selectedFilesForOcr,
        apiKey: translatorConfig.geminiApi,
   //  apiKey: translatorConfig.apiKey,
        onProgress: (completed, total) {
          setState(() {
            ocrProgress = completed / total;
          });
        },
      );

      setState(() {
        originalFileContent = combinedText.trim().isNotEmpty
            ? combinedText
            : 'OCR process finished, but no text was extracted.';
        chunkedContent = 'Press "Chunk Text" to process.';
        translatedContent = 'Translate chunks to see the result.';
        chunks = [];
        translatedChunks = null;
        translationProgress = 0.0;
        inputTokens = _countTokens(originalFileContent);
        outputTokens = 0;
        lastResultTokens = 0;
        _recomputeUsageCost();
        // Clear the selection after processing
        selectedFilesForOcr = [];
        fileName = 'OCR Completed. Content loaded.';
      });
    } catch (e) {
      showSnack('An error occurred during OCR processing: $e', error: true);
      setState(() {
        originalFileContent =
            'OCR failed. Please check your API key and network connection.';
      });
    } finally {
      setState(() {
        isOcrProcessing = false;
      });
    }
  }
  // void _startMinuteMonitor() {
  //   minuteTimer?.cancel();
  //   setState(() {
  //     rpmThisMinute = 0;
  //     tpmThisMinute = 0;
  //     monitoring = true;
  //   });
  //   minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
  //     setState(() {
  //       rpmThisMinute = 0;
  //       tpmThisMinute = 0;
  //     });
  //   });
  // }

  // void _stopMinuteMonitor() {
  //   minuteTimer?.cancel();
  //   setState(() {
  //     monitoring = false; // keep last counters visible until next run
  //   });
  // }

  Future<void> _performTranslation() async {
    if (chunks.isEmpty) {
      showSnack('Please chunk the text before translating.', error: true);
      return;
    }

    setState(() {
      isTranslating = true;
      translationProgress = 0.0;
      translatedChunks = List.filled(chunks.length, null);
      translatedContent = 'Translating...';
    });

    translationService.setApiKey(translatorConfig.apiKey);
    //  _startMinuteMonitor();
    int completedCount = 0;
    try {
      await translationService.translateChunksConcurrently(
        chunks: chunks,
        targetLanguage: translatorConfig.outputLang,
        onChunkTranslated: (index, translatedChunk) {
          setState(() {
            translatedChunks![index] = translatedChunk;
            completedCount++;
            translationProgress = completedCount / chunks.length;
          });
        },
        batchSize: translatorConfig.batchN,
      );
    } catch (e) {
      showSnack('Translation failed: $e', error: true);
    } finally {
      setState(() {
        isTranslating = false;
        translatedContent =
            translatedChunks?.where((s) => s != null).join('\n\n') ??
            'Translation finished with errors.';
        if (translatedContent.trim().isEmpty &&
            (translatedChunks?.isNotEmpty ?? false)) {
          translatedContent =
              'Translation finished, but content is empty. Check API key or response.';
        }
      });
    }
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.storage.request();
    if (status.isGranted || status.isLimited) return true;
    showSnack(
      'Storage permission denied. Trying SAF-based save...',
      error: false,
    );
    return false;
  }

  Future<void> _saveResult() async {
    final String contentToSave =
        translatedContent.isNotEmpty &&
            translatedContent != 'Translated content will appear here.'
        ? translatedContent
        : (chunkedContent.isNotEmpty &&
                  chunkedContent !=
                      'Chunked content will appear here after processing.'
              ? chunkedContent
              : originalFileContent);

    if (contentToSave.isEmpty ||
        contentToSave == 'Select a text file to display its content here.') {
      showSnack(
        'No content to save. Please load a file and process it.',
        error: true,
      );
      return;
    }

    final String? exportType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export as PDF'),
                onTap: () async {
                  // ... inside the 'Export as PDF' ListTile onTap callback
                  final String? dirPath = await FilePicker.platform
                      .getDirectoryPath();
                  if (dirPath == null) return;
                  final suggestedBase =
                      (fileName?.replaceAll(RegExp(r'\.[^.]+$'), '') ??
                      'output');
                  final pdfPath = p.join(dirPath, '$suggestedBase.pdf');

                  final PdfDocument document = PdfDocument();
                  final PdfPage page = document.pages.add();

                  // Use PdfTextElement for proper text wrapping and pagination
                  final PdfTextElement textElement = PdfTextElement(
                    text: contentToSave,
                    font: PdfStandardFont(PdfFontFamily.helvetica, 12),
                    brush: PdfSolidBrush(PdfColor(0, 0, 0)),
                  );

                  // Use a layout format that automatically paginates
                  final PdfLayoutFormat layoutFormat = PdfLayoutFormat(
                    layoutType: PdfLayoutType.paginate,
                  );

                  // Draw the text element on the page
                  textElement.draw(
                    page: page,
                    bounds: Rect.fromLTWH(
                      0,
                      0,
                      page.getClientSize().width,
                      page.getClientSize().height,
                    ),
                    format: layoutFormat,
                  );

                  // Save the document to the file
                  await File(
                    pdfPath,
                  ).writeAsBytes(await document.saveAsBytes());
                  document.dispose();

                  if (mounted) Navigator.of(context).pop('pdf');
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Export as TXT'),
                onTap: () async {
                  final String? dirPath = await FilePicker.platform
                      .getDirectoryPath();
                  if (dirPath == null) return;
                  final suggestedBase =
                      (fileName?.replaceAll(RegExp(r'\.[^.]+$'), '') ??
                      'output');
                  await _ensureStoragePermission();
                  final txtPath = p.join(dirPath, '$suggestedBase.txt');
                  await File(txtPath).writeAsString(contentToSave);
                  if (mounted) Navigator.of(context).pop('txt');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (exportType == null) return;
  }

  Widget monitorBar(BuildContext context) {
    final styleLabel = Theme.of(context).textTheme.labelSmall;
    final styleValue = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget chip(String label, String value, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.tealAccent),
              const SizedBox(width: 6),
            ],
            Text('$label ', style: styleLabel),
            Text(value, style: styleValue),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: -6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('Input tok', '$inputTokens', icon: Icons.input),
        //  chip('Output tok', '$outputTokens', icon: Icons.outbond),
        //  chip('Last result tok', '$lastResultTokens', icon: Icons.history),
        chip('Usage', usageCost.toStringAsFixed(4), icon: Icons.payments),
        //  chip('RPM (min)', '$rpmThisMinute', icon: Icons.av_timer),
        //   chip('TPM (min)', '$tpmThisMinute', icon: Icons.speed),
        chip(
          'Status',
          monitoring ? 'monitoring' : 'idle',
          icon: monitoring ? Icons.play_arrow : Icons.pause,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controls = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
           Row(
            children: [
              Checkbox(
                value: isOcrEnabled,
                onChanged: (bool? newValue) {
                  setState(() {
                    isOcrEnabled = newValue ?? false;
                    // Reset selections when switching modes
                    selectedFilesForOcr = [];
                    fileName = 'No file selected';
                  });
                },
              ),
              const Text('Enable OCR (for handwritten PDFs & images)'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    if (isOcrEnabled) {
                      FilePickerResult? result = await FilePicker.platform
                          .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                        allowMultiple: true,
                        withData: true,
                      );
                      if (result != null) {
                        setState(() {
                          selectedFilesForOcr = result.files;
                          fileName =
                              '${result.files.length} file(s) selected for OCR.';
                        });
                      }
                    } else {
                      FilePickerResult? result = await FilePicker.platform
                          .pickFiles(
                        type: FileType.any,
                        withData: true,
                      );
                      if (result != null) {
                        await pickFile(result);
                      }
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                      isOcrEnabled ? 'Select Files for OCR' : 'Select File'),
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ConfigPage())),
                icon: const Icon(Icons.settings),
                label: const Text('Open Config'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              fileName ?? 'No file selected',
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          SizedBox(height: 12),
    if (isOcrEnabled && selectedFilesForOcr.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isOcrProcessing ? null : _performOcr,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Perform OCR'),
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.orange.shade700),
                  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            child: Text('Target Language ${translatorConfig.outputLang}'),
            onPressed: () {
              openLanguagePickerDialog(context);
              setState(() {});
            },
          ),
          SizedBox(height: 8),
          Divider(height: 12),

          // Chunking options
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ChunkingMethod.values.map((method) {
                return ChoiceChip(
                  label: Text(
                    method.name[0].toUpperCase() + method.name.substring(1),
                  ),
                  selected: selectedChunkingMethod == method,
                  onSelected: (selected) =>
                      setState(() => selectedChunkingMethod = method),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _buildChunkingInputs(),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _performChunking,
                  icon: const Icon(Icons.cut),
                  label: const Text('Chunk Text'),
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isTranslating ? null : _performTranslation,
                  icon: const Icon(Icons.translate),
                  label: const Text('Translate Chunks'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled))
                        return Colors.grey.shade600;
                      return Colors.green.shade600;
                    }),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    minimumSize: const WidgetStatePropertyAll(
                      Size.fromHeight(48),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveResult,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Result'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      Colors.blue.shade600,
                    ),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    minimumSize: const WidgetStatePropertyAll(
                      Size.fromHeight(48),
                    ),
                  ),
                ),
              ),
            ],
          ),
             if (isOcrProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: ocrProgress,
                    backgroundColor: Colors.orange.shade900,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Performing OCR... ${(ocrProgress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          if (isTranslating)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: translationProgress),
                  const SizedBox(height: 4),
                  Text(
                    'Translating... ${(translationProgress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          monitorBar(context),
        ],
      ),
    );

    final contentTabs = DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.description), text: 'Original'),
              Tab(icon: Icon(Icons.segment), text: 'Chunked'),
              Tab(icon: Icon(Icons.translate), text: 'Translated'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ContentDisplayBox(
                  title: 'Original Content',
                  content: originalFileContent,
                ),
                ContentDisplayBox(
                  title: 'Chunked Content (${chunks.length} chunks)',
                  content: chunkedContent,
                ),
                ContentDisplayBox(
                  title: 'Translated Content',
                  content: translatedContent,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return MaterialApp(
      title: 'File Chunker & Translator',
      theme: AppThemes.awesomeDarkTheme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('File Chunker & Translator'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Configuration',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ConfigPage())),
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 24 : 8,
                          ),
                          child: controls,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  Expanded(flex: 2, child: contentTabs),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
