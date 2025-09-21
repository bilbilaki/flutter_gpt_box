
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';


// Assuming TranslationService and ChunkingMethod enums are defined in chunker_service.dart
// And ContentDisplayBox is defined in lib/widgets/content_box.dart as provided below.
import 'package:gpt_box/data/res/openai.dart';
import 'package:openai_dart/openai_dart.dart';

/// Enum to define different chunking methods for text.
enum ChunkingMethod {
  lines,
  words,
  regex,
  characters,
}

/// Service class responsible for text chunking operations.
class TextChunkerService {
  static List<String> chunkText({
    required String originalContent,
    required ChunkingMethod method,
    int linesPerChunk = 10,
    int wordsPerChunk = 100,
    int charactersPerChunk = 500,
    String regexPattern = r'\n\n+',
    int overlap = 0,
  }) {
    if (originalContent.isEmpty) return [];

    if (overlap < 0) {
      throw ArgumentError('Overlap must be a non-negative number.');
    }

    List<String> chunks = [];

    switch (method) {
      case ChunkingMethod.lines:
        if (linesPerChunk <= 0) throw ArgumentError('Lines per chunk must be a positive number.');
        if (overlap >= linesPerChunk) throw ArgumentError('Overlap must be smaller than lines per chunk.');

        final List<String> contentLines = originalContent.split('\n');
        int step = linesPerChunk - overlap;
        for (int i = 0; i < contentLines.length; i += step) {
          int end = (i + linesPerChunk > contentLines.length) ? contentLines.length : i + linesPerChunk;
          chunks.add(contentLines.sublist(i, end).join('\n'));
          if (end == contentLines.length) break;
        }
        break;

      case ChunkingMethod.words:
        if (wordsPerChunk <= 0) throw ArgumentError('Words per chunk must be a positive number.');
        if (overlap >= wordsPerChunk) throw ArgumentError('Overlap must be smaller than words per chunk.');

        final List<String> contentWords = originalContent.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
        int step = wordsPerChunk - overlap;
        for (int i = 0; i < contentWords.length; i += step) {
          int end = (i + wordsPerChunk > contentWords.length) ? contentWords.length : i + wordsPerChunk;
          chunks.add(contentWords.sublist(i, end).join(' '));
          if (end == contentWords.length) break;
        }
        break;

      case ChunkingMethod.characters:
        if (charactersPerChunk <= 0) throw ArgumentError('Characters per chunk must be a positive number.');
        if (overlap >= charactersPerChunk) throw ArgumentError('Overlap must be smaller than characters per chunk.');

        final String content = originalContent;
        int step = charactersPerChunk - overlap;
        for (int i = 0; i < content.length; i += step) {
          int end = (i + charactersPerChunk > content.length) ? content.length : i + charactersPerChunk;
          chunks.add(content.substring(i, end));
          if (end == content.length) break;
        }
        break;

      case ChunkingMethod.regex:
        if (regexPattern.isEmpty) throw ArgumentError('Regex pattern cannot be empty.');
        final RegExp regExp = RegExp(regexPattern);
        chunks = originalContent.split(regExp).where((s) => s.isNotEmpty).toList();
        break;
    }

    if (chunks.isEmpty && originalContent.isNotEmpty) {
      chunks.add(originalContent);
    }
    return chunks;
  }
}

/// Service for handling translation via OpenAI API.
class TranslationService {
  // A single client can handle concurrent requests.
  OpenAIClient? _client;

  // Use a setter for the API key to initialize the client.
  void setApiKey(String apiKey) {
    if (apiKey.isNotEmpty) {
      _client = OpenAIClient(apiKey: Cfg.current.key, baseUrl: Cfg.current.url);
    } else {
      _client = null;
    }
  }

  Future<String> _translateTextChunk(String text, String targetLanguage) async {
    if (_client == null) {
      throw Exception('API Key not set. Please provide a valid OpenAI API key.');
    }
    if (text.trim().isEmpty) {
      return text; // Return empty or whitespace text as is.
    }

    final prompt = 'Translate the following text to $targetLanguage. Return only the translated text, without any introductory phrases or explanations.';

    try {
      final res = await _client!.createChatCompletion(
        request: CreateChatCompletionRequest(
          // Using a standard, reliable OpenAI model.
          model: const ChatCompletionModel.modelId('gemini-2.5-flash-lite'),
          messages: [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('$prompt\n\nText: """$text"""'),
            ),
          ],
          temperature: 0.2, // Lower temperature for more deterministic translations.
        ),
      );
      return res.choices.first.message.content?.trim() ?? '[Translation Failed: Empty Response]';
    } catch (e) {
      // Return a specific error message for this chunk.
      return '[Translation Error: ${e.toString()}]';
    }
  }

  /// Translates a list of text chunks concurrently.
  ///
  /// This method processes chunks in batches to avoid overwhelming the API and to manage memory.
  /// It's more stable than managing a complex queue of individual futures.
  Future<void> translateChunksConcurrently({
    required List<String> chunks,
    required String targetLanguage,
    required Function(int index, String translatedChunk) onChunkTranslated,
    int batchSize = 5, // Process 5 chunks at a time. Adjust based on performance.
  }) async {
    if (_client == null) {
      throw Exception('API Key not set before starting translation.');
    }

    for (int i = 0; i < chunks.length; i += batchSize) {
      // Determine the end of the current batch.
      int end = (i + batchSize > chunks.length) ? chunks.length : i + batchSize;
      List<String> batchChunks = chunks.sublist(i, end);

      // Create a list of translation futures for the current batch.
      List<Future<String>> batchFutures = batchChunks
          .map((chunk) => _translateTextChunk(chunk, targetLanguage))
          .toList();

      // Wait for all translations in the current batch to complete.
      List<String> translatedBatch = await Future.wait(batchFutures);

      // Report progress for each completed chunk in the batch.
      for (int j = 0; j < translatedBatch.length; j++) {
        onChunkTranslated(i + j, translatedBatch[j]);
      }
    }
  }
}
class ChunkerInterface extends StatefulWidget {
  const ChunkerInterface({super.key});

  @override
  State<ChunkerInterface> createState() => _ChunkerInterfaceState();
}

class _ChunkerInterfaceState extends State<ChunkerInterface> {
  // File and Content State
  String? _fileName;
  String _originalFileContent = 'Select a text file to display its content here.';
  String _chunkedContent = 'Chunked content will appear here after processing.';
  String _translatedContent = 'Translated content will appear here.';

  // UI and Chunking Parameters
  ChunkingMethod _selectedChunkingMethod = ChunkingMethod.lines;
  final TextEditingController _linesPerChunkController = TextEditingController(text: '10');
  final TextEditingController _wordsPerChunkController = TextEditingController(text: '100');
  final TextEditingController _charactersPerChunkController = TextEditingController(text: '1000');
  final TextEditingController _regexPatternController = TextEditingController(text: r'\n\n+');
  final TextEditingController _overlapController = TextEditingController(text: '0');

  // Translation State (API Key related parts removed from UI)
  final TextEditingController _targetLanguageController = TextEditingController(text: 'Spanish');
  // NOTE: TranslationService would need to handle API key internally (e.g., from environment variables)
  // or be modified not to require one from the UI if it's strictly removed.
  final TranslationService _translationService = TranslationService();
  List<String> _chunks = [];
  List<String?>? _translatedChunks;
  bool _isTranslating = false;
  double _translationProgress = 0.0;

  @override
  void dispose() {
    _linesPerChunkController.dispose();
    _wordsPerChunkController.dispose();
    _charactersPerChunkController.dispose();
    _regexPatternController.dispose();
    _overlapController.dispose();
    _targetLanguageController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        PlatformFile platformFile = result.files.single;
        File file = File(platformFile.path!);
        String content = await file.readAsString();
        setState(() {
          _fileName = platformFile.name;
          _originalFileContent = content;
          _chunkedContent = 'Press "Chunk Text" to process.';
          _translatedContent = 'Translate chunks to see the result.';
          _chunks = [];
          _translatedChunks = null;
          _translationProgress = 0.0;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking or reading file: $e');
    }
  }

  void _performChunking() {
    if (_originalFileContent == 'Select a text file to display its content here.') {
      _showErrorSnackBar('Please select a file first.');
      return;
    }
    try {
      _chunks = TextChunkerService.chunkText(
        originalContent: _originalFileContent,
        method: _selectedChunkingMethod,
        linesPerChunk: int.tryParse(_linesPerChunkController.text) ?? 10,
        wordsPerChunk: int.tryParse(_wordsPerChunkController.text) ?? 100,
        charactersPerChunk: int.tryParse(_charactersPerChunkController.text) ?? 1000,
        regexPattern: _regexPatternController.text,
        overlap: int.tryParse(_overlapController.text) ?? 0,
      );

      setState(() {
        _chunkedContent = _chunks.asMap().entries.map((entry) {
          return '--- Chunk ${entry.key + 1} ---\n${entry.value}';
        }).join('\n\n');
        _translatedContent = 'Ready to translate ${_chunks.length} chunks.';
        _translatedChunks = null;
        _translationProgress = 0.0;
      });
    } catch (e) {
      _showErrorSnackBar('Error during chunking: $e');
    }
  }

  Future<void> _performTranslation() async {
    if (_chunks.isEmpty) {
      _showErrorSnackBar('Please chunk the text before translating.');
      return;
    }
    // API Key check removed as per request. TranslationService must handle API key internally.
    // _translationService.setApiKey(_apiKeyController.text); // This line is removed as API key input is removed

    setState(() {
      _isTranslating = true;
      _translationProgress = 0.0;
      _translatedChunks = List.filled(_chunks.length, null);
      _translatedContent = 'Translating...';
    });

    int completedCount = 0;

    try {
      await _translationService.translateChunksConcurrently(
        chunks: _chunks,
        targetLanguage: _targetLanguageController.text,
        onChunkTranslated: (index, translatedChunk) {
          setState(() {
            _translatedChunks![index] = translatedChunk;
            completedCount++;
            _translationProgress = completedCount / _chunks.length;
          });
        },
      );
    } catch (e) {
      _showErrorSnackBar('Translation failed: $e');
    } finally {
      setState(() {
        _isTranslating = false;
        _translatedContent = _translatedChunks?.where((s) => s != null).join('\n\n') ??
            'Translation finished with errors or no chunks.';
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900; // Define a breakpoint for large screens

    return MaterialApp(
      title: 'Flutter File Chunker & Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          centerTitle: true,
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.shadow,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
            selectedForegroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('File Chunker & Translator'),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? screenWidth * 0.05 : 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // File Selection & Target Language Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuration',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Divider(height: 24, thickness: 1),
                      // File Picker
                      isLargeScreen
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('Select File'),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _fileName ?? 'No file selected',
                                    textAlign: TextAlign.start,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickFile,
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('Select File'),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _fileName ?? 'No file selected',
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                      const SizedBox(height: 24),
                      // Target Language
                      TextField(
                        controller: _targetLanguageController,
                        decoration: const InputDecoration(
                          labelText: 'Target Language',
                          prefixIcon: Icon(Icons.language),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Chunking Options Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chunking Parameters',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Divider(height: 24, thickness: 1),
                      // Chunking Method Selection
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ChunkingMethod>(
                          segments: ChunkingMethod.values.map((method) {
                            return ButtonSegment<ChunkingMethod>(
                              value: method,
                              label: Text(
                                method.name[0].toUpperCase() + method.name.substring(1),
                              ),
                            );
                          }).toList(),
                          selected: {_selectedChunkingMethod},
                          onSelectionChanged: (Set<ChunkingMethod> newSelection) {
                            setState(() {
                              _selectedChunkingMethod = newSelection.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Dynamic Chunking Parameters
                      if (_selectedChunkingMethod == ChunkingMethod.lines)
                        TextField(
                          controller: _linesPerChunkController,
                          decoration: const InputDecoration(labelText: 'Lines per chunk'),
                          keyboardType: TextInputType.number,
                        )
                      else if (_selectedChunkingMethod == ChunkingMethod.words)
                        TextField(
                          controller: _wordsPerChunkController,
                          decoration: const InputDecoration(labelText: 'Words per chunk'),
                          keyboardType: TextInputType.number,
                        )
                      else if (_selectedChunkingMethod == ChunkingMethod.characters)
                        TextField(
                          controller: _charactersPerChunkController,
                          decoration: const InputDecoration(labelText: 'Characters per chunk'),
                          keyboardType: TextInputType.number,
                        )
                      else
                        TextField(
                          controller: _regexPatternController,
                          decoration: const InputDecoration(labelText: 'Regex Pattern'),
                        ),
                      const SizedBox(height: 16),
                      if (_selectedChunkingMethod != ChunkingMethod.regex)
                        TextField(
                          controller: _overlapController,
                          decoration: InputDecoration(
                              labelText: 'Overlap (in ${_selectedChunkingMethod.name.toLowerCase()})'),
                          keyboardType: TextInputType.number,
                        ),
                      const SizedBox(height: 24),
                      // Action Buttons for chunking
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _performChunking,
                              icon: const Icon(Icons.cut),
                              label: const Text('Chunk Text'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isTranslating ? null : _performTranslation,
                              icon: const Icon(Icons.translate),
                              label: const Text('Translate Chunks'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isTranslating)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Column(
                            children: [
                              LinearProgressIndicator(value: _translationProgress),
                              const SizedBox(height: 8),
                              Text(
                                  'Translating... ${(_translationProgress * 100).toStringAsFixed(0)}%'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Content Display Section
              Text(
                'Content Display',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 24, thickness: 1),
              isLargeScreen
                  ? IntrinsicHeight( // Use IntrinsicHeight to make content boxes same height
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children to fill height
                        children: [
                          Expanded(
                            child: Card(
                                child: ContentDisplayBox(
                                    title: 'Original Content', content: _originalFileContent)),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Card(
                                child: ContentDisplayBox(
                                    title: 'Chunked Content (${_chunks.length} chunks)',
                                    content: _chunkedContent)),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Card(
                                child: ContentDisplayBox(
                                    title: 'Translated Content', content: _translatedContent)),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Card(
                            child: ContentDisplayBox(
                                title: 'Original Content', content: _originalFileContent)),
                        Card(
                            child: ContentDisplayBox(
                                title: 'Chunked Content (${_chunks.length} chunks)',
                                content: _chunkedContent)),
                        Card(
                            child: ContentDisplayBox(
                                title: 'Translated Content', content: _translatedContent)),
                      ],
                    ),
              const SizedBox(height: 24), // Add some space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}

// lib/widgets/content_box.dart (provided for completeness as it's part of the UI rebuild)
// This file should exist at the specified import path.

//import 'package:flutter/material.dart';

class ContentDisplayBox extends StatelessWidget {
  final String title;
  final String content;

  const ContentDisplayBox({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), // Padding for title
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge, // Material 3 title style
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Padding for the content box
            child: Container(
              padding: const EdgeInsets.all(16), // Inner padding for the content
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12), // Rounded corners for content box
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), // Lighter background
              ),
              child: SingleChildScrollView( // Allow content to scroll
                child: Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
//*/