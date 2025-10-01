import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:gpt_box/bridges/generated_bindings_golib.dart';
import 'package:path/path.dart' as p;

// --- Generated Binding Imports ---
// Assuming your generated file is named 'mylib_bindings.dart'
// and contains the class 'Libgoolib'.
// --- 1. Platform-Agnostic Dynamic Library Loader ---

const String _libName = 'libgolib';

class _GolibLoader {
  static final Libgoolib _bindings = _load();
  static Libgoolib get bindings => _bindings;

  static ffi.DynamicLibrary _getDynamicLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      return ffi.DynamicLibrary.open('$_libName.dylib');
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('$_libName.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('$_libName.dll');
    }
    // Fallback/Web/Fuchsia not supported by standard FFI
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  static Libgoolib _load() {
    final lib = _getDynamicLibrary();
    return Libgoolib(lib);
  }
}


// --- 2. Static Utilities and Memory Management (CRITICAL FIX) ---

/// Utility class to handle memory management for C strings.
class _GolibUtilities {
  static String getStringAndFree(ffi.Pointer<ffi.Char> ptr) {
    if (ptr == ffi.nullptr) {
      return '';
    }
    try {
      return ptr.toString();
    } finally {
      // Use the 'free' function exposed by ffigen from stdlib.h
      _GolibLoader.bindings.free(ptr.cast()); 
    }
  }

  /// Allocates a Dart string into C memory (must be manually freed by the caller using calloc.free).
  static ffi.Pointer<ffi.Char> toNativeString(String? dartString) {
    if (dartString == null || dartString.isEmpty) {
      return ''.toNativeUtf8().cast();
    }
    // Use package:ffi's malloc utility
    return dartString.toNativeUtf8().cast();
  }
  
  /// Helper to free pointers allocated by the Dart side (usually via toNativeString)
  static void freeNativePointer(ffi.Pointer<ffi.Void> ptr) {
    calloc.free(ptr);
  }
}


// --- 3. Data Models (Unchanged) ---

class HttpResponse {
  final int status;
  final String body;
  final Map<String, dynamic> headers;
  final String? error;

  HttpResponse.fromJson(Map<String, dynamic> json)
      : status = json['Status'] as int? ?? 0,
        body = json['Body'] as String? ?? '',
        headers = (json['Headers'] as Map?)?.cast<String, dynamic>() ?? {},
        error = json['Error'] as String?;

  @override
  String toString() => 'Status: $status, Error: $error, Body length: ${body.length}';
}

class GitRemote {
  final String name;
  final List<String> urls;

  GitRemote.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        urls = (json['urls'] as List).cast<String>();

  @override
  String toString() => '$name: ${urls.join(", ")}';
}

// --- 4. Core Service Manager and Utilities ---

class Golib {
  final Libgoolib _bindings = _GolibLoader.bindings;

  // Static utilities are accessed directly via class name.

  Golib() {
    // Initialization code here if needed
  }

  // --- GENERAL UTILITIES ---

  /// Calculates the difference between two strings.
  Future<String> textDiff(String text1, String text2) async {
    final ptr1 = _GolibUtilities.toNativeString(text1);
    final ptr2 = _GolibUtilities.toNativeString(text2);
    
    try {
      final resultPtr = await Future.microtask(() => _bindings.TextDiff(ptr1, ptr2));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(ptr1.cast());
      _GolibUtilities.freeNativePointer(ptr2.cast());
    }
  }

  // --- TERMINAL/SHELL SERVICE ---

  /// Starts a new shell session (returns session ID, or 0 on error).
  Future<int> startShell() async {
    return await Future.microtask(() => _bindings.StartShell());
  }

  /// Reads output from a shell session (blocking call).
  /// Returns null if the session ID is invalid.
  Future<String?> readOutput(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.ReadOutput(sessionId));
    if (resultPtr == ffi.nullptr) {
      return null;
    }
    // Go allocated memory, so use getStringAndFree
    return _GolibUtilities.getStringAndFree(resultPtr);
  }

  /// Writes input to a shell session.
  Future<void> writeInput(int sessionId, String input) async {
    final ptr = _GolibUtilities.toNativeString(input);
    try {
      await Future.microtask(() => _bindings.WriteInput(sessionId, ptr));
    } finally {
      _GolibUtilities.freeNativePointer(ptr.cast());
    }
  }

  /// Closes and cleans up a shell session.
  Future<void> closeShell(int sessionId) async {
    await Future.microtask(() => _bindings.CloseShell(sessionId));
  }

  // --- PDF SERVICE ---

  /// Generates a simple PDF immediately. Returns success message or detailed error.
  Future<String> generateSimplePdf({
    required String outputPath,
    required String fontPath,
    required String text,
  }) async {
    final outPtr = _GolibUtilities.toNativeString(outputPath);
    final fontPtr = _GolibUtilities.toNativeString(fontPath);
    final textPtr = _GolibUtilities.toNativeString(text);

    try {
      final resultPtr = await Future.microtask(() => _bindings.GenerateSimplePdf(outPtr, fontPtr, textPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(outPtr.cast());
      _GolibUtilities.freeNativePointer(fontPtr.cast());
      _GolibUtilities.freeNativePointer(textPtr.cast());
    }
  }

  /// Starts a new PDF session for multi-step document creation. Returns session ID.
  Future<int> startPdfSession() async {
    return await Future.microtask(() => _bindings.StartPdfSession());
  }

  /// Closes and cleans up a PDF session. Must be called after `writePdf`.
  Future<void> closePdfSession(int sessionId) async {
    await Future.microtask(() => _bindings.ClosePdfSession(sessionId));
  }

  Future<String?> pdfAddPage(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfAddPage(sessionId));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }

  Future<String?> pdfAddFont({
    required int sessionId,
    required String key,
    required String path,
  }) async {
    final keyPtr = _GolibUtilities.toNativeString(key);
    final pathPtr = _GolibUtilities.toNativeString(path);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfAddFont(sessionId, keyPtr, pathPtr));
      return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
    } finally {
      _GolibUtilities.freeNativePointer(keyPtr.cast());
      _GolibUtilities.freeNativePointer(pathPtr.cast());
    }
  }
  
  Future<String?> pdfSetFont({
    required int sessionId,
    required String family,
    required String style,
    required int size, 
  }) async {
    final familyPtr = _GolibUtilities.toNativeString(family);
    final stylePtr = _GolibUtilities.toNativeString(style);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfSetFont(sessionId, familyPtr, stylePtr, size));
      return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
    } finally {
      _GolibUtilities.freeNativePointer(familyPtr.cast());
      _GolibUtilities.freeNativePointer(stylePtr.cast());
    }
  }

  Future<String?> pdfSetTextColorRGB(int sessionId, int r, int g, int b) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfSetTextColorRGB(sessionId, r, g, b));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }

  Future<String?> pdfText(int sessionId, String content) async {
    final contentPtr = _GolibUtilities.toNativeString(content);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfText(sessionId, contentPtr));
      return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
    } finally {
      _GolibUtilities.freeNativePointer(contentPtr.cast());
    }
  }
  
  Future<String?> pdfSetXY(int sessionId, double x, double y) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfSetXY(sessionId, x, y));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }

  Future<String?> pdfAddImage({
    required int sessionId, 
    required String path, 
    required double x, 
    required double y,
  }) async {
    final pathPtr = _GolibUtilities.toNativeString(path);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfAddImage(sessionId, pathPtr, x, y));
      return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
    } finally {
      _GolibUtilities.freeNativePointer(pathPtr.cast());
    }
  }

  Future<String?> pdfRotate(int sessionId, double angle, double x, double y) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfRotate(sessionId, angle, x, y));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }
  
  Future<String?> pdfRotateReset(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfRotateReset(sessionId));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }
  
  Future<String?> pdfAddExternalLink({
    required int sessionId, 
    required String url, 
    required double x, 
    required double y, 
    required double w, 
    required double h,
  }) async {
    final urlPtr = _GolibUtilities.toNativeString(url);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfAddExternalLink(sessionId, urlPtr, x, y, w, h));
      return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
    } finally {
      _GolibUtilities.freeNativePointer(urlPtr.cast());
    }
  }

  Future<String?> pdfSetLineWidth(int sessionId, double width) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfSetLineWidth(sessionId, width));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }

  Future<String?> pdfLine(int sessionId, double x1, double y1, double x2, double y2) async {
    final resultPtr = await Future.microtask(() => _bindings.PdfLine(sessionId, x1, y1, x2, y2));
    return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
  }

  Future<String?> pdfRectangle({
    required int sessionId, 
    required double x, 
    required double y, 
    required double w, 
    required double h, 
    required String style, 
    required double r, 
    required int dot,
  }) async {
    final stylePtr = _GolibUtilities.toNativeString(style);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfRectangle(sessionId, x, y, w, h, stylePtr, r, dot));
      return _GolibUtilities.getStringAndFree(resultPtr).nullIfEmptyOrSuccess();
    } finally {
      _GolibUtilities.freeNativePointer(stylePtr.cast());
    }
  }

  /// Saves the PDF document to the specified path.
  Future<String> pdfWritePdf({required int sessionId, required String path}) async {
    final pathPtr = _GolibUtilities.toNativeString(path);
    try {
      final resultPtr = await Future.microtask(() => _bindings.PdfWritePdf(sessionId, pathPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(pathPtr.cast());
    }
  }

  // --- HTTP CLIENT SERVICE ---

  /// Creates a new persistent HTTP client session. Returns session ID.
  Future<int> newHttpClient() async {
    return await Future.microtask(() => _bindings.NewHttpClient());
  }

  /// Closes all idle connections associated with the client.
  Future<void> httpClientCloseIdleConnections(int sessionId) async {
    await Future.microtask(() => _bindings.HttpClientCloseIdleConnections(sessionId));
  }
  
  /// Closes and cleans up the HTTP client session.
  Future<void> closeHttpClient(int sessionId) async {
    await Future.microtask(() => _bindings.CloseHttpClient(sessionId));
  }

  /// Executes an HTTP GET request.
  Future<HttpResponse> httpGet(int sessionId, String url) async {
    final urlPtr = _GolibUtilities.toNativeString(url);
    try {
      final resultPtr = await Future.microtask(() => _bindings.HttpGet(sessionId, urlPtr));
      final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
      return HttpResponse.fromJson(jsonDecode(jsonString));
    } finally {
      _GolibUtilities.freeNativePointer(urlPtr.cast());
    }
  }
  
  /// Executes an HTTP POST request with form data.
  Future<HttpResponse> httpPostForm(int sessionId, String url, Map<String, String> formData) async {
    final urlPtr = _GolibUtilities.toNativeString(url);
    final formJson = jsonEncode(formData);
    final formPtr = _GolibUtilities.toNativeString(formJson);

    try {
      final resultPtr = await Future.microtask(() => _bindings.HttpPostForm(sessionId, urlPtr, formPtr));
      final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
      return HttpResponse.fromJson(jsonDecode(jsonString));
    } finally {
      _GolibUtilities.freeNativePointer(urlPtr.cast());
      _GolibUtilities.freeNativePointer(formPtr.cast());
    }
  }

  // --- HTTP SERVER SERVICE ---

  /// Starts a static file server. Returns server ID (or 0 on error).
  Future<int> startStaticFileServer({required String port, required String baseDir}) async {
    final portPtr = _GolibUtilities.toNativeString(port);
    final dirPtr = _GolibUtilities.toNativeString(baseDir);
    try {
      return await Future.microtask(() => _bindings.StartStaticFileServer(portPtr, dirPtr));
    } finally {
      _GolibUtilities.freeNativePointer(portPtr.cast());
      _GolibUtilities.freeNativePointer(dirPtr.cast());
    }
  }

  /// Stops a running static file server.
  Future<String> stopStaticFileServer(int serverId) async {
    final resultPtr = await Future.microtask(() => _bindings.StopStaticFileServer(serverId));
    return _GolibUtilities.getStringAndFree(resultPtr);
  }

  // --- SSH CLIENT SERVICE ---

  /// Starts an SSH session. Returns session ID (or 0 on error).
  Future<int> startSsh({
    required String user,
    required String host,
    String password = '',
    String keyPath = '',
    String passphrase = '',
    bool useAgent = false,
  }) async {
    final userPtr = _GolibUtilities.toNativeString(user);
    final hostPtr = _GolibUtilities.toNativeString(host);
    final passPtr = _GolibUtilities.toNativeString(password);
    final keyPtr = _GolibUtilities.toNativeString(keyPath);
    final ppPtr = _GolibUtilities.toNativeString(passphrase);

    try {
      return await Future.microtask(() => _bindings.StartSSH(
            userPtr,
            hostPtr,
            passPtr,
            keyPtr,
            ppPtr,
            useAgent ? 1 : 0,
          ));
    } finally {
      _GolibUtilities.freeNativePointer(userPtr.cast());
      _GolibUtilities.freeNativePointer(hostPtr.cast());
      _GolibUtilities.freeNativePointer(passPtr.cast());
      _GolibUtilities.freeNativePointer(keyPtr.cast());
      _GolibUtilities.freeNativePointer(ppPtr.cast());
    }
  }

  /// Runs a command on the remote host.
  Future<String> runRemoteCommand({
    required int sessionId,
    required String command,
    int timeoutSeconds = 60,
  }) async {
    final cmdPtr = _GolibUtilities.toNativeString(command);
    try {
      final resultPtr = await Future.microtask(() => _bindings.RunRemoteCommand(sessionId, cmdPtr, timeoutSeconds));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(cmdPtr.cast());
    }
  }

  /// Transfers a file. 0 = Upload, 1 = Download. Returns 0 on success, 1 on failure.
  Future<bool> remoteFileTransfer({
    required int sessionId,
    required bool isDownload,
    required String localPath,
    required String remotePath,
  }) async {
    final localPtr = _GolibUtilities.toNativeString(localPath);
    final remotePtr = _GolibUtilities.toNativeString(remotePath);
    final transferType = isDownload ? 1 : 0;
    
    try {
      final result = await Future.microtask(() => _bindings.RemoteFileTransfer(sessionId, transferType, localPtr, remotePtr));
      return result == 0;
    } finally {
      _GolibUtilities.freeNativePointer(localPtr.cast());
      _GolibUtilities.freeNativePointer(remotePtr.cast());
    }
  }

  /// Closes the SSH session.
  Future<void> closeSsh(int sessionId) async {
    await Future.microtask(() => _bindings.CloseSSH(sessionId));
  }

  // --- BS4 PARSING SERVICE (HTML/XML) ---
  
  /// Creates a new BS4 parsing client. Returns session ID (or 0).
  Future<int> newBs4Client(String htmlText, {String? baseUrl}) async {
    final textPtr = _GolibUtilities.toNativeString(htmlText);
    final basePtr = _GolibUtilities.toNativeString(baseUrl);
    try {
      return await Future.microtask(() => _bindings.NewBs4Client(textPtr, basePtr));
    } finally {
      _GolibUtilities.freeNativePointer(textPtr.cast());
      _GolibUtilities.freeNativePointer(basePtr.cast());
    }
  }
  
  /// Copies an existing BS4 client state. Returns new session ID (or 0).
  Future<int> bs4Copy(int sessionId) async {
    return await Future.microtask(() => _bindings.Bs4Copy(sessionId));
  }
  
  /// Closes and cleans up a BS4 client session.
  Future<void> closeBs4Client(int sessionId) async {
    await Future.microtask(() => _bindings.CloseBs4Client(sessionId));
  }

  /// Finds a single element matching the selector. Returns the new element's session ID (or 0).
  Future<int> bs4Find(int sessionId, String selector) async {
    final selectorPtr = _GolibUtilities.toNativeString(selector);
    try {
      return await Future.microtask(() => _bindings.Bs4Find(sessionId, selectorPtr));
    } finally {
      _GolibUtilities.freeNativePointer(selectorPtr.cast());
    }
  }

  /// Finds all elements matching the selector. Returns a list of new session IDs.
  Future<List<int>> bs4Finds(int sessionId, String selector) async {
    final selectorPtr = _GolibUtilities.toNativeString(selector);
    try {
      final resultPtr = await Future.microtask(() => _bindings.Bs4Finds(sessionId, selectorPtr));
      final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
      if (jsonString.startsWith('[')) {
        return (jsonDecode(jsonString) as List).cast<int>();
      }
      return [];
    } finally {
      _GolibUtilities.freeNativePointer(selectorPtr.cast());
    }
  }
  
  // BS4 Traversal Functions (returning multiple IDs)
  Future<List<int>> bs4Childrens(int sessionId, List<String> selectors) async {
    final selectorJson = jsonEncode(selectors);
    final jsonPtr = _GolibUtilities.toNativeString(selectorJson);
    try {
      final resultPtr = await Future.microtask(() => _bindings.Bs4Childrens(sessionId, jsonPtr));
      final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
      return (jsonDecode(jsonString) as List).cast<int>();
    } finally {
      _GolibUtilities.freeNativePointer(jsonPtr.cast());
    }
  }

  Future<List<int>> bs4Parents(int sessionId, List<String> selectors) async {
    final selectorJson = jsonEncode(selectors);
    final jsonPtr = _GolibUtilities.toNativeString(selectorJson);
    try {
      final resultPtr = await Future.microtask(() => _bindings.Bs4Parents(sessionId, jsonPtr));
      final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
      return (jsonDecode(jsonString) as List).cast<int>();
    } finally {
      _GolibUtilities.freeNativePointer(jsonPtr.cast());
    }
  }

  // BS4 Traversal Function (returning single ID)
  Future<int> bs4Next(int sessionId, List<String> selectors) async {
    final selectorJson = jsonEncode(selectors);
    final jsonPtr = _GolibUtilities.toNativeString(selectorJson);
    try {
      return await Future.microtask(() => _bindings.Bs4Next(sessionId, jsonPtr));
    } finally {
      _GolibUtilities.freeNativePointer(jsonPtr.cast());
    }
  }

  // BS4 Getters
  Future<String> bs4Text(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.Bs4Text(sessionId));
    return _GolibUtilities.getStringAndFree(resultPtr);
  }
  
  Future<Map<String, String>> bs4Attrs(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.Bs4Attrs(sessionId));
    final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
    if (jsonString.startsWith('{')) {
      return (jsonDecode(jsonString) as Map).cast<String, String>();
    }
    return {};
  }
  
  Future<String> bs4Get(int sessionId, String key, {String defaultValue = ''}) async {
    final keyPtr = _GolibUtilities.toNativeString(key);
    final defaultPtr = _GolibUtilities.toNativeString(defaultValue);
    try {
      final resultPtr = await Future.microtask(() => _bindings.Bs4Get(sessionId, keyPtr, defaultPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(keyPtr.cast());
      _GolibUtilities.freeNativePointer(defaultPtr.cast());
    }
  }
  
  Future<String> bs4Html(int sessionId, {String? content}) async {
    final contentPtr = _GolibUtilities.toNativeString(content);
    try {
      final resultPtr = await Future.microtask(() => _bindings.Bs4Html(sessionId, contentPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(contentPtr.cast());
    }
  }
  
  Future<List<String>> bs4Strings(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.Bs4Strings(sessionId));
    final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
    if (jsonString.startsWith('[')) {
      return (jsonDecode(jsonString) as List).cast<String>();
    }
    return [];
  }

  // BS4 Setters/Mutations
  Future<void> bs4Set(int sessionId, String key, String value) async {
    final keyPtr = _GolibUtilities.toNativeString(key);
    final valPtr = _GolibUtilities.toNativeString(value);
    try {
      await Future.microtask(() => _bindings.Bs4Set(sessionId, keyPtr, valPtr));
    } finally {
      _GolibUtilities.freeNativePointer(keyPtr.cast());
      _GolibUtilities.freeNativePointer(valPtr.cast());
    }
  }

  Future<void> bs4Append(int sessionId, String content) async {
    final contentPtr = _GolibUtilities.toNativeString(content);
    try {
      await Future.microtask(() => _bindings.Bs4Append(sessionId, contentPtr));
    } finally {
      _GolibUtilities.freeNativePointer(contentPtr.cast());
    }
  }

  Future<void> bs4Remove(int sessionId) async {
    await Future.microtask(() => _bindings.Bs4Remove(sessionId));
  }
  
  Future<void> bs4Clear(int sessionId) async {
    await Future.microtask(() => _bindings.Bs4Clear(sessionId));
  }

  // --- GIT SERVICE ---

  /// Clones a repository into the specified directory.
  Future<String> gitClone(String repoUrl, String directory) async {
    final urlPtr = _GolibUtilities.toNativeString(repoUrl);
    final dirPtr = _GolibUtilities.toNativeString(directory);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitClone(urlPtr, dirPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(urlPtr.cast());
      _GolibUtilities.freeNativePointer(dirPtr.cast());
    }
  }

  /// Pulls changes from the remote.
  Future<String> gitPull(String directory) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitPull(dirPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
    }
  }

  /// Pushes local changes to the remote.
  Future<String> gitPush(String directory) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitPush(dirPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
    }
  }
  
  /// Adds a file or path to the staging area.
  Future<String> gitAdd(String directory, String filePath) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    final filePtr = _GolibUtilities.toNativeString(filePath);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitAdd(dirPtr, filePtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
      _GolibUtilities.freeNativePointer(filePtr.cast());
    }
  }

  /// Commits staged changes.
  Future<String> gitCommit({
    required String directory,
    required String message,
    required String authorName,
    required String authorEmail,
  }) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    final msgPtr = _GolibUtilities.toNativeString(message);
    final namePtr = _GolibUtilities.toNativeString(authorName);
    final emailPtr = _GolibUtilities.toNativeString(authorEmail);
    
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitCommit(dirPtr, msgPtr, namePtr, emailPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
      _GolibUtilities.freeNativePointer(msgPtr.cast());
      _GolibUtilities.freeNativePointer(namePtr.cast());
      _GolibUtilities.freeNativePointer(emailPtr.cast());
    }
  }

  /// Adds a new remote.
  Future<String> gitRemoteAdd({
    required String directory,
    required String remoteName,
    required String remoteUrl,
  }) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    final namePtr = _GolibUtilities.toNativeString(remoteName);
    final urlPtr = _GolibUtilities.toNativeString(remoteUrl);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitRemoteAdd(dirPtr, namePtr, urlPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
      _GolibUtilities.freeNativePointer(namePtr.cast());
      _GolibUtilities.freeNativePointer(urlPtr.cast());
    }
  }

  /// Deletes a remote.
  Future<String> gitRemoteDelete(String directory, String remoteName) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    final namePtr = _GolibUtilities.toNativeString(remoteName);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitRemoteDelete(dirPtr, namePtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
      _GolibUtilities.freeNativePointer(namePtr.cast());
    }
  }

  /// Lists all remotes. Returns list of [GitRemote] or throws error if repo is invalid.
  Future<List<GitRemote>> gitRemoteList(String directory) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitRemoteList(dirPtr));
      final jsonString = _GolibUtilities.getStringAndFree(resultPtr);
      
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is Map && decoded.containsKey('Error')) {
        throw Exception(decoded['Error']);
      }
      
      if (decoded is List) {
        return decoded.map((e) => GitRemote.fromJson(e)).toList();
      }
      return [];
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
    }
  }
  
  /// Fetches from a specific remote.
  Future<String> gitFetch(String directory, String remoteName) async {
    final dirPtr = _GolibUtilities.toNativeString(directory);
    final namePtr = _GolibUtilities.toNativeString(remoteName);
    try {
      final resultPtr = await Future.microtask(() => _bindings.GitFetch(dirPtr, namePtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(dirPtr.cast());
      _GolibUtilities.freeNativePointer(namePtr.cast());
    }
  }
  
  // --- DATA ANALYSIS (DATAFRAME) ---
  
  Future<String> describeData(int sessionId, String optionsJson) async {
    final jsonPtr = _GolibUtilities.toNativeString(optionsJson);
    try {
      final resultPtr = await Future.microtask(() => _bindings.DescribeData(sessionId, jsonPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(jsonPtr.cast());
    }
  }

  Future<String> dataDropNil(int sessionId) async {
    final resultPtr = await Future.microtask(() => _bindings.DataDropNil(sessionId));
    return _GolibUtilities.getStringAndFree(resultPtr);
  }

  Future<String> dataFillNil(int sessionId, String replaceValJson) async {
    final jsonPtr = _GolibUtilities.toNativeString(replaceValJson);
    try {
      final resultPtr = await Future.microtask(() => _bindings.DataFillNil(sessionId, jsonPtr));
      return _GolibUtilities.getStringAndFree(resultPtr);
    } finally {
      _GolibUtilities.freeNativePointer(jsonPtr.cast());
    }
  }

}

// Helper extension for clean error handling on function calls that return
// an empty string on success. (This extension remains valid)
extension on String {
  String? nullIfEmptyOrSuccess() {
    if (isEmpty || startsWith('Success')) {
      return null;
    }
    if (startsWith('Error:') || startsWith('Warning:') || startsWith('PDF Error:')) {
      return this;
    }
    return this; 
  }
}