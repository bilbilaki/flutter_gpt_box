

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../generated_bindings.dart';

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:responsive_framework/responsive_framework.dart';

class SearchResultResponse {
  final String file;
  final int lineNumber;
  final String lineText;
  final int matchPos;
  final String type;
  final int score;
  final String searchId;
  final bool? isAIProposed;
  final String? patchId;
  final String? changeStatus;
  final Map<String, dynamic>? validationInfo;
  final List<String>? relatedPatches;

  SearchResultResponse({
    required this.file,
    required this.lineNumber,
    required this.lineText,
    required this.matchPos,
    required this.type,
    required this.score,
    required this.searchId,
    this.isAIProposed,
    this.patchId,
    this.changeStatus,
    this.validationInfo,
    this.relatedPatches,
  });

  factory SearchResultResponse.fromJson(Map<String, dynamic> json) {
    return SearchResultResponse(
      file: json['file'] ?? '',
      lineNumber: json['lineNumber'] ?? 0,
      lineText: json['lineText'] ?? '',
      matchPos: json['matchPos'] ?? 0,
      type: json['type'] ?? ' ',
      score: json['score'] ?? 0,
      searchId: json['searchId'] ?? '',
      isAIProposed: json['isAIProposed'],
      patchId: json['patchId'],
      changeStatus: json['changeStatus'],
      validationInfo: json['validationInfo'] != null
          ? Map<String, dynamic>.from(json['validationInfo'])
          : null,
      relatedPatches: json['relatedPatches'] != null
          ? List<String>.from(json['relatedPatches'])
          : null,
    );
  }
}

class PartialDiff {
  final String targetFile;
  final String hunkID;
  final List<int> originalLines;
  final List<int> proposedLines;
  final int contextLines;
  final String diffContent;
  final String explanation;
  final String changeType;
  final List<String> dependencies;

  PartialDiff({
    required this.targetFile,
    required this.hunkID,
    required this.originalLines,
    required this.proposedLines,
    required this.contextLines,
    required this.diffContent,
    required this.explanation,
    required this.changeType,
    required this.dependencies,
  });

  factory PartialDiff.fromJson(Map<String, dynamic> json) {
    return PartialDiff(
      targetFile: json['targetFile'] ?? '',
      hunkID: json['hunkID'] ?? '',
      originalLines: List<int>.from(json['originalLines'] ?? []),
      proposedLines: List<int>.from(json['proposedLines'] ?? []),
      contextLines: json['contextLines'] ?? 0,
      diffContent: json['diffContent'] ?? '',
      explanation: json['explanation'] ?? '',
      changeType: json['changeType'] ?? 'modification',
      dependencies: List<String>.from(json['dependencies'] ?? []),
    );
  }
}

class AIResponse {
  final List<PartialDiff> generatedDiffs;
  final List<String> explanations;
  final double confidenceScore;
  final List<String> warnings;
  final List<String> suggestedFiles;

  AIResponse({
    required this.generatedDiffs,
    required this.explanations,
    required this.confidenceScore,
    required this.warnings,
    required this.suggestedFiles,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      generatedDiffs: (json['generatedDiffs'] as List? ?? [])
          .map((e) => PartialDiff.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      explanations: List<String>.from(json['explanations'] ?? []),
      confidenceScore: (json['confidenceScore'] ?? 0.0).toDouble(),
      warnings: List<String>.from(json['warnings'] ?? []),
      suggestedFiles: List<String>.from(json['suggestedFiles'] ?? []),
    );
  }
}

class AppliedPatch {
  final String id;
  final String targetFile;
  final List<int> originalLines;
  final List<int> appliedLines;
  final String originalContent;
  final String newContent;
  final double matchConfidence;
  final String changeSummary;
  final String timestamp;
  final bool dryRun;
  final String gitPatch;
  final List<String> validationErrors;

  AppliedPatch({
    required this.id,
    required this.targetFile,
    required this.originalLines,
    required this.appliedLines,
    required this.originalContent,
    required this.newContent,
    required this.matchConfidence,
    required this.changeSummary,
    required this.timestamp,
    required this.dryRun,
    required this.gitPatch,
    required this.validationErrors,
  });

  factory AppliedPatch.fromJson(Map<String, dynamic> json) {
    return AppliedPatch(
      id: json['id'] ?? '',
      targetFile: json['targetFile'] ?? '',
      originalLines: List<int>.from(json['originalLines'] ?? []),
      appliedLines: List<int>.from(json['appliedLines'] ?? []),
      originalContent: json['originalContent'] ?? '',
      newContent: json['newContent'] ?? '',
      matchConfidence: (json['matchConfidence'] ?? 0.0).toDouble(),
      changeSummary: json['changeSummary'] ?? '',
      timestamp: json['timestamp'] ?? '',
      dryRun: json['dryRun'] ?? false,
      gitPatch: json['gitPatch'] ?? '',
      validationErrors: List<String>.from(json['validationErrors'] ?? []),
    );
  }
}

class PatchStoreStatus {
  final bool exists;
  final String? message;
  final int? pendingDiffs;
  final int? appliedPatches;

  PatchStoreStatus({
    required this.exists,
    this.message,
    this.pendingDiffs,
    this.appliedPatches,
  });

  factory PatchStoreStatus.fromJson(Map<String, dynamic> json) {
    return PatchStoreStatus(
      exists: json['exists'] ?? false,
      message: json['message'],
      pendingDiffs: json['pendingDiffs'],
      appliedPatches: json['appliedPatches'],
    );
  }
}

enum GoResponseType {
  searchResults,
  aiContextGenerated,
  patchApplied,
  patchStoreStatus,
  error,
  logMessage,
}

class GoResponseEvent {
  final GoResponseType type;
  final dynamic data;
  final String? rawMessage;
  final DateTime timestamp;

  GoResponseEvent({
    required this.type,
    this.data,
    this.rawMessage,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'GoResponseEvent{type: $type, data: $data, timestamp: $timestamp}';
  }
}

class JuicityService {
  late final libgofalow _bindings;
  late final DynamicLibrary _dylib;

  final _logStreamController = StreamController<String>.broadcast();
  final _structuredDataStreamController =
      StreamController<GoResponseEvent>.broadcast();

  Stream<String> get logStream => _logStreamController.stream;
  Stream<GoResponseEvent> get structuredDataStream =>
      _structuredDataStreamController.stream;

  late final ReceivePort _port;
  int get nativePort => _port.sendPort.nativePort;

  JuicityService() {
    _dylib = _loadLibrary();
    _bindings = libgofalow(_dylib);
    _port = ReceivePort();
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) {
      final libPath = p.join(Directory.current.path, 'native', 'linux', 'libgofalow.so');
      return DynamicLibrary.open(libPath);
    } else if (Platform.isWindows) {
      final libPath = p.join(Directory.current.path, 'native', 'windows', 'libgofalow.dll');
      return DynamicLibrary.open(libPath);
    } else if (Platform.isMacOS) {
      final libPath = p.join(Directory.current.path, 'native', 'macos', 'libgofalow.dylib');
      return DynamicLibrary.open(libPath);
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  void initialize() {
    _bindings.InitDartApi(NativeApi.initializeApiDLData);
    _logStreamController.add("Dart API initialized for Go bridge.");

    _port.listen((message) {
      _handleGoMessage(message);
    });

    _logStreamController.add("JuicityService initialized with structured data support.");
  }

  void _handleGoMessage(dynamic message) {
    if (message is String) {
      try {
        final jsonData = jsonDecode(message);
        _handleStructuredData(jsonData, message);
      } catch (_) {
        _logStreamController.add(message);
        _structuredDataStreamController.add(
          GoResponseEvent(type: GoResponseType.logMessage, rawMessage: message),
        );
      }
    } else {
      _logStreamController.add('Unknown message type: ${message.runtimeType}');
    }
  }

  void _handleStructuredData(dynamic jsonData, String rawMessage) {
    try {
      if (jsonData is Map<String, dynamic>) {
        if (jsonData.containsKey('success') && jsonData.containsKey('data')) {
          _handleDartResponse(jsonData);
        } else if (jsonData.containsKey('exists')) {
          final status = PatchStoreStatus.fromJson(jsonData);
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.patchStoreStatus,
            data: status,
            rawMessage: rawMessage,
          ));
        } else if (jsonData.containsKey('generatedDiffs')) {
          final aiResponse = AIResponse.fromJson(jsonData);
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.aiContextGenerated,
            data: aiResponse,
            rawMessage: rawMessage,
          ));
        } else if (jsonData.containsKey('id') && jsonData.containsKey('targetFile')) {
          final appliedPatch = AppliedPatch.fromJson(jsonData);
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.patchApplied,
            data: appliedPatch,
            rawMessage: rawMessage,
          ));
        } else if (jsonData.containsKey('file') && jsonData.containsKey('lineNumber')) {
          _handleSearchResults(jsonData, rawMessage);
        } else {
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.logMessage,
            data: jsonData,
            rawMessage: rawMessage,
          ));
        }
      } else if (jsonData is List) {
        _handleSearchResults(jsonData, rawMessage);
      }
    } catch (e) {
      _logStreamController.add('Error parsing structured data: $e\nRaw: $rawMessage');
      _structuredDataStreamController.add(
        GoResponseEvent(type: GoResponseType.error, rawMessage: 'Parse error: $e\nData: $rawMessage'),
      );
    }
  }

  void _handleDartResponse(Map<String, dynamic> response) {
    final success = response['success'] ?? false;
    final data = response['data'];
    final message = response['message'] ?? '';

    if (!success) {
      _structuredDataStreamController.add(GoResponseEvent(
        type: GoResponseType.error,
        data: {'message': message, 'data': data},
        rawMessage: message,
      ));
      return;
    }

    if (data != null) {
      try {
        final parsedData = jsonDecode(data);
        _handleStructuredData(parsedData, data);
      } catch (_) {
        _structuredDataStreamController.add(GoResponseEvent(
          type: GoResponseType.logMessage,
          data: {'message': message, 'data': data},
          rawMessage: data,
        ));
      }
    }
  }

  void _handleSearchResults(dynamic resultsData, String rawMessage) {
    try {
      if (resultsData is List) {
        final results = resultsData.map((e) {
          if (e is Map<String, dynamic>) {
            return SearchResultResponse.fromJson(e);
          } else {
            return SearchResultResponse(
              file: '',
              lineNumber: 0,
              lineText: e.toString(),
              matchPos: 0,
              type: ' ',
              score: 0,
              searchId: '',
            );
          }
        }).toList();

        _structuredDataStreamController.add(GoResponseEvent(
          type: GoResponseType.searchResults,
          data: results,
          rawMessage: rawMessage,
        ));
      } else if (resultsData is Map<String, dynamic>) {
        final searchResult = SearchResultResponse.fromJson(resultsData);
        _structuredDataStreamController.add(GoResponseEvent(
          type: GoResponseType.searchResults,
          data: [searchResult],
          rawMessage: rawMessage,
        ));
      }
    } catch (e) {
      _logStreamController.add('Error parsing search results: $e');
      _structuredDataStreamController.add(
        GoResponseEvent(type: GoResponseType.error, rawMessage: 'Search results parse error: $e'),
      );
    }
  }

  Future<List<SearchResultResponse>> searchWithConfig(Map<String, dynamic> config) async {
    final completer = Completer<List<SearchResultResponse>>();
    late final StreamSubscription<GoResponseEvent> sub;

    sub = structuredDataStream.listen((event) {
      if (event.type == GoResponseType.searchResults) {
        completer.complete((event.data as List).cast<SearchResultResponse>());
        sub.cancel();
      } else if (event.type == GoResponseType.error) {
        completer.completeError(event.rawMessage ?? 'Search failed');
        sub.cancel();
      }
    });

    startSearch(jsonEncode(config));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('Search operation timed out');
      },
    );
  }

  Future<AIResponse> generateAIContextWithRequest(Map<String, dynamic> request) async {
    final completer = Completer<AIResponse>();
    late final StreamSubscription<GoResponseEvent> sub;

    sub = structuredDataStream.listen((event) {
      if (event.type == GoResponseType.aiContextGenerated) {
        completer.complete(event.data as AIResponse);
        sub.cancel();
      } else if (event.type == GoResponseType.error) {
        completer.completeError(event.rawMessage ?? 'AI context generation failed');
        sub.cancel();
      }
    });

    generateAIContext(jsonEncode(request));

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('AI context generation timed out');
      },
    );
  }

  void getPatchStoreStatus(String searchID) {
    final ptr = searchID.toNativeUtf8();
    try {
      _bindings.GetPatchStoreStatus(nativePort, ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  void cleanupPatchStore(String searchID) {
    final ptr = searchID.toNativeUtf8();
    try {
      _bindings.CleanupPatchStore(ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  void startSearch(String configJson) {
    final ptr = configJson.toNativeUtf8();
    try {
      _bindings.StartSearch(nativePort, ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  void stopSearch(String searchID) {
    final ptr = searchID.toNativeUtf8();
    try {
      _bindings.StopSearch(ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  void generateAIContext(String requestJson) {
    final ptr = requestJson.toNativeUtf8();
    try {
      _bindings.GenerateAIContext(nativePort, ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  void applyAIPatch(String patchID, String searchID, String matchResultJson) {
    final patchPtr = patchID.toNativeUtf8();
    final idPtr = searchID.toNativeUtf8();
    final matchPtr = matchResultJson.toNativeUtf8();
    try {
      _bindings.ApplyAIPatch(nativePort, patchPtr.cast(), idPtr.cast(), matchPtr.cast());
    } finally {
      malloc.free(patchPtr);
      malloc.free(idPtr);
      malloc.free(matchPtr);
    }
  }

  void searchAIChanges(String configJson) {
    final ptr = configJson.toNativeUtf8();
    try {
      _bindings.SearchAIChanges(nativePort, ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  void dispose() {
    _logStreamController.close();
    _structuredDataStreamController.close();
    _port.close();
  }
}


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Search & Diff App',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.purpleAccent,
          surface: Colors.grey[900]!,
          background: Colors.grey[850]!,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.grey[800],
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[800],
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: BouncingScrollWrapper.builder(context, child!),
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      home: const FileSearchScreen(),
    );
  }
}

class FileContent {
  final String fileName;
  final String filePath;
  String content;
  final String fileExtension;
  bool isSelected;

  FileContent({
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.fileExtension,
    this.isSelected = false,
  });

  @override
  String toString() {
    return 'FileContent{fileName: $fileName, filePath: $filePath, contentLength: ${content.length}, fileExtension: $fileExtension, isSelected: $isSelected}';
  }
}

class DiffHunk {
  final int oldStartLine;
  final int oldNumLines;
  final int newStartLine;
  final int newNumLines;
  final List<String> lines;

  DiffHunk({
    required this.oldStartLine,
    required this.oldNumLines,
    required this.newStartLine,
    required this.newNumLines,
    required this.lines,
  });

  DiffHunk copyWith({List<String>? lines}) {
    return DiffHunk(
      oldStartLine: oldStartLine,
      oldNumLines: oldNumLines,
      newStartLine: newStartLine,
      newNumLines: newNumLines,
      lines: lines ?? this.lines,
    );
  }

  @override
  String toString() {
    return 'Hunk(old:$oldStartLine,$oldNumLines new:$newStartLine,$newNumLines lines:${lines.length})';
  }
}

class FileSearchScreen extends StatefulWidget {
  const FileSearchScreen({super.key});
  @override
  State<FileSearchScreen> createState() => _FileSearchScreenState();
}

class _FileSearchScreenState extends State<FileSearchScreen> {
  String? selectedPath;
  final TextEditingController _fileTypeController =
      TextEditingController(text: '.dart,.json,.yaml');
  final TextEditingController _excludePatternController = TextEditingController();
  final TextEditingController _diffInputController = TextEditingController();

  final TextEditingController _includePathPatternController = TextEditingController();
  final TextEditingController _excludePathPatternController = TextEditingController();
  final TextEditingController _includeFileNamePatternController = TextEditingController();
  final TextEditingController _excludeFileNamePatternController = TextEditingController();
  final TextEditingController _postSearchContentFilterController = TextEditingController();

  List<FileContent> _foundFiles = [];
  List<FileContent> _displayedFiles = [];
  bool isSearching = false;
  int totalFilesFound = 0;
  bool _isAnyFileSelected = false;

  bool _isFileNamePatternFilteringEnabled = false;
  bool _isPathPatternFilteringEnabled = false;
  bool _isPostSearchContentFilteringEnabled = false;
  bool _isPostSearchContentInclude = true;

  Map<String, List<DiffHunk>> _parsedDiffs = {};

  // Debounce for content filter
  Timer? _filterDebounce;

  // Results pane
  bool _isResultsPaneExpanded = true;

  // Go service integration
  late final JuicityService _go;
  final TextEditingController _goQueryController = TextEditingController();
  bool _useGoRipgrep = true;
  bool _goCaseSensitive = false;
  int _goTopN = 500;
  String? _currentGoSearchId;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _go = JuicityService()..initialize();
    _go.logStream.listen((msg) {
      // You can show logs in UI if needed
      // debugPrint("Go> $msg");
    });
    _go.structuredDataStream.listen((event) {
      // Optional: observe events
      // debugPrint("Go event: $event");
    });

    _postSearchContentFilterController.addListener(_onContentFilterTextChanged);
  }

  void _onContentFilterTextChanged() {
    if (_isPostSearchContentFilteringEnabled) {
      _filterDebounce?.cancel();
      _filterDebounce = Timer(const Duration(milliseconds: 400), () {
        _applyPostSearchContentFilters();
      });
    }
  }

  Future<void> _requestPermissions() async {
    // Add platform-specific permissions if needed
  }

  Future<void> _selectDirectory() async {
    try {
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        setState(() {
          selectedPath = path;
        });
      }
    } catch (e) {
      _showError('Error selecting directory: $e');
    }
  }

  Future<void> _startSearch() async {
    if (selectedPath == null) {
      _showError('Please select a directory first');
      return;
    }
    final fileTypesInput = _fileTypeController.text.trim();
    if (fileTypesInput.isEmpty) {
      _showError('Please enter file types (e.g., .dart,.json)');
      return;
    }

    setState(() {
      isSearching = true;
      _foundFiles = [];
      _displayedFiles = [];
      totalFilesFound = 0;
      _isAnyFileSelected = false;
    });

    try {
      final allowedExtensions = fileTypesInput
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      final includePathRegexes = _parsePatternsToRegex(_includePathPatternController.text);
      final excludePathRegexes = _parsePatternsToRegex(_excludePathPatternController.text);
      final includeFileNameRegexes = _parsePatternsToRegex(_includeFileNamePatternController.text);
      final excludeFileNameRegexes = _parsePatternsToRegex(_excludeFileNamePatternController.text);

      if (_useGoRipgrep) {
        await _searchWithGoRipgrep(
          allowedExtensions: allowedExtensions,
          includePathRegexes: includePathRegexes,
          excludePathRegexes: excludePathRegexes,
          includeFileNameRegexes: includeFileNameRegexes,
          excludeFileNameRegexes: excludeFileNameRegexes,
        );
      } else {
        await _searchFiles(
          selectedPath!,
          allowedExtensions,
          includePathRegexes,
          excludePathRegexes,
          includeFileNameRegexes,
          excludeFileNameRegexes,
        );
      }

      if (_isPostSearchContentFilteringEnabled &&
          _postSearchContentFilterController.text.isNotEmpty) {
        await _applyPostSearchContentFilters();
      } else {
        setState(() {
          _displayedFiles = List.from(_foundFiles);
        });
      }

      _showSuccess('Search completed! Found $totalFilesFound files');
    } catch (e) {
      _showError('Error during search: $e');
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }

  Future<void> _searchWithGoRipgrep({
    required List<String> allowedExtensions,
    required List<RegExp> includePathRegexes,
    required List<RegExp> excludePathRegexes,
    required List<RegExp> includeFileNameRegexes,
    required List<RegExp> excludeFileNameRegexes,
  }) async {
    final query = _goQueryController.text.trim();
    if (query.isEmpty) {
      _showError('Enter a query for Go ripgrep search.');
      return;
    }
    final searchId = 'search_${DateTime.now().microsecondsSinceEpoch}';
    _currentGoSearchId = searchId;

    final config = {
      'query': query,
      'caseSensitive': _goCaseSensitive,
      'topN': _goTopN,
      'findPath': selectedPath!,
      'mode': 'find',
      'searchId': searchId,
    };

    final results = await _go.searchWithConfig(config);

    // Aggregate unique files
    final uniquePaths = <String>{};
    for (final r in results) {
      uniquePaths.add(r.file);
    }

    final List<FileContent> list = [];
    for (final p in uniquePaths) {
      final norm = path_pkg.normalize(p).replaceAll(r'\', '/');

      // Path filtering
      if (_isPathPatternFilteringEnabled &&
          !_matchesPatternCriteria(norm, includePathRegexes, excludePathRegexes)) {
        continue;
      }

      final ext = path_pkg.extension(norm).toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        continue;
      }

      final name = path_pkg.basename(norm);
      if (_isFileNamePatternFilteringEnabled &&
          !_matchesPatternCriteria(name, includeFileNameRegexes, excludeFileNameRegexes)) {
        continue;
      }

      try {
        final content = await File(norm).readAsString();
        list.add(FileContent(
          fileName: name,
          filePath: norm,
          content: content,
          fileExtension: ext,
        ));
      } catch (_) {
        // ignore unreadable files
      }
    }

    setState(() {
      _foundFiles = list;
      totalFilesFound = _foundFiles.length;
    });
  }

  void _cancelSearch() {
    if (_useGoRipgrep && _currentGoSearchId != null) {
      _go.stopSearch(_currentGoSearchId!);
      _currentGoSearchId = null;
    }
    setState(() {
      isSearching = false;
    });
  }

  List<RegExp> _parsePatternsToRegex(String patternsInput) {
    if (patternsInput.trim().isEmpty) return [];
    return patternsInput
        .split(',')
        .map((pattern) {
          pattern = pattern.trim();
          if (pattern.isEmpty) return null;

          String regexString = RegExp.escape(pattern);
          if (pattern.startsWith('/')) {
            regexString = '^' + regexString;
          }
          if (pattern.endsWith('/')) {
            regexString = regexString + r'$';
          }
          regexString = regexString.replaceAll(r'\*', '.*');
          return RegExp(regexString, caseSensitive: false);
        })
        .whereType<RegExp>()
        .toList();
  }

  Future<void> _searchFiles(
    String directoryPath,
    List<String> allowedExtensions,
    List<RegExp> includePathRegexes,
    List<RegExp> excludePathRegexes,
    List<RegExp> includeFileNameRegexes,
    List<RegExp> excludeFileNameRegexes,
  ) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return;

    try {
      await for (final entity in directory.list(recursive: false)) {
        if (!isSearching) break;

        final entityPath = entity.path;
        final normPath = path_pkg.normalize(entityPath).replaceAll(r'\', '/');

        if (_isPathPatternFilteringEnabled &&
            !_matchesPatternCriteria(normPath, includePathRegexes, excludePathRegexes)) {
          if (entity is Directory) continue;
          if (entity is File) continue;
        }

        if (entity is File) {
          final fileName = path_pkg.basename(entity.path);
          final ext = path_pkg.extension(entity.path).toLowerCase();

          if (!allowedExtensions.contains(ext)) {
            continue;
          }

          if (_isFileNamePatternFilteringEnabled &&
              !_matchesPatternCriteria(fileName, includeFileNameRegexes, excludeFileNameRegexes)) {
            continue;
          }

          try {
            final content = await entity.readAsString();
            if (mounted) {
              setState(() {
                _foundFiles.add(FileContent(
                  fileName: fileName,
                  filePath: entity.path,
                  content: content,
                  fileExtension: ext,
                ));
                totalFilesFound++;
              });
            }
          } catch (_) {}
        } else if (entity is Directory) {
          await _searchFiles(
            entity.path,
            allowedExtensions,
            includePathRegexes,
            excludePathRegexes,
            includeFileNameRegexes,
            excludeFileNameRegexes,
          );
        }
      }
    } catch (e) {
      // ignore
    }
  }

  bool _matchesPatternCriteria(
    String text,
    List<RegExp> includeRegexes,
    List<RegExp> excludeRegexes,
  ) {
    bool included = true;
    if (includeRegexes.isNotEmpty) {
      included = includeRegexes.any((r) => r.hasMatch(text));
    }
    if (included && excludeRegexes.isNotEmpty) {
      included = !excludeRegexes.any((r) => r.hasMatch(text));
    }
    return included;
  }

  Future<void> _applyPostSearchContentFilters() async {
    final pattern = _postSearchContentFilterController.text.trim();

    if (!_isPostSearchContentFilteringEnabled || pattern.isEmpty) {
      setState(() {
        _displayedFiles = List.from(_foundFiles);
      });
      return;
    }

    try {
      final regex = RegExp(pattern, caseSensitive: false);
      final List<FileContent> results = [];
      for (final f in _foundFiles) {
        final matches = regex.hasMatch(f.content);
        if (_isPostSearchContentInclude ? matches : !matches) {
          results.add(f);
        }
      }
      setState(() {
        _displayedFiles = results;
        _updateSelectionState();
      });
    } catch (e) {
      _showError('Error applying content filter: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _updateSelectionState() {
    setState(() {
      _isAnyFileSelected = _displayedFiles.any((f) => f.isSelected);
    });
  }

  void _selectAllFiles() {
    setState(() {
      for (var f in _displayedFiles) {
        f.isSelected = true;
      }
      _isAnyFileSelected = true;
    });
  }

  void _deselectAllFiles() {
    setState(() {
      for (var f in _displayedFiles) {
        f.isSelected = false;
      }
      _isAnyFileSelected = false;
    });
  }

  void _deleteSelectedFiles() {
    setState(() {
      _foundFiles.removeWhere((f) => f.isSelected);
      _displayedFiles.removeWhere((f) => f.isSelected);
      _isAnyFileSelected = false;
      totalFilesFound = _foundFiles.length;
    });
    _showSuccess('Selected files deleted from list.');
  }

  String _formatContentWithLineNumbers(String content) {
    final lines = content.split('\n');
    final buf = StringBuffer();
    final pad = lines.length.toString().length;
    for (int i = 0; i < lines.length; i++) {
      buf.writeln('${(i + 1).toString().padLeft(pad)}: ${lines[i]}');
    }
    return buf.toString();
  }

  String _formatContentAsGitHubDiff(FileContent fileContent) {
    final buffer = StringBuffer();
    final lines = fileContent.content.split('\n');
    final numLines = lines.length;

    buffer.writeln('--- a/${fileContent.filePath}');
    buffer.writeln('+++ b/${fileContent.filePath}');
    buffer.writeln('@@ -1,$numLines +1,$numLines @@');
    for (int i = 0; i < numLines; i++) {
      buffer.writeln(' ${lines[i]}');
    }
    return buffer.toString();
  }

  Future<void> _showFileContent(FileContent fileContent) async {
    final controller = TextEditingController(text: fileContent.content);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileContent.fileName),
        content: SizedBox(
          width: ResponsiveValue<double>(context, defaultValue: 400, conditionalValues: [
            Condition.equals(name: MOBILE, value: MediaQuery.of(context).size.width * 0.8),
            Condition.equals(name: TABLET, value: 600),
            Condition.largerThan(name: TABLET, value: 800),
          ]).value,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Path: ${fileContent.filePath}'),
                const SizedBox(height: 8),
                Text('Extension: ${fileContent.fileExtension}'),
                const SizedBox(height: 16),
                const Text('File Content (Editable):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration.collapsed(hintText: 'No content to display'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Content with Line Numbers (Read-Only):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[800],
                  ),
                  child: SingleChildScroll...View(
                      _formatContentWithLineNumbers(fileContent.content),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _formatContentAsGitHubDiff(fileContent)),
              );
              _showSuccess('File content (GitHub diff style) copied!');
            },
            child: const Text('Copy Diff Style'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fileContent.content));
              _showSuccess('File content copied!');
            },
            child: const Text('Copy Raw Content'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final file = File(fileContent.filePath);
                await file.writeAsString(controller.text);
                setState(() {
                  fileContent.content = controller.text;
                });
                _showSuccess('File ${fileContent.fileName} saved successfully!');
                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showError('Error saving file: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<String> _generateFileTree(String directoryPath, [String prefix = '']) async {
    final buffer = StringBuffer();
    final directory = Directory(directoryPath);

    if (!await directory.exists()) return '';

    final entities = directory.listSync(recursive: false)
      ..sort((a, b) => path_pkg.basename(a.path).compareTo(path_pkg.basename(b.path)));

    for (int i = 0; i < entities.length; i++) {
      final entity = entities[i];
      final isLast = i == entities.length - 1;
      final newPrefix = isLast ? '└── ' : '├── ';
      final nextPrefix = isLast ? '    ' : '│   ';

      buffer.writeln('$prefix$newPrefix${path_pkg.basename(entity.path)}');

      if (entity is Directory) {
        buffer.write(await _generateFileTree(entity.path, prefix + nextPrefix));
      }
    }
    return buffer.toString();
  }

  Future<void> _showFileTree() async {
    if (selectedPath == null) {
      _showError('Please select a directory first to generate a file tree.');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating file tree... This might take a moment.'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final tree = await _generateFileTree(selectedPath!);
      final controller = TextEditingController(text: tree);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generated File Tree'),
          content: SizedBox(
            width: ResponsiveValue<double>(context, defaultValue: 600, conditionalValues: [
              Condition.equals(name: MOBILE, value: MediaQuery.of(context).size.width * 0.9),
              Condition.equals(name: TABLET, value: 700),
              Condition.largerThan(name: TABLET, value: 800),
            ]).value,
            child: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                  decoration: const InputDecoration.collapsed(hintText: 'No tree generated'),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: controller.text));
                _showSuccess('File tree copied to clipboard!');
              },
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () async {
                String? outputPath = await FilePicker.platform.saveFile(
                  dialogTitle: 'Save File Tree As',
                  fileName: 'file_tree.txt',
                  type: FileType.custom,
                  allowedExtensions: ['txt'],
                );
                if (outputPath != null) {
                  try {
                    final outputFile = File(outputPath);
                    await outputFile.writeAsString(controller.text);
                    _showSuccess('File tree saved to ${outputFile.path}');
                  } catch (e) {
                    _showError('Error saving file tree: $e');
                  }
                }
              },
              child: const Text('Save'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Error generating file tree: $e');
    }
  }

  Map<String, List<DiffHunk>> _parseGitHubDiff(String diffContent) {
    final Map<String, List<DiffHunk>> diffsByFile = {};
    final lines = diffContent.split('\n');

    String? currentFilePath;
    List<DiffHunk> currentFileHunks = [];
    DiffHunk? currentHunk;
    List<String> currentHunkLines = [];

    for (final line in lines) {
      if (line.startsWith('--- a/')) {
        if (currentFilePath != null && currentFileHunks.isNotEmpty) {
          diffsByFile[currentFilePath] = List.from(currentFileHunks);
        }
        currentFilePath = null;
        currentFileHunks = [];
        currentHunk = null;
        currentHunkLines = [];
      } else if (line.startsWith('+++ b/')) {
        currentFilePath = line.substring(6).trim();
      } else if (line.startsWith('@@ ')) {
        if (currentHunk != null) {
          currentFileHunks.add(currentHunk.copyWith(lines: List.from(currentHunkLines)));
        }
        currentHunkLines = [];

        final regex = RegExp(r'@@ -(\d+),?(\d*)\s+\+(\d+),?(\d*)\s@@');
        final match = regex.firstMatch(line);
        if (match != null) {
          final oldStart = int.parse(match.group(1)!);
          final oldNum = match.group(2)!.isEmpty ? 1 : int.parse(match.group(2)!);
          final newStart = int.parse(match.group(3)!);
          final newNum = match.group(4)!.isEmpty ? 1 : int.parse(match.group(4)!);

          currentHunk = DiffHunk(
            oldStartLine: oldStart,
            oldNumLines: oldNum,
            newStartLine: newStart,
            newNumLines: newNum,
            lines: [],
          );
        } else {
          throw FormatException('Invalid diff hunk header: $line');
        }
      } else if (currentFilePath != null && currentHunk != null) {
        if (line.isNotEmpty && (line.startsWith('+') || line.startsWith('-') || line.startsWith(' '))) {
          currentHunkLines.add(line);
        }
      }
    }

    if (currentHunk != null) {
      currentFileHunks.add(currentHunk.copyWith(lines: List.from(currentHunkLines)));
    }
    if (currentFilePath != null && currentFileHunks.isNotEmpty) {
      diffsByFile[currentFilePath] = List.from(currentFileHunks);
    }

    return diffsByFile;
  }

  int _findFirstMatchIndex(List<String> list, List<String> sublist, int startHint) {
    if (sublist.isEmpty) return startHint;
    if (sublist.length > list.length) return -1;

    const int searchRadius = 20;
    final int searchStart = (startHint - searchRadius).clamp(0, list.length - sublist.length);
    final int searchEnd = (startHint + searchRadius).clamp(0, list.length - sublist.length);

    for (int i = searchStart; i <= searchEnd; i++) {
      if (list[i] == sublist[0]) {
        bool isMatch = true;
        for (int j = 1; j < sublist.length; j++) {
          if (i + j >= list.length || list[i + j] != sublist[j]) {
            isMatch = false;
            break;
          }
        }
        if (isMatch) return i;
      }
    }

    for (int i = 0; i <= list.length - sublist.length; i++) {
      if (i >= searchStart && i <= searchEnd) continue;

      if (list[i] == sublist[0]) {
        bool isMatch = true;
        for (int j = 1; j < sublist.length; j++) {
          if (i + j >= list.length || list[i + j] != sublist[j]) {
            isMatch = false;
            break;
          }
        }
        if (isMatch) return i;
      }
    }
    return -1;
  }

  List<String> _applyHunksToLines(List<String> originalLines, List<DiffHunk> hunks) {
    List<String> resultLines = List.from(originalLines);
    hunks.sort((a, b) => b.oldStartLine.compareTo(a.oldStartLine));

    for (final hunk in hunks) {
      final List<String> searchPattern = hunk.lines
          .where((line) => line.startsWith(' ') || line.startsWith('-'))
          .map((line) => line.substring(1))
          .toList();

      final List<String> newContent = hunk.lines
          .where((line) => line.startsWith(' ') || line.startsWith('+'))
          .map((line) => line.substring(1))
          .toList();

      int matchIndex;
      if (searchPattern.isEmpty) {
        matchIndex = (hunk.newStartLine - 1).clamp(0, resultLines.length);
      } else {
        matchIndex = _findFirstMatchIndex(resultLines, searchPattern, hunk.oldStartLine - 1);
      }

      if (matchIndex != -1) {
        resultLines.replaceRange(matchIndex, matchIndex + searchPattern.length, newContent);
      } else {
        // Skip hunk; optionally collect errors to show
      }
    }
    return resultLines;
  }

  Future<void> _showDiffPreviewAndApply() async {
    if (_parsedDiffs.isEmpty) {
      _showError('No diffs parsed. Please load diff content first.');
      return;
    }

    final List<String> previewContent = [];
    final Map<String, List<String>> fileNewContents = {};
    bool hasErrors = false;

    for (final filePath in _parsedDiffs.keys) {
      final file = File(filePath);
      if (!await file.exists()) {
        previewContent.add('--- ERROR: File not found for diff: $filePath ---');
        hasErrors = true;
        continue;
      }

      final currentContent = await file.readAsString();
      final originalLines = currentContent.split('\n');

      final hunks = _parsedDiffs[filePath]!;
      final newLines = _applyHunksToLines(originalLines, hunks);
      fileNewContents[filePath] = newLines;

      previewContent.add('--- Diff Preview for: $filePath ---');
      previewContent.add('Original (first 10 lines):');
      previewContent.addAll(originalLines.take(10).map((l) => ' $l'));
      if (originalLines.length > 10) {
        previewContent.add('... (${originalLines.length - 10} more lines)');
      }

      previewContent.add('\nProposed Changes (Diff Hunks):');
      for (final hunk in hunks) {
        previewContent.add('@@ -${hunk.oldStartLine},${hunk.oldNumLines} +${hunk.newStartLine},${hunk.newNumLines} @@');
        previewContent.addAll(hunk.lines);
      }

      previewContent.add('\nNew Content (first 10 lines, after applying diff):');
      previewContent.addAll(newLines.take(10).map((l) => ' $l'));
      if (newLines.length > 10) {
        previewContent.add('... (${newLines.length - 10} more lines)');
      }
      previewContent.add('\n');
    }

    if (previewContent.isEmpty) {
      _showError('No files processed for diff preview.');
      return;
    }

    final previewController = TextEditingController(text: previewContent.join('\n'));
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diff Preview'),
        content: SizedBox(
          width: ResponsiveValue<double>(context, defaultValue: 800, conditionalValues: [
            Condition.equals(name: MOBILE, value: MediaQuery.of(context).size.width * 0.9),
            Condition.equals(name: TABLET, value: 700),
            Condition.largerThan(name: TABLET, value: 900),
          ]).value,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasErrors)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Some files could not be found or processed. Review the preview carefully!',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[800],
                  ),
                  child: TextField(
                    controller: previewController,
                    readOnly: true,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white70),
                    decoration: const InputDecoration.collapsed(hintText: 'No diff preview'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              bool allApplied = true;
              for (final filePath in fileNewContents.keys) {
                try {
                  final file = File(filePath);
                  await file.writeAsString(fileNewContents[filePath]!.join('\n'));
                  final idx = _foundFiles.indexWhere((f) => f.filePath == filePath);
                  if (idx != -1) {
                    setState(() {
                      _foundFiles[idx].content = fileNewContents[filePath]!.join('\n');
                    });
                  }
                } catch (e) {
                  allApplied = false;
                  _showError('Failed to apply diff to $filePath: $e');
                }
              }
              if (allApplied) {
                _showSuccess('All selected diffs applied successfully!');
              }
              _parsedDiffs = {};
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Apply Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Search & Diff App'),
        actions: isMobile
            ? [
                IconButton(
                  icon: Icon(_isResultsPaneExpanded ? Icons.chevron_right : Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _isResultsPaneExpanded = !_isResultsPaneExpanded;
                    });
                  },
                  tooltip: _isResultsPaneExpanded ? 'Collapse results' : 'Expand results',
                ),
              ]
            : null,
      ),
      body: ResponsiveRowColumn(
        layout: ResponsiveBreakpoints.of(context).largerThan(MOBILE)
            ? ResponsiveRowColumnType.ROW
            : ResponsiveRowColumnType.COLUMN,
        rowSpacing: 16,
        columnSpacing: 16,
        rowMainAxisAlignment: MainAxisAlignment.start,
        columnCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveRowColumnItem(
            rowFlex: 2,
            columnFlex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildControlsSection(),
            ),
          ),
          ResponsiveRowColumnItem(
            rowFlex: 3,
            columnFlex: 1,
            child: isMobile
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _isResultsPaneExpanded ? MediaQuery.of(context).size.height * 0.5 : 50,
                    child: _isResultsPaneExpanded ? _buildResultList() : _buildCollapsedResultHeader(),
                  )
                : _buildResultList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedResultHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _isResultsPaneExpanded = true;
        });
      },
      child: Card(
        margin: const EdgeInsets.all(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found Files: ${_displayedFiles.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.expand_less),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(onPressed: _selectDirectory, child: const Text('Select Directory')),
        const SizedBox(height: 8),
        Text(
          selectedPath != null ? 'Selected: ${selectedPath!}' : 'No directory selected',
          style: TextStyle(
            color: selectedPath != null ? Colors.greenAccent : Colors.grey,
            fontStyle: selectedPath != null ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),
        _buildSearchFilters(),
        const SizedBox(height: 12),
        _buildGoSearchControls(),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isSearching ? _cancelSearch : _startSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: isSearching ? Colors.orange : Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: isSearching
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    SizedBox(width: 8),
                    Text('Searching... Tap to Cancel'),
                  ],
                )
              : const Text('Start Search'),
        ),
        const SizedBox(height: 10),
        const Divider(),
        _buildPostSearchContentFilter(),
        const Divider(),
        _buildDiffSection(),
        const Divider(),
        const SizedBox(height: 20),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildGoSearchControls() {
    return ExpansionTile(
      title: const Text('Go ripgrep Search'),
      initiallyExpanded: false,
      leading: const Icon(Icons.search),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        SwitchListTile(
          title: const Text('Use Go ripgrep for content search'),
          value: _useGoRipgrep,
          onChanged: (v) => setState(() => _useGoRipgrep = v),
          contentPadding: EdgeInsets.zero,
        ),
        if (_useGoRipgrep) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _goQueryController,
            decoration: const InputDecoration(
              labelText: 'Query (required for Go search)',
              hintText: 'e.g., class MyWidget',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Top N results'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v.trim());
                    if (n != null && n > 0) {
                      _goTopN = n;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  title: const Text('Case sensitive'),
                  value: _goCaseSensitive,
                  onChanged: (v) => setState(() => _goCaseSensitive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: Go ripgrep search reads the files on disk and returns matching lines, '
            'this UI will then load the entire file content for preview.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchFilters() {
    return ExpansionTile(
      title: const Text('File & Path Search Filters'),
      initiallyExpanded: false,
      leading: const Icon(Icons.filter_alt),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        TextField(
          controller: _fileTypeController,
          decoration: const InputDecoration(
            labelText: 'File Extensions (e.g., .dart,.json)',
            hintText: '.dart,.java,.xml',
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Filter by Directory/Path'),
          value: _isPathPatternFilteringEnabled,
          onChanged: (value) => setState(() => _isPathPatternFilteringEnabled = value),
          contentPadding: EdgeInsets.zero,
        ),
        if (_isPathPatternFilteringEnabled) ...[
          TextField(
            controller: _includePathPatternController,
            decoration: const InputDecoration(
              labelText: 'Include Paths (e.g., /src/*, *controller/)',
              hintText: '/lib/src/*, *data/, /bin/',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _excludePathPatternController,
            decoration: const InputDecoration(
              labelText: 'Exclude Paths (e.g., /build/*, *node_modules/)',
              hintText: '/build/*, *node_modules/, *.git',
            ),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text('Filter by File Name Pattern'),
          value: _isFileNamePatternFilteringEnabled,
          onChanged: (value) => setState(() => _isFileNamePatternFilteringEnabled = value),
          contentPadding: EdgeInsets.zero,
        ),
        if (_isFileNamePatternFilteringEnabled) ...[
          TextField(
            controller: _includeFileNamePatternController,
            decoration: const InputDecoration(
              labelText: 'Include File Names (e.g., *-provider.go, *model*)',
              hintText: '*-repository.dart, *settings.json',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _excludeFileNamePatternController,
            decoration: const InputDecoration(
              labelText: 'Exclude File Names (e.g., *test.dart, *.tmp)',
              hintText: '*_test.dart, *.log, temporary*',
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildPostSearchContentFilter() {
    return ExpansionTile(
      title: const Text('Post-Search Content Filter'),
      initiallyExpanded: false,
      leading: const Icon(Icons.search),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        SwitchListTile(
          title: const Text('Enable Content Filtering'),
          value: _isPostSearchContentFilteringEnabled,
          onChanged: (value) {
            setState(() {
              _isPostSearchContentFilteringEnabled = value;
              if (!value) {
                _displayedFiles = List.from(_foundFiles);
              } else {
                _filterDebounce?.cancel();
                _filterDebounce = Timer(const Duration(milliseconds: 300), () {
                  _applyPostSearchContentFilters();
                });
              }
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_isPostSearchContentFilteringEnabled) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _postSearchContentFilterController,
            decoration: const InputDecoration(
              labelText: 'Search content (regex)',
              hintText: 'e.g., class MyWidget, (await|Future)<String>',
            ),
            maxLines: null,
            minLines: 1,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Include'),
                selected: _isPostSearchContentInclude,
                onSelected: (selected) {
                  setState(() {
                    _isPostSearchContentInclude = true;
                    _applyPostSearchContentFilters();
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Exclude'),
                selected: !_isPostSearchContentInclude,
                onSelected: (selected) {
                  setState(() {
                    _isPostSearchContentInclude = false;
                    _applyPostSearchContentFilters();
                  });
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDiffSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Apply GitHub-style Diff:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _diffInputController,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Paste Diff Content Here',
            hintText: '--- a/file.txt\n+++ b/file.txt\n@@ -1,3 +1,4 @@\n-old\n+new\n context',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton(onPressed: _loadDiffFromFile, child: const Text('Load Diff from File')),
            ElevatedButton(
              onPressed: () {
                final diffContent = _diffInputController.text.trim();
                if (diffContent.isEmpty) {
                  _showError('Please paste diff content into the text field.');
                  return;
                }
                _parseAndPrepareDiff(diffContent);
              },
              child: const Text('Parse Diff from Input'),
            ),
            ElevatedButton(
              onPressed: _parsedDiffs.isNotEmpty ? _showDiffPreviewAndApply : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text('Preview & Apply Diff'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadDiffFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['diff', 'patch', 'txt']);
      if (result != null && result.files.single.path != null) {
        final diffFile = File(result.files.single.path!);
        final diffContent = await diffFile.readAsString();
        _diffInputController.text = diffContent;
        _parseAndPrepareDiff(diffContent);
      }
    } catch (e) {
      _showError('Error loading diff from file: $e');
    }
  }

  void _parseAndPrepareDiff(String diffContent) {
    try {
      _parsedDiffs = _parseGitHubDiff(diffContent);
      if (_parsedDiffs.isEmpty) {
        _showError('No valid diff entries found in the provided content.');
      } else {
        _showSuccess('Diff content parsed successfully! Ready for preview and application.');
      }
    } catch (e) {
      _showError('Error parsing diff content: $e');
      _parsedDiffs = {};
    }
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('File Actions:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _displayedFiles.isNotEmpty ? _selectAllFiles : null,
              child: const Text('Select All'),
            ),
            ElevatedButton(
              onPressed: _isAnyFileSelected ? _deselectAllFiles : null,
              child: const Text('Deselect All'),
            ),
            ElevatedButton(
              onPressed: _isAnyFileSelected ? _deleteSelectedFiles : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete Selected'),
            ),
            ElevatedButton(
              onPressed: _isAnyFileSelected ? () => _exportSelectedFiles(includeDiffHeader: true) : null,
              child: const Text('Export Selected (Diff Style)'),
            ),
            ElevatedButton(
              onPressed: _isAnyFileSelected ? () => _exportSelectedFiles(includeDiffHeader: false) : null,
              child: const Text('Export Selected (Raw)'),
            ),
            ElevatedButton(onPressed: selectedPath != null ? _showFileTree : null, child: const Text('Generate File Tree')),
          ],
        ),
      ],
    );
  }

  Future<void> _exportSelectedFiles({required bool includeDiffHeader}) async {
    final selectedFiles = _displayedFiles.where((f) => f.isSelected).toList();
    if (selectedFiles.isEmpty) {
      _showError('No files selected for export');
      return;
    }

    try {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Exported Files As',
        fileName: includeDiffHeader ? 'selected_files_diff_export.txt' : 'selected_files_export.txt',
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
      );
      if (outputPath == null) return;

      final outputFile = File(outputPath);
      final buffer = StringBuffer();

      buffer.writeln('--- Selected Files Export ---');
      buffer.writeln('Export Date: ${DateTime.now().toIso8601String()}\n');

      for (final fileContent in selectedFiles) {
        if (includeDiffHeader) {
          buffer.writeln(_formatContentAsGitHubDiff(fileContent));
        } else {
          buffer.writeln('### File: ${fileContent.fileName} (${fileContent.filePath})');
          buffer.writeln('```${fileContent.fileExtension.replaceFirst('.', '')}');
          buffer.writeln(fileContent.content);
          buffer.writeln('```');
        }
        buffer.writeln('\n--- End File: ${fileContent.fileName} ---\n');
      }

      await outputFile.writeAsString(buffer.toString());
      _showSuccess('Selected files exported to ${outputFile.path}');
    } catch (e) {
      _showError('Error exporting selected results: $e');
    }
  }

  Widget _buildResultList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Displayed Files: ${_displayedFiles.length} (Total Found: $totalFilesFound)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _displayedFiles.isEmpty
              ? Center(
                  child: Text(
                    isSearching
                        ? 'Searching...'
                        : 'No files found yet or no files match current content filters.\nSelect a directory and start search.',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _displayedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _displayedFiles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Checkbox(
                          value: file.isSelected,
                          onChanged: (v) {
                            setState(() {
                              file.isSelected = v ?? false;
                              _updateSelectionState();
                            });
                          },
                        ),
                        title: Text(file.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(file.filePath, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        trailing: Text('${file.content.length} chars', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        onTap: () => _showFileContent(file),
                        tileColor: file.isSelected ? Colors.blue.withOpacity(0.2) : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fileTypeController.dispose();
    _excludePatternController.dispose();
    _diffInputController.dispose();
    _includePathPatternController.dispose();
    _excludePathPatternController.dispose();
    _includeFileNamePatternController.dispose();
    _excludeFileNamePatternController.dispose();
    _postSearchContentFilterController.removeListener(_onContentFilterTextChanged);
    _postSearchContentFilterController.dispose();
    _filterDebounce?.cancel();
    _goQueryController.dispose();
    super.dispose();
  }
}