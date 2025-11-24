# Agent Orchestrator - Usage Guide

## Overview

The `AgentOrchestrator` class implements a dual-agent system for browser automation:

- **Brain 1 (Router)**: Analyzes user requests and selects the appropriate tool category
- **Brain 2 (Specialist)**: Executes specific tools within that category in a loop until the task is complete

## Architecture

```
User Request
    ↓
[Brain 1: Router] (gpt-4o-mini)
    ↓
Selects Category (e.g., "elementInteractionTools")
    ↓
[Brain 2: Specialist] (gpt-4o) ←─┐
    ↓                              │
Calls Tools (click, type, etc.)   │
    ↓                              │
Tool Results ──────────────────────┘
    ↓
Final Answer → User
```

## Quick Start

### 1. Initialize the Orchestrator

```dart
import 'package:openai_dart/openai_dart.dart';
import 'agent_orchestrator.dart';

// Create OpenAI client
final client = OpenAIClient(
  apiKey: 'your-api-key',
);

// Create orchestrator
final orchestrator = AgentOrchestrator(
  client: client,
  maxSpecialistIterations: 20, // Optional, default is 20
);
```

### 2. Run a Workflow

```dart
// Simple usage
final result = await orchestrator.runWorkflow(
  "Go to google.com and search for Flutter"
);
print(result);

// Verbose usage (with debug output)
final result = await orchestrator.runWorkflowVerbose(
  "Click the login button and type my email"
);
```

### 3. Advanced Usage

```dart
// Check session status
final status = orchestrator.getSessionStatus();
print(status['browserSession']);
print(status['conversationLength']);

// Access browser directly if needed
final browser = orchestrator.browser;
await browser.loadUrl('https://example.com');

// Clear conversation history
orchestrator.clearHistory();

// Close browser session
await orchestrator.closeBrowserSession();
```

## Tool Categories

The router automatically selects from these categories:

1. **browserSessionTools**: Initialize/close browser, session management
2. **navigationTools**: Load URLs, navigate history, get page info
3. **elementInteractionTools**: Click, type, hover, focus, key presses
4. **elementInspectionTools**: Read text, check elements, get values
5. **formTools**: Fill forms, select dropdowns, submit
6. **scrollingTools**: Scroll to elements or positions
7. **waitingTools**: Wait for elements or navigation
8. **screenshotTools**: Capture page or element screenshots
9. **advancedTools**: Execute JavaScript, manage cookies, viewport

## Example Workflows

### Example 1: Simple Navigation

```dart
final result = await orchestrator.runWorkflow(
  "Initialize browser and go to https://github.com"
);
// Router → browserSessionTools
// Specialist → initialize_browser_session, load_url
```

### Example 2: Form Filling

```dart
final result = await orchestrator.runWorkflow(
  "Fill in the email field with 'test@example.com' and click submit"
);
// Router → formTools or elementInteractionTools
// Specialist → type_in_element, click_element
```

### Example 3: Data Extraction

```dart
final result = await orchestrator.runWorkflow(
  "Read all the article titles on the page"
);
// Router → elementInspectionTools
// Specialist → get_texts_of_all_elements
```

## How It Works

### Phase 1: Routing (Brain 1)

1. User input added to conversation history
2. Router (gpt-4o-mini) analyzes the request
3. Router calls `select_tool_category` with:
   - `category`: Tool category name
   - `task_information`: Specific instructions for specialist

### Phase 2: Execution (Brain 2)

1. Specialist receives its own fresh context with the task
2. Specialist loops:
   - Decides which tool to call
   - Executes the tool (actual browser operation)
   - Receives tool result
   - Decides next action or finishes
3. Returns final answer when complete

### Safety Features

- **Max iterations**: Prevents infinite loops (default 20)
- **Error handling**: Catches and reports tool execution errors
- **Session validation**: Checks browser session before operations
- **Verbose logging**: Optional debug output for troubleshooting

## Integration with UI

```dart
class BrowserAutomationScreen extends StatefulWidget {
  @override
  State<BrowserAutomationScreen> createState() => _BrowserAutomationScreenState();
}

class _BrowserAutomationScreenState extends State<BrowserAutomationScreen> {
  late AgentOrchestrator orchestrator;
  String result = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    orchestrator = AgentOrchestrator(client: Cfg.client);
  }

  Future<void> executeTask(String task) async {
    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      final response = await orchestrator.runWorkflow(task);
      setState(() {
        result = response;
      });
    } catch (e) {
      setState(() {
        result = 'Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    orchestrator.closeBrowserSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Your UI here
  }
}
```

## Benefits Over Old System

### Before (toolagent2, toolagent3, etc.)
- ❌ Separate functions for each tool category
- ❌ Manual routing logic
- ❌ Duplicate code for tool execution
- ❌ Hard to add new tool categories
- ❌ No conversation context maintained

### After (AgentOrchestrator)
- ✅ Single unified workflow
- ✅ AI-powered smart routing
- ✅ Reusable tool execution loop
- ✅ Easy to extend (just add to AgentTools)
- ✅ Full conversation history tracking

## Debugging

Enable verbose mode to see detailed execution:

```dart
final result = await orchestrator.runWorkflowVerbose(
  "Your task here"
);
```

Output shows:
- Router decision
- Category selected
- Each tool call with arguments
- Tool results
- Specialist iterations
- Final answer

## Customization

### Custom Browser Controller

```dart
final customBrowser = BrowserController();
// ... configure browser ...

final orchestrator = AgentOrchestrator(
  client: client,
  browser: customBrowser,
);
```

### Custom Iteration Limit

```dart
final orchestrator = AgentOrchestrator(
  client: client,
  maxSpecialistIterations: 50, // Increase for complex tasks
);
```

## Error Handling

The orchestrator handles errors gracefully:

- Unknown tools: Returns error message
- Tool execution failures: Catches and reports to specialist
- Max iterations: Returns timeout message
- Browser session errors: Validates and reports

## Performance Tips

1. **Use specific requests**: "Click the login button" vs "Do login stuff"
2. **One task per workflow**: Break complex tasks into steps
3. **Clear history periodically**: `orchestrator.clearHistory()`
4. **Monitor iterations**: Check if tasks are looping inefficiently

## Future Enhancements

Possible improvements:
- Streaming responses for real-time feedback
- Parallel tool execution
- Tool result caching
- Multi-step task planning
- Browser session pooling
