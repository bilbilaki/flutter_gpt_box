import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert'; // For JSON parsing
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

// Import the generated bindings
import 'generated_bindings.dart';

// Response types that Go might send back
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
          .map((e) => PartialDiff.fromJson(e))
          .toList(),
      explanations: List<String>.from(json['explanations'] ?? []),
      confidenceScore: (json['confidenceScore'] ?? 0.0).toDouble(),
      warnings: List<String>.from(json['warnings'] ?? []),
      suggestedFiles: List<String>.from(json['suggestedFiles'] ?? []),
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

// Event types for the structured data stream
enum GoResponseType {
  searchResults,
  aiContextGenerated,
  patchApplied,
  patchStoreStatus,
  error,
  logMessage
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

class GofalowService {
  late final libgofalow _bindings;
  late final DynamicLibrary _dylib;

  // Stream controllers for different types of responses
  final _logStreamController = StreamController<String>.broadcast();
  final _structuredDataStreamController = StreamController<GoResponseEvent>.broadcast();
  
  Stream<String> get logStream => _logStreamController.stream;
  Stream<GoResponseEvent> get structuredDataStream => _structuredDataStreamController.stream;

  late final ReceivePort _port;
  int get nativePort => _port.sendPort.nativePort;

  GofalowService() {
    _dylib = _loadLibrary();
    _bindings = libgofalow(_dylib);
    _port = ReceivePort();
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) {
      final libPath = p.join(
        Directory.current.path,
        'native',
        'linux',
        'libgofalow.so',
      );
      print('Loading Go library from: $libPath');
      return DynamicLibrary.open(libPath);
    } else if (Platform.isWindows) {
      final libPath = p.join(
        Directory.current.path,
        'native',
        'windows',
        'libgofalow.dll',
      );
      print('Loading Go library from: $libPath');
      return DynamicLibrary.open(libPath);
    } else if (Platform.isMacOS) {
      final libPath = p.join(
        Directory.current.path,
        'native',
        'macos',
        'libgofalow.dylib',
      );
      print('Loading Go library from: $libPath');
      return DynamicLibrary.open(libPath);
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  void initialize() {
    _bindings.InitDartApi(NativeApi.initializeApiDLData);
    _logStreamController.add("Dart API initialized for Go bridge.");

    // Enhanced port listener with structured data parsing
    _port.listen((message) {
      _handleGoMessage(message);
    });

    _logStreamController.add("GofalowService initialized with structured data support.");
  }

  void _handleGoMessage(dynamic message) {
    if (message is String) {
      try {
        // Try to parse as JSON first
        final jsonData = jsonDecode(message);
        _handleStructuredData(jsonData, message);
      } catch (e) {
        // If not JSON, treat as plain log message
        _logStreamController.add(message);
        _structuredDataStreamController.add(GoResponseEvent(
          type: GoResponseType.logMessage,
          rawMessage: message,
        ));
      }
    } else {
      // Handle other types of messages if needed
      _logStreamController.add('Unknown message type: ${message.runtimeType}');
    }
  }

  void _handleStructuredData(dynamic jsonData, String rawMessage) {
    try {
      if (jsonData is Map<String, dynamic>) {
        // Check if it's a bridge.DartResponse structure from Go
        if (jsonData.containsKey('success') && jsonData.containsKey('data')) {
          _handleDartResponse(jsonData);
        } 
        // Check if it's patch store status
        else if (jsonData.containsKey('exists')) {
          final status = PatchStoreStatus.fromJson(jsonData);
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.patchStoreStatus,
            data: status,
            rawMessage: rawMessage,
          ));
        }
        // Check if it's search results
        else if (jsonData is List || (jsonData.containsKey('file') && jsonData.containsKey('lineNumber'))) {
          _handleSearchResults(jsonData, rawMessage);
        }
        // Check if it's AI response
        else if (jsonData.containsKey('generatedDiffs')) {
          final aiResponse = AIResponse.fromJson(jsonData);
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.aiContextGenerated,
            data: aiResponse,
            rawMessage: rawMessage,
          ));
        }
        // Check if it's applied patch
        else if (jsonData.containsKey('id') && jsonData.containsKey('targetFile')) {
          final appliedPatch = AppliedPatch.fromJson(jsonData);
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.patchApplied,
            data: appliedPatch,
            rawMessage: rawMessage,
          ));
        }
        // Generic error handling
        else if (jsonData.containsKey('error') || jsonData.containsKey('Error')) {
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.error,
            data: jsonData,
            rawMessage: rawMessage,
          ));
          _logStreamController.add('Error from Go: $jsonData');
        }
        // Unknown structured data
        else {
          _structuredDataStreamController.add(GoResponseEvent(
            type: GoResponseType.logMessage,
            data: jsonData,
            rawMessage: rawMessage,
          ));
        }
      } else if (jsonData is List) {
        // Handle array responses (like search results list)
        _handleSearchResults(jsonData, rawMessage);
      }
    } catch (e) {
      _logStreamController.add('Error parsing structured data: $e\nRaw: $rawMessage');
      _structuredDataStreamController.add(GoResponseEvent(
        type: GoResponseType.error,
        rawMessage: 'Parse error: $e\nData: $rawMessage',
      ));
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
      } catch (e) {
        // Data might not be JSON, treat as plain text
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
        final searchResults = resultsData.map((item) {
          if (item is Map<String, dynamic>) {
            return SearchResultResponse.fromJson(item);
          }
          return SearchResultResponse(
            file: '',
            lineNumber: 0,
            lineText: item.toString(),
            matchPos: 0,
            type: ' ',
            score: 0,
            searchId: '',
          );
        }).toList();

        _structuredDataStreamController.add(GoResponseEvent(
          type: GoResponseType.searchResults,
          data: searchResults,
          rawMessage: rawMessage,
        ));
      } else if (resultsData is Map<String, dynamic>) {
        // Single result
        final searchResult = SearchResultResponse.fromJson(resultsData);
        _structuredDataStreamController.add(GoResponseEvent(
          type: GoResponseType.searchResults,
          data: [searchResult],
          rawMessage: rawMessage,
        ));
      }
    } catch (e) {
      _logStreamController.add('Error parsing search results: $e');
      _structuredDataStreamController.add(GoResponseEvent(
        type: GoResponseType.error,
        rawMessage: 'Search results parse error: $e',
      ));
    }
  }

  // Convenience methods for common operations with structured responses
  Future<List<SearchResultResponse>> searchWithConfig(Map<String, dynamic> config) async {
    final completer = Completer<List<SearchResultResponse>>();
    late final StreamSubscription<GoResponseEvent> subscription;
     subscription = structuredDataStream.listen((event) {
      if (event.type == GoResponseType.searchResults) {
        completer.complete(event.data);
        subscription.cancel();
      } else if (event.type == GoResponseType.error) {
        completer.completeError(event.rawMessage ?? 'Search failed');
        subscription.cancel();
      }
    });

    startSearch(jsonEncode(config));
    
    // Timeout after 30 seconds
    return completer.future.timeout(
      Duration(seconds: 30),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('Search operation timed out');
      },
    );
  }

  Future<AIResponse> generateAIContextWithRequest(Map<String, dynamic> request) async {
    final completer = Completer<AIResponse>();
    late final StreamSubscription<GoResponseEvent> subscription;
     subscription = structuredDataStream.listen((GoResponseEvent event) {
      if (event.type == GoResponseType.aiContextGenerated) {
        completer.complete(event.data);
        subscription.cancel();
      } else if (event.type == GoResponseType.error) {
        completer.completeError(event.rawMessage ?? 'AI context generation failed');
        subscription.cancel();
      }
    });

    generateAIContext(jsonEncode(request));
    
    return completer.future.timeout(
      Duration(seconds: 60),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('AI context generation timed out');
      },
    );
  }

  // Existing wrapper methods (unchanged but now they'll benefit from structured responses)
  void getPatchStoreStatus(String searchID) {
    _logStreamController.add("Requesting patch store status for ID: $searchID");
    final searchIDPtr = searchID.toNativeUtf8();
    try {
      _bindings.GetPatchStoreStatus(nativePort, searchIDPtr.cast());
    } finally {
      malloc.free(searchIDPtr);
    }
  }

  void cleanupPatchStore(String searchID) {
    _logStreamController.add("Cleaning up patch store for ID: $searchID");
    final searchIDPtr = searchID.toNativeUtf8();
    try {
      _bindings.CleanupPatchStore(searchIDPtr.cast());
    } finally {
      malloc.free(searchIDPtr);
    }
  }

  void startSearch(String configJson) {
    _logStreamController.add("Starting search with config: $configJson");
    final configJsonPtr = configJson.toNativeUtf8();
    try {
      _bindings.StartSearch(nativePort, configJsonPtr.cast());
    } finally {
      malloc.free(configJsonPtr);
    }
  }

  void stopSearch(String searchID) {
    _logStreamController.add("Stopping search with ID: $searchID");
    final searchIDPtr = searchID.toNativeUtf8();
    try {
      _bindings.StopSearch(searchIDPtr.cast());
    } finally {
      malloc.free(searchIDPtr);
    }
  }

  void generateAIContext(String requestJson) {
    _logStreamController.add("Generating AI context with request: $requestJson");
    final requestJsonPtr = requestJson.toNativeUtf8();
    try {
      _bindings.GenerateAIContext(nativePort, requestJsonPtr.cast());
    } finally {
      malloc.free(requestJsonPtr);
    }
  }

  void applyAIPatch(String patchID, String searchID, String matchResultJson) {
    _logStreamController.add("Applying AI patch '$patchID' for search '$searchID'");
    final patchIDPtr = patchID.toNativeUtf8();
    final searchIDPtr = searchID.toNativeUtf8();
    final matchResultJsonPtr = matchResultJson.toNativeUtf8();
    try {
      _bindings.ApplyAIPatch(
        nativePort,
        patchIDPtr.cast(),
        searchIDPtr.cast(),
        matchResultJsonPtr.cast(),
      );
    } finally {
      malloc.free(patchIDPtr);
      malloc.free(searchIDPtr);
      malloc.free(matchResultJsonPtr);
    }
  }

  void searchAIChanges(String configJson) {
    _logStreamController.add("Searching AI changes with config: $configJson");
    final configJsonPtr = configJson.toNativeUtf8();
    try {
      _bindings.SearchAIChanges(nativePort, configJsonPtr.cast());
    } finally {
      malloc.free(configJsonPtr);
    }
  }

  void dispose() {
    _logStreamController.close();
    _structuredDataStreamController.close();
    _port.close();
    _logStreamController.add("GofalowService disposed.");
  }
}