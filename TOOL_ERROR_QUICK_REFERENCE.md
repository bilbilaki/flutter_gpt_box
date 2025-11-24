# ToolError Quick Reference

## Basic Usage

```dart
// Import is automatic (part of tool.dart)

// 1. Invalid input (missing/empty required parameter)
final error = ToolError.invalidInput('paramName', suggestion: 'Describe what to provide.');
return [ChatContent.text(error.toMessage())];

// 2. Resource not found
final error = ToolError.notFound('Contact "John"', suggestion: 'Verify the name exists.');
return [ChatContent.text(error.toMessage())];

// 3. Permission denied
final error = ToolError.permissionDenied('SMS sending', suggestion: 'Grant permission in settings.');
return [ChatContent.text(error.toMessage())];

// 4. Invalid argument value
final error = ToolError.invalidArgument('action', 'Unknown value "xyz"', suggestion: 'Use one of: a, b, c.');
return [ChatContent.text(error.toMessage())];

// 5. Execution failed during operation
final error = ToolError.executionFailed('Network request failed', suggestion: 'Check connection and retry.');
return [ChatContent.text(error.toMessage())];

// 6. Custom error
final error = ToolError(
  code: 'custom_error_code',
  description: 'What happened',
  suggestion: 'How to recover',
);
return [ChatContent.text(error.toMessage())];
```

## Output Format

All `ToolError.toMessage()` calls produce:

```
[TOOL_ERROR] error_code: description. Suggestion: actionable_hint
```

### Examples

```
[TOOL_ERROR] invalid_input: Required parameter "contact" is missing or empty. Suggestion: Provide both a contact name and message content.

[TOOL_ERROR] not_found: Contact "John" not found. Suggestion: Verify spelling/case or try a variation like "john".

[TOOL_ERROR] permission_denied: Permission denied for "SMS sending". Suggestion: Grant the required permission in system settings and retry.

[TOOL_ERROR] invalid_argument: Invalid "action": "unknown" is not supported. Suggestion: Use one of: list, tree, read, create, delete, search, copy, move.

[TOOL_ERROR] execution_failed: SMS sending failed: Permission denied. Suggestion: Verify SIM status, network connection, and provider support.
```

## Error Codes

| Code | Factory | Use When |
|------|---------|----------|
| `invalid_input` | `.invalidInput()` | Required param is null/empty |
| `not_found` | `.notFound()` | Resource doesn't exist |
| `permission_denied` | `.permissionDenied()` | Permission not granted |
| `invalid_argument` | `.invalidArgument()` | Param value is invalid |
| `execution_failed` | `.executionFailed()` | Operation fails during execution |
| Custom | `ToolError()` | Custom error scenario |

## Common Patterns

### Pattern 1: Validate Required Parameter
```dart
final contact = args['contact'] as String?;
if (contact == null || contact.isEmpty) {
  final error = ToolError.invalidInput('contact', suggestion: 'Provide a contact name.');
  return [ChatContent.text(error.toMessage())];
}
```

### Pattern 2: Check Resource Exists
```dart
if (item == null) {
  final error = ToolError.notFound('Task with ID "$taskId"', suggestion: 'Verify the taskId.');
  return [ChatContent.text(error.toMessage())];
}
```

### Pattern 3: Handle Permission Errors
```dart
if (!hasPermission) {
  final error = ToolError.permissionDenied('SMS sending', suggestion: 'Grant permission in settings.');
  return [ChatContent.text(error.toMessage())];
}
```

### Pattern 4: Validate Parameter Value
```dart
if (!allowedActions.contains(action)) {
  final error = ToolError.invalidArgument(
    'action',
    '"$action" is not supported',
    suggestion: 'Use one of: ${allowedActions.join(", ")}.',
  );
  return [ChatContent.text(error.toMessage())];
}
```

### Pattern 5: Handle Execution Exception
```dart
try {
  // operation
} catch (e) {
  final error = ToolError.executionFailed(
    'Operation failed: $e',
    suggestion: 'Check the input and try again.',
  );
  return [ChatContent.text(error.toMessage())];
}
```

## Logging

Always log before returning error:
```dart
log('Tool error: Contact not found - $contact');
final error = ToolError.notFound('Contact "$contact"', ...);
return [ChatContent.text(error.toMessage())];
```

## Best Practices

✅ **DO:**
- Use specific parameter names in error messages
- Provide actionable suggestions users can follow
- Include relevant context (e.g., attempted value)
- Log errors for debugging

❌ **DON'T:**
- Use generic messages like "Error occurred"
- Mix [TOOL_ERROR] with other formats
- Omit the suggestion field when possible
- Return multiple error messages (use one per call)

## For LLM Integration

Error codes follow this pattern: `lowercase_with_underscores`

LLM should parse using regex:
```regex
\[TOOL_ERROR\] ([a-z_]+):
```

Suggestion text follows: `Suggestion: ` prefix for easy extraction.
