// agent_orchestrator.dart

import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';
import '../../../data/res/openai.dart';
import 'agent_tools.dart';
import 'browser_controller.dart';

/// The main orchestrator that coordinates between the router (Brain 1) and specialists (Brain 2).
/// This replaces the old toolagent2, toolagent3 pattern with a smart, stateful workflow.
/// 
/// Workflow:
/// 1. User input goes to Router (Brain 1) - selects tool category
/// 2. Router routes to Specialist (Brain 2) - executes tools in that category
/// 3. Specialist loops until task complete
/// 4. Result returned to user
class AgentOrchestrator {
  final OpenAIClient client;
  final BrowserController browserController;
  late final AgentTools agentTools;

  // History for the entire conversation across all workflow runs
  final List<ChatCompletionMessage> _mainHistory = [];

  // Maximum iterations for the specialist loop (safety limit)
  final int maxSpecialistIterations;

  AgentOrchestrator({
    required this.client,
    BrowserController? browser,
    this.maxSpecialistIterations = 20,
  }) : browserController = browser ?? BrowserController() {
    agentTools = AgentTools(browser: browserController);
    
    // Add the system prompt for the "Router" (Brain 1)
    _mainHistory.add(
      const ChatCompletionMessage.system(
        content: "You are a master orchestrator for browser automation tasks. "
                 "Your job is to analyze a user's request and route it to the correct specialist tool category. "
                 "Consider what type of action the user wants to perform:\n"
                 "- browserSessionTools: Starting/stopping browser, session management\n"
                 "- navigationTools: Loading URLs, going back/forward, page information\n"
                 "- elementInteractionTools: Clicking, typing, hovering, focusing\n"
                 "- elementInspectionTools: Reading text, checking if elements exist, getting values\n"
                 "- formTools: Filling forms, selecting dropdowns, submitting\n"
                 "- scrollingTools: Scrolling page or to specific elements\n"
                 "- waitingTools: Waiting for elements or navigation\n"
                 "- screenshotTools: Taking screenshots\n"
                 "- advancedTools: JavaScript execution, cookies, viewport settings\n"
                 "Always use the 'select_tool_category' function.",
      ),
    );
  }

  /// The main entry point for running a complete workflow.
  /// Takes user input, routes through Brain 1, executes via Brain 2, returns final result.
  Future<String> runWorkflow(String userInput) async {
    // Add user input to main history
    _mainHistory.add(ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(userInput),
    ));

    // === STEP 1: CALL THE ROUTER (BRAIN 1) ===
    print("--- 🧠 Calling Router (Brain 1) ---");
    
    final routerResponse = await client.createChatCompletion(
      request: CreateChatCompletionRequest(
        model:  ChatCompletionModel.modelId(Cfg.current.model), // Fast, cheap model for routing
        messages: _mainHistory,
        tools: [AgentTools.toolSelector],
        toolChoice: const ChatCompletionToolChoiceOption.mode(
          ChatCompletionToolChoiceMode.required,
        ),
      ),
    );

    final routerMessage = routerResponse.choices.first.message;
    _mainHistory.add(routerMessage); // Add router's decision to history

    // Get the router's decision
    if (routerMessage.toolCalls == null || routerMessage.toolCalls!.isEmpty) {
      return "Error: The router failed to select a tool category.";
    }

    final routerCall = routerMessage.toolCalls!.first;
    final arguments = json.decode(routerCall.function.arguments) as Map<String, dynamic>;
    final String category = arguments['category'];
    final String taskInfo = arguments['task_information'];

    print("--- 📍 Routing to: $category ---");
    print("--- 📋 Task: $taskInfo ---");

    // === STEP 2: PREPARE THE SPECIALIST (BRAIN 2) ===
    // Build specialist tools: include session + waiting tools for resilience
    final Map<String, List<ChatCompletionTool>> allToolLists = agentTools.getSpecialistToolList();
    final Map<String, Map<String, Function>> allFunctionMaps = agentTools.getSpecialistFunctionMap();

    final List<ChatCompletionTool>? categoryTools = allToolLists[category];
    final Map<String, Function>? categoryFunctionMap = allFunctionMaps[category];

    if (categoryTools == null || categoryFunctionMap == null) {
      return "Error: Could not find tools for category '$category'.";
    }

    // Merge base tools (session + waiting) with category-specific tools, avoid duplicates by tool name
    List<ChatCompletionTool> baseTools = [
      ...agentTools.browserSessionTools,
      ...agentTools.waitingTools,
    ];
    final Map<String, ChatCompletionTool> toolByName = {};
    for (final t in [...baseTools, ...categoryTools]) {
      final name = t.function.name;
      if (name.isNotEmpty) toolByName[name] = t; // later entries overwrite earlier
    }
    final List<ChatCompletionTool> specialistTools = toolByName.values.toList();

    // Merge function maps (category has priority over base if name collision)
    final Map<String, Function> specialistFunctionMap = {
      ...agentTools.browserSessionToolMap,
      ...agentTools.waitingToolMap,
      ...categoryFunctionMap,
    };

    // Ensure a running browser session for any non-session category before starting
    if (category != 'browserSessionTools') {
      final ensured = await _ensureSessionReady();
      if (!ensured) {
        return "Error: Failed to initialize browser session in time. Please try again.";
      }
    }

    // Create a new, temporary message list for the specialist
    final List<ChatCompletionMessage> specialistHistory = [
      ChatCompletionMessage.system(
        content: "You are a specialist agent for '$category'. "
                 "Your task is: '$taskInfo'. "
                 "Execute the steps needed, one by one, using your tools. "
                 
                 "--- CRITICAL FAILURE INSTRUCTIONS ---"
                 "If a tool returns an error (e.g., 'Timeout', 'Error loading URL', or you see a 'recaptcha'), "
                 "DO NOT just give up or say 'I failed.' "
                 "Your job is to REPORT THE PROBLEM CLEARLY."
                 "A good final response is: 'I was unable to load the page because it is protected by a reCAPTCHA.' "
                 "A bad final response is: 'I'm sorry, I can't do that.' "
                 "Report the *reason* for the failure. This is a successful completion of your task."
                 
                 "--- Standard Operating Rules ---"
                 "1) ALWAYS call 'initialize_browser_session' first if 'get_session_status' shows 'isActive: false'. "
                 "2) ALWAYS call 'wait_for_navigation' after 'load_url' or 'click_element' if you expect a new page to load. "
                 "3. Report the final result or the final error message clearly to the user.",
      ),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(
          "Please begin the task: $taskInfo",
        ),
      ),
    ];

    // === STEP 3: RUN THE SPECIALIST LOOP (BRAIN 2) ===
    // This loop continues until the specialist gives a final text answer
    int iteration = 0;
    
    while (iteration < maxSpecialistIterations) {
      iteration++;
      print("--- 🛠️ Calling Specialist (Brain 2) - Iteration $iteration ---");

      final specialistResponse = await client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model:  ChatCompletionModel.modelId(Cfg.current.model), // Powerful model for execution
          messages: specialistHistory,
          tools: specialistTools,
        ),
      );

      final specialistMessage = specialistResponse.choices.first.message;
      specialistHistory.add(specialistMessage);

      // CASE 1: Specialist wants to call one or more tools
      if (specialistMessage.toolCalls != null && specialistMessage.toolCalls!.isNotEmpty) {
        
        for (final toolCall in specialistMessage.toolCalls!) {
          final toolName = toolCall.function.name;
          final toolArgs = json.decode(toolCall.function.arguments) as Map<String, dynamic>;
          
          print("--- 🔧 Specialist calling tool: $toolName ---");
          print("--- 📥 Arguments: $toolArgs ---");

          // Find and execute the actual Dart function
          final Function? toolFunction = specialistFunctionMap[toolName];
          String toolResult;

          if (toolFunction == null) {
            toolResult = "Error: Unknown tool '$toolName'.";
          } else {
            try {
              // This is where the actual BrowserController method is executed
              final result = await toolFunction(toolArgs);
              toolResult = result.toString();
              // If a tool indicates inactive session, attempt one-time auto-recovery
              if (toolResult.toLowerCase().contains('browser session not active')) {
                print("--- 🔁 Auto-recover: attempting to initialize browser session ---");
                final ok = await _ensureSessionReady();
                final recoveryMsg = ok
                    ? 'Auto-recovery: Browser session initialized and ready.'
                    : 'Auto-recovery failed: Could not initialize browser session.';
                toolResult = toolResult + "\n" + recoveryMsg;
              }
            } catch (e) {
              toolResult = "Error executing tool '$toolName': $e";
            }
          }

          print("--- 📤 Tool result: ${toolResult.substring(0, toolResult.length > 200 ? 200 : toolResult.length)}${toolResult.length > 200 ? '...' : ''} ---");
const int maxResultLength = 2000; // Max 2000 chars
          String truncatedResult = toolResult;
          if (toolResult.length > maxResultLength) {
            truncatedResult = toolResult.substring(0, maxResultLength) + 
                              "... [Result truncated]";
          }
          // Add the tool's result to history for the next loop iteration
        specialistHistory.add(
            ChatCompletionMessage.tool(
              toolCallId: toolCall.id,
              content: truncatedResult, // <-- USE THE TRUNCATED RESULT
            ),
          );
        }
        // Continue to the next iteration of the while loop
        continue;
      }

      // CASE 2: Specialist is finished (no tool call, just a text answer)
      final content = specialistMessage.content;
      if (content != null && content.isNotEmpty) {
        print("--- ✅ Specialist Finished Successfully ---");
        _mainHistory.add(specialistMessage); // Add final answer to main history
        return content; // Exit the loop and return the answer
      }

      // Fallback for unexpected response
      print("--- ⚠️ Warning: Specialist responded without tool call or text content ---");
    }

    // If we hit the iteration limit
    return "Error: Specialist agent reached maximum iterations ($maxSpecialistIterations) without completing the task. "
           "The task may be too complex or the agent got stuck in a loop.";
  }

  /// Ensure the browser session is initialized and ready.
  /// Returns true if ready, false on timeout or failure.
  /// Timeout is 1000 seconds.
  Future<bool> _ensureSessionReady() async {
    try {
      // If already active, consider it ready
      if (browserController.isSessionActive) {
        return true;
      }

      // Attempt initialization
      print("--- 🚀 Initializing browser session (preflight) ---");
      final initMsg = await browserController.initializeBrowserSession(null);
      print("--- 📣 Init message: $initMsg ---");

      // Poll until active or timeout (1000 seconds)
      final Duration timeout = const Duration(seconds: 1000);
      final int maxChecks = (timeout.inMilliseconds / 250).ceil();
      for (int i = 0; i < maxChecks; i++) {
        if (browserController.isSessionActive) {
          // Optional: verify page loading state if available
          try {
            final loading = await browserController.isPageLoading();
            if (loading == false) {
              return true;
            }
          } catch (_) {
            // If isPageLoading not usable here, still accept active session
            return true;
          }
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }
      return browserController.isSessionActive;
    } catch (e) {
      print("--- ❌ Failed to ensure session ready: $e ---");
      return false;
    }
  }

  /// Run a workflow with verbose output for debugging
  Future<String> runWorkflowVerbose(String userInput) async {
    print("\n════════════════════════════════════════");
    print("🚀 STARTING NEW WORKFLOW");
    print("════════════════════════════════════════");
    print("📝 User Input: $userInput");
    print("════════════════════════════════════════\n");
    
    final result = await runWorkflow(userInput);
    
    print("\n════════════════════════════════════════");
    print("🏁 WORKFLOW COMPLETE");
    print("════════════════════════════════════════");
    print("📊 Result: $result");
    print("════════════════════════════════════════\n");
    
    return result;
  }

  /// Clear the conversation history (useful for starting fresh)
  void clearHistory() {
    _mainHistory.clear();
    // Re-add the system prompt
    _mainHistory.add(
      const ChatCompletionMessage.system(
        content: "You are a master orchestrator for browser automation tasks. "
                 "Your job is to analyze a user's request and route it to the correct specialist tool category. "
                 "Consider what type of action the user wants to perform:\n"
                 "- browserSessionTools: Starting/stopping browser, session management\n"
                 "- navigationTools: Loading URLs, going back/forward, page information\n"
                 "- elementInteractionTools: Clicking, typing, hovering, focusing\n"
                 "- elementInspectionTools: Reading text, checking if elements exist, getting values\n"
                 "- formTools: Filling forms, selecting dropdowns, submitting\n"
                 "- scrollingTools: Scrolling page or to specific elements\n"
                 "- waitingTools: Waiting for elements or navigation\n"
                 "- screenshotTools: Taking screenshots\n"
                 "- advancedTools: JavaScript execution, cookies, viewport settings\n"
                 "Always use the 'select_tool_category' function.",
      ),
    );
  }

  /// Get the current conversation history
  List<ChatCompletionMessage> get history => List.unmodifiable(_mainHistory);

  /// Get the current session status
  Map<String, dynamic> getSessionStatus() {
    return {
      'browserSession': browserController.getSessionStatus(),
      'conversationLength': _mainHistory.length,
    };
  }

  /// Close the browser session
  Future<String> closeBrowserSession() async {
    return await browserController.closeBrowserSession();
  }

  /// Get browser controller for direct access if needed
  BrowserController get browser => browserController;
}
