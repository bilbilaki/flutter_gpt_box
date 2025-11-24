# Tool Error Pattern Improvements for LLM Self-Correction

## Overview

This document describes the standardized error handling pattern implemented across all tool functions in the GPT Box application. The new pattern enables **LLM self-correction** by providing structured, machine-readable error messages with actionable suggestions.

## Problem Solved

Previously, tool functions returned natural-language failures like:
```
"failed to sending sms message"
"Error: couldn't find a phone number for the provided contact"
"Copy failed (e.g., invalid paths or permissions)."
```

These messages made it difficult for language models to:
- Understand what went wrong
- Retry with corrected parameters
- Provide useful guidance to users

## Solution: `ToolError` Class

A new `ToolError` data class in `type.dart` provides a consistent error format:

```dart
class ToolError {
  final String code;        // Machine-readable error code
  final String description; // Human-readable explanation
  final String? suggestion; // Actionable suggestion for retry
  
  String toMessage(); // Formats as: [TOOL_ERROR] code: description. Suggestion: hint
}
```

### Example Output

```
[TOOL_ERROR] not_found: Contact "John" not found. Suggestion: Verify spelling/case or provide an exact phone number. Try a slight variation (e.g., "John" vs "john").
```

## Error Codes

Predefined factory constructors for common error patterns:

| Code | Use Case | Example |
|------|----------|---------|
| `invalid_input` | Required parameter missing/empty | `url` param required |
| `not_found` | Resource doesn't exist | Contact, file, or task not found |
| `permission_denied` | Access not granted | SMS permission required |
| `invalid_argument` | Parameter value is wrong | Invalid action or format |
| `execution_failed` | Operation failed during execution | Network error, file write failed |

## Implementation Across Tools

### 1. **contectsms.dart** (TfSMSSender)
- ❌ Before: `"failed to sending sms message"`
- ✅ After: `[TOOL_ERROR] invalid_input: Required parameter "contact" is missing or empty. Suggestion: Provide both a contact name and message content.`

**Key Changes:**
- `findContactNumber()` now returns empty string (not error text)
- SMS send errors use standardized suggestions
- Permission errors guide user to system settings

---

### 2. **urlluancher.dart** (TfUrlLuancher)
- ❌ Before: `"failed to open url for user"`
- ✅ After: `[TOOL_ERROR] invalid_input: Required parameter "url" is missing or empty. Suggestion: Provide a valid URL (e.g., "https://example.com").`

**Key Changes:**
- Structured validation with actionable feedback
- Execution failures include retry suggestions

---

### 3. **terminal.dart** (TfTerminal)
- ❌ Before: `"Error executing command: $e"`
- ✅ After: `[TOOL_ERROR] execution_failed: Command execution failed: Permission denied. Suggestion: Verify the command syntax and ensure all required tools are installed.`

**Key Changes:**
- Non-zero exit codes include structured error info
- Exception messages include recovery suggestions

---

### 4. **filemanager.dart** (TfFileManager)
- ❌ Before: `{"error": "'path' is required for the 'list' action."}`
- ✅ After: `[TOOL_ERROR] invalid_input: Required parameter "path" is missing or empty. Suggestion: Provide a directory path.`

**Key Changes:**
- All actions (list, tree, read, create, delete, copy, move, search) standardized
- Removed dead code and JSON error objects
- Clear distinction between different error types

---

### 5. **download.dart** (TfDownloader)
- ❌ Before: `"Error: Specify only one action (checkStatus or cancelTask)."`
- ✅ After: `[TOOL_ERROR] invalid_argument: Both checkStatus and cancelTask are true. Suggestion: Specify only one action per call: either checkStatus or cancelTask.`

**Key Changes:**
- Action validation errors use structured format
- APK installation errors guide user on permissions/storage
- Task not found errors suggest taskId verification

---

## Benefits for LLM Self-Correction

### 1. **Parseable Format**
LLM can extract the error code programmatically:
```
Pattern: /\[TOOL_ERROR\] (\w+):/
Match: contact_not_found
```

### 2. **Actionable Suggestions**
Instead of generic failures, the LLM gets concrete retry hints:
```
Suggestion: Verify spelling/case or provide an exact phone number.
```

### 3. **Consistent Pattern**
All tools follow the same format, making it easier for LLMs to learn and apply recovery logic.

### 4. **Context Preservation**
Error messages include the problematic parameter names and values, enabling better reprompting.

## Usage Examples

### Successful Operation
```
ChatContent.text("Successfully sent SMS to John.")
```

### Validation Error
```dart
final error = ToolError.invalidInput(
  'contact',
  suggestion: 'Provide both a contact name and message content.',
);
return [ChatContent.text(error.toMessage())];
```

### Not Found Error
```dart
final error = ToolError.notFound(
  'Download task with ID "$taskId"',
  suggestion: 'Verify the taskId from a previous download call or check active/completed tasks.'
);
return [ChatContent.text(error.toMessage())];
```

### Execution Error
```dart
final error = ToolError.executionFailed(
  'SMS sending failed during transmission: $e',
  suggestion: 'Verify SIM status, network connection, and provider support.',
);
return [ChatContent.text(error.toMessage())];
```

## Migration Guide

For new tools or existing tools needing updates:

1. **Instead of plain text errors:**
   ```dart
   // ❌ Don't do this
   return [ChatContent.text("Error: something failed")];
   ```

2. **Use ToolError factories:**
   ```dart
   // ✅ Do this
   final error = ToolError.invalidInput('paramName', suggestion: 'Provide a valid value.');
   return [ChatContent.text(error.toMessage())];
   ```

3. **For custom errors, use the constructor:**
   ```dart
   final error = ToolError(
     code: 'custom_code',
     description: 'Detailed explanation here',
     suggestion: 'How to recover from this',
   );
   ```

## Testing Recommendations

1. **Error Message Format**
   ```dart
   expect(error.toMessage(), contains('[TOOL_ERROR]'));
   expect(error.toMessage(), contains(error.code));
   expect(error.toMessage(), contains('Suggestion:'));
   ```

2. **Error Code Consistency**
   Ensure error codes match expected values for LLM pattern matching.

3. **Suggestion Quality**
   Verify suggestions are actionable and specific.

## Files Modified

- ✅ `lib/core/util/tool_func/type.dart` - Added `ToolError` class
- ✅ `lib/core/util/tool_func/func/contectsms.dart` - Standardized SMS errors
- ✅ `lib/core/util/tool_func/func/urlluancher.dart` - Standardized URL errors
- ✅ `lib/core/util/tool_func/func/terminal.dart` - Standardized terminal errors
- ✅ `lib/core/util/tool_func/func/filemanager.dart` - Standardized file operation errors
- ✅ `lib/core/util/tool_func/func/download.dart` - Standardized download errors

## Future Improvements

1. **Error Analytics**: Track which error codes appear most frequently
2. **Localization**: Translate error codes and suggestions to supported languages
3. **Recovery Hints**: Add code snippets or examples in suggestions
4. **Error Hierarchy**: Map error codes to HTTP status codes for API consistency
5. **Tool-Specific Codes**: Namespace error codes by tool (e.g., `sms_` prefix for SMS errors)

## Example LLM Self-Correction Flow

```
User: "Send a text to john"
LLM calls: TfSMSSender with contact="john", message=[needs context]
Tool returns: [TOOL_ERROR] invalid_input: Required parameter "message" is missing...

LLM sees [TOOL_ERROR] and knows to:
1. Extract error code: invalid_input
2. Read suggestion: "Provide message content"
3. Ask user: "What message do you want to send to john?"
4. Retry with complete parameters
```

This enables smooth, corrective interactions without requiring users to debug tool calls manually.
