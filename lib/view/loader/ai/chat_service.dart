import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'tools_handler.dart';
import 'config.dart'; 
class ChatService extends ChangeNotifier {
  final Config config;
  final ToolsHandler toolsHandler;
  
  List<Message> messages = [];
  bool isThinking = false;
  String currentStreamingContent = "";

  ChatService(this.config, String rootPath) : toolsHandler = ToolsHandler(rootPath) {
    _initSystemPrompt();
  }

  void _initSystemPrompt() {
    String os = Platform.operatingSystem;
    messages.add(Message(
      role: "system", 
      content: "You are an advanced coding assistant. OS: $os\n"
               "Use 'list_files' to see the repo structure.\n"
               "Use 'read_file' to see code with line numbers.\n"
               "Use 'patch_file' to edit. Syntax: 'N++ code', 'N--', '0++' (prepend), '00++' (append).\n"
               "Be concise."
    ));
  }

  // Called by UI
  Future<void> sendMessage(String text) async {
    messages.add(Message(role: "user", content: text));
    notifyListeners();
    await _runLoop();
  }

  Future<void> _runLoop() async {
    bool keepGoing = true;

    while (keepGoing) {
      isThinking = true;
      currentStreamingContent = "";
      notifyListeners();

      // 1. Prepare Request
      final requestBody = {
        "model": config.currentModel,
        "messages": messages.map((e) => e.toJson()).toList(),
        "stream": true,
        "tools": toolsHandler.getToolDefinitions().map((e) => e.toJson()).toList(),
      };

      // 2. Start Request
      try {
        final request = http.Request("POST", Uri.parse("${config.baseUrl}/v1/chat/completions"));
        request.headers['Authorization'] = "Bearer ${config.apiKey}";
        request.headers['Content-Type'] = "application/json";
        request.body = jsonEncode(requestBody);

        final response = await http.Client().send(request);

        // 3. Stream & Parse
        Map<int, ToolCall> pendingToolCalls = {};
        
        await for (var line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (!line.startsWith("data: ")) continue;
          final jsonStr = line.substring(6).trim();
          if (jsonStr == "[DONE]") break;

          try {
            final chunk = jsonDecode(jsonStr);
            final delta = chunk['choices'][0]['delta'];

            // Handle Content
            if (delta['content'] != null) {
              currentStreamingContent += delta['content'];
              notifyListeners();
            }

            // Handle Tool Calls (fragments)
            if (delta['tool_calls'] != null) {
              for (var tc in delta['tool_calls']) {
                int idx = tc['index'];
                if (!pendingToolCalls.containsKey(idx)) {
                  pendingToolCalls[idx] = ToolCall(
                    id: tc['id'] ?? "", 
                    type: "function", 
                    function: FunctionCall(name: "", arguments: "")
                  );
                }
                if (tc['id'] != null) pendingToolCalls[idx]!.id = tc['id'];
                if (tc['function']['name'] != null) pendingToolCalls[idx]!.function.name += tc['function']['name'];
                if (tc['function']['arguments'] != null) pendingToolCalls[idx]!.function.arguments += tc['function']['arguments'];
              }
            }
          } catch (e) {
            print("Parse error: $e");
          }
        }

        // 4. Finalize Assistant Message
        final assistantMsg = Message(
          role: "assistant",
          content: currentStreamingContent,
          toolCalls: pendingToolCalls.isEmpty ? null : pendingToolCalls.values.toList(),
        );
        messages.add(assistantMsg);
        currentStreamingContent = ""; // Reset buffer
        
        // 5. Execute Tools?
        if (pendingToolCalls.isEmpty) {
          keepGoing = false;
        } else {
          // Execute all tools
          for (var tc in pendingToolCalls.values) {
             // In UI, we might show "Executing..."
             Map<String, dynamic> args = {};
             try {
               args = jsonDecode(tc.function.arguments);
             } catch(e) { 
               args = {}; 
             }
             
             String output = await toolsHandler.execute(tc.function.name, args);
             
             // Add result to history
             messages.add(Message(
               role: "tool", 
               content: output, 
               toolCallId: tc.id
             ));
          }
          // Loop continues -> sends tool outputs back to AI
        }

      } catch (e) {
        messages.add(Message(role: "system", content: "Error: $e"));
        keepGoing = false;
      }
    }

    isThinking = false;
    notifyListeners();
  }
}