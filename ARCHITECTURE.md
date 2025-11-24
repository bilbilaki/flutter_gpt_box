# Tool Error Architecture & Data Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LLM (Claude/GPT)                        │
│                  (Parses [TOOL_ERROR] codes)                │
└────────────────────────┬────────────────────────────────────┘
                         │ Tool Call Request
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Tool Function (ToolFunc subclass)              │
│          (TfSMSSender, TfTerminal, TfDownloader, etc.)     │
│                                                              │
│  1. Parse arguments                                         │
│  2. Validate inputs                                         │
│  3. Execute operation                                       │
│  4. Return result or error                                  │
└────────────┬────────────────────────────────┬───────────────┘
             │                                │
     Success │                                │ Failure
             │                                ▼
             │                    ┌──────────────────────┐
             │                    │    ToolError         │
             │                    │  - code              │
             │                    │  - description       │
             │                    │  - suggestion        │
             │                    │  + toMessage()       │
             │                    └──────────┬───────────┘
             │                               │
             ▼                               ▼
    ┌────────────────────┐        ┌──────────────────────┐
    │ ChatContent.text() │        │ ChatContent.text()   │
    │ "Success message"  │        │ "[TOOL_ERROR] ..."   │
    └────────┬───────────┘        └──────────┬───────────┘
             │                               │
             │                               │
             └─────────────┬─────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │    LLM Response Handler          │
        │  (Processes _Ret = List<Chat..>) │
        │                                   │
        │  If [TOOL_ERROR]:                │
        │  - Parse error code              │
        │  - Extract suggestion            │
        │  - Ask user for correction       │
        │  - Retry with corrected params   │
        │                                   │
        │  If success:                     │
        │  - Report to user                │
        │  - Continue conversation         │
        └──────────────────────────────────┘
```

## Error Classification Hierarchy

```
ToolError
├── invalidInput(param)
│   └── Use when: Required parameter is null or empty
│       Code: "invalid_input"
│       Example: Missing "url" in URLLauncher
│
├── notFound(item)
│   └── Use when: Resource doesn't exist
│       Code: "not_found"
│       Example: Contact not in contacts list
│
├── permissionDenied(action)
│   └── Use when: Permission not granted
│       Code: "permission_denied"
│       Example: SMS permission denied
│
├── invalidArgument(param, reason)
│   └── Use when: Parameter value is invalid/unsupported
│       Code: "invalid_argument"
│       Example: Unknown action value
│
├── executionFailed(reason)
│   └── Use when: Operation fails during execution
│       Code: "execution_failed"
│       Example: Network timeout, file write error
│
└── Custom(code, description, suggestion)
    └── Use when: None of above fit
        Code: Custom string
        Example: Domain-specific errors
```

## Error Message Format Specification

```
[TOOL_ERROR] error_code: description. Suggestion: actionable_hint

Components:
├── Prefix: "[TOOL_ERROR] " (Mandatory, consistent)
├── Error Code: "error_code"
│   ├── Characters: lowercase + underscore
│   ├── Examples: invalid_input, not_found, permission_denied
│   └── Purpose: Machine-readable classification
├── Separator: ": "
├── Description: "What happened"
│   ├── Purpose: Human-readable explanation
│   └── Includes: Parameter names, values, context
├── Separator: ". Suggestion: "
├── Suggestion: "How to recover"
│   ├── Purpose: Actionable next steps
│   └── Includes: Specific examples, commands, options
└── End: (No period after suggestion, no exclamation)

Examples:
✓ [TOOL_ERROR] invalid_input: Required parameter "url" is missing. Suggestion: Provide a valid URL (e.g., "https://example.com").
✓ [TOOL_ERROR] not_found: Contact "john" not found. Suggestion: Try "John" or verify the exact name.
✓ [TOOL_ERROR] execution_failed: SMS sending failed: Permission denied. Suggestion: Grant SMS permission in settings and retry.
```

## Data Flow During Error Scenario

### Case 1: Missing Required Parameter

```
┌─────────────────────────┐
│ User Input              │
│ "Send SMS to john"      │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│ LLM Parses Request      │
│ contact="john"          │
│ message=null            │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ TfSMSSender.run() Called        │
│ args: {                         │
│   'contact': 'john',            │
│   'message': null               │
│ }                               │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ Input Validation                │
│ if (message.isEmpty) {          │
│   ← Validation fails            │
│ }                               │
└────────────┬────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│ Create ToolError                         │
│ error = ToolError.invalidInput(          │
│   'message',                             │
│   suggestion: 'Provide message content'  │
│ )                                        │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│ Generate Error Message                           │
│ "[TOOL_ERROR] invalid_input: Required parameter │
│ \"message\" is missing. Suggestion: Provide      │
│ message content."                                │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│ Return to LLM                                    │
│ ChatContent.text(error.toMessage())              │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│ LLM Processes Error                              │
│ • Extracts code: "invalid_input"                │
│ • Reads suggestion: "Provide message content"   │
│ • Asks user: "What message for john?"           │
└──────────────────────────────────────────────────┘
```

### Case 2: Resource Not Found

```
┌─────────────────────────────────┐
│ User Input                       │
│ "Send SMS to 'xyz'"              │
└────────────┬────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│ Validation Passes                    │
│ • contact="xyz" (not empty)          │
│ • message="Hello" (not empty)        │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│ findContactNumber("xyz")             │
│ • Query contacts database            │
│ • No match found                     │
│ • Return empty string                │
└────────────┬─────────────────────────┘
             │ finalNumber.isEmpty()
             ▼
┌────────────────────────────────────────────┐
│ Create ToolError                           │
│ error = ToolError.notFound(                │
│   'Contact "xyz"',                         │
│   suggestion: 'Verify spelling/case or...' │
│ )                                          │
└────────────┬───────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│ Generate Error Message                           │
│ "[TOOL_ERROR] not_found: Contact \"xyz\" not    │
│ found. Suggestion: Verify spelling/case or try  │
│ a variation (e.g., \"XYZ\")."                    │
└────────────┬─────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────┐
│ LLM Processes Error                              │
│ • Extracts code: "not_found"                    │
│ • Reads suggestion with example: "xyz" → "XYZ" │
│ • Asks user: "Did you mean 'John'? (example)"  │
└──────────────────────────────────────────────────┘
```

## State Transitions in Tool Function

```
                    ┌─────────────┐
                    │ Tool Called │
                    └──────┬──────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
         ┌──────────────┐      ┌──────────────┐
         │   Validate   │      │   Validate   │
         │    Args 1    │      │    Args 2    │
         └──────┬───────┘      └──────┬───────┘
                │                     │
         ❌ Invalid              ✓ Valid
                │                     │
                ▼                     ▼
         ┌──────────────┐      ┌──────────────┐
         │ invalidInput │      │   Execute    │
         │    Error     │      │  Operation   │
         └──────┬───────┘      └──────┬───────┘
                │                     │
                │              ❌ Exception
                │                     │
                │                ✓ Success
                │                     │
                │              ┌──────┴───────┐
                │              │              │
                │              ▼              ▼
                │        ┌─────────┐    ┌─────────────┐
                │        │ Success │    │ Execution   │
                │        │ Message │    │ Failed Err. │
                │        └────┬────┘    └────┬────────┘
                │             │             │
                └─────────────┬─────────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │ Return ChatContent  │
                    │ to LLM              │
                    └─────────────────────┘
```

## Integration with LLM Retry Loop

```
LLM Interaction Flow with Error Handling
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Iteration 1:
┌─ User Request ─────────────────────────┐
│ "Send SMS to john"                      │
└────────────────────────────────────────┘
           ↓
┌─ LLM Decision ─────────────────────────┐
│ Call TfSMSSender with incomplete args  │
│ (missing message parameter)            │
└────────────────────────────────────────┘
           ↓
┌─ Tool Response ────────────────────────┐
│ [TOOL_ERROR] invalid_input: ...        │
│ Suggestion: Provide message content.   │
└────────────────────────────────────────┘
           ↓
┌─ LLM Processing ───────────────────────┐
│ • Parse error code → "invalid_input"   │
│ • Recognize: Parameter missing         │
│ • Action: Ask user for it              │
└────────────────────────────────────────┘

Iteration 2:
┌─ LLM to User ──────────────────────────┐
│ "What message should I send to john?"  │
└────────────────────────────────────────┘
           ↓
┌─ User Response ────────────────────────┐
│ "I'm on my way"                         │
└────────────────────────────────────────┘
           ↓
┌─ LLM Decision ─────────────────────────┐
│ Call TfSMSSender with all args now:    │
│ • contact: "john"                      │
│ • message: "I'm on my way"             │
└────────────────────────────────────────┘
           ↓
┌─ Tool Response ────────────────────────┐
│ "Successfully sent SMS to john."       │
└────────────────────────────────────────┘
           ↓
┌─ LLM to User ──────────────────────────┐
│ "Done! I've sent the message to john." │
└────────────────────────────────────────┘

✅ Success with automatic recovery!
```

## Extension Points

### Adding New Error Type

```dart
// 1. Add factory in ToolError class
factory ToolError.rateLimited(String action, {String? suggestion}) =>
    ToolError(
      code: 'rate_limited',
      description: 'Rate limit exceeded for "$action".',
      suggestion: suggestion ?? 'Wait a moment before retrying.',
    );

// 2. Use in tool
if (requests > limit) {
  final error = ToolError.rateLimited('API calls');
  return [ChatContent.text(error.toMessage())];
}
```

### Tool-Specific Error Codes (Recommended Pattern)

```dart
// Namespace error codes by tool
[TOOL_ERROR] sms_contact_not_found: Contact not found...
[TOOL_ERROR] download_file_exists: File already exists...
[TOOL_ERROR] file_permission_denied: Permission denied...
[TOOL_ERROR] terminal_command_not_found: Command not found...
```

This architecture enables reliable, correctable tool interactions with language models.
