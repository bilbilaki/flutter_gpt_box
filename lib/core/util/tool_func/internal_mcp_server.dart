part of 'tool.dart';

/// Internal MCP server that provides built-in tools like Memory, History, and HTTP
/// This allows all tools to be handled through the unified MCP protocol
class InternalMcpServer {
  static const String serverName = '__internal__';

  /// Handle internal tool calls
  static Future<_Ret?> handleToolCall(
    String toolName,
    Map<String, dynamic> arguments,
    OnToolLog onToolLog,
  ) async {
    // Create a mock call response for compatibility with existing tool functions
    final mockCall = _CallResp(
      id: 'internal_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: toolName,
        arguments: json.encode(arguments),
      ),
    );

    switch (toolName) {
      case 'memory':
        onToolLog('[$serverName] Executing memory tool...');
        return await TfMemory.instance.run(mockCall, arguments, onToolLog);
      case 'history':
        onToolLog('[$serverName] Executing history tool...');
        return await TfHistory.instance.run(mockCall, arguments, onToolLog);
      case 'httpReq':
        onToolLog('[$serverName] Executing HTTP request tool...');
        return await TfHttpReq.instance.run(mockCall, arguments, onToolLog);
      case 'terminal':
        onToolLog('[$serverName] Executing Terminal request tool...');
        return await TfTerminal.instance.run(mockCall, arguments, onToolLog);
      case 'urlluancher':
        onToolLog('[$serverName] Opening url for User...');
        return await TfUrlLuancher.instance.run(mockCall, arguments, onToolLog);
      case 'smssender':
        onToolLog('[$serverName] Sending SMS Message...');
        return await TfSMSSender.instance.run(mockCall, arguments, onToolLog);
      case 'downloader':
        onToolLog('[$serverName] Managing Download Task...');
        return await TfDownloader.instance.run(mockCall, arguments, onToolLog);
      case 'filemanager':
        onToolLog('[$serverName]  Managing Files...');
        return await TfFileManager.instance.run(mockCall, arguments, onToolLog);
      case 'pdfmanager':
        onToolLog('[$serverName]  Useing PDF Tools...');
        return await TfPdfManager.instance.run(mockCall, arguments, onToolLog);
      case 'zipmanager':
        onToolLog('[$serverName]  Useing Zip Manager Tools...');
        return await TfZipManager.instance.run(mockCall, arguments, onToolLog);
      case 'webbuilder':
        onToolLog('[$serverName]  Useing Web Builder Tools please wait...');
        return await TfWebBuilder.instance.run(mockCall, arguments, onToolLog);
      case 'pythonProjectBuilder':
        onToolLog(
          '[$serverName]  Useing pythonProjectBuilder Tools please wait...',
        );
        return await TfPythonProjectBuilder.instance.run(
          mockCall,
          arguments,
          onToolLog,
        );
      case 'goProjectBuilder':
        onToolLog(
          '[$serverName]  Useing goProjectBuilder Tools please wait...',
        );
        return await TfGoProjectBuilder.instance.run(
          mockCall,
          arguments,
          onToolLog,
        );
      default:
        onToolLog('[$serverName] Unknown tool: $toolName');
        return null;
    }
  }
}
