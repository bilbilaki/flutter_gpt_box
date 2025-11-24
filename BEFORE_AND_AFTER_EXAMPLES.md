# Before & After: Error Message Examples

## SMS Sender (contectsms.dart)

### Scenario 1: Missing Contact Parameter

**Before:**
```
failed to sending sms message: invalid contact or message
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "contact" is missing or empty. Suggestion: Provide both a contact name and message content.
```

**LLM Benefit:** Clearly identifies the missing parameter and what to do.

---

### Scenario 2: Contact Not Found

**Before:**
```
failed to sending sms message. couldn't find a phone number for the provided contact

(verbose confusing message that tells to recheck and adjust case sensitivity)
```

**After:**
```
[TOOL_ERROR] not_found: Contact "john" not found. Suggestion: Verify spelling/case or provide an exact phone number. Try a slight variation (e.g., "John" vs "john").
```

**LLM Benefit:** Actionable suggestions for retry with exact examples.

---

### Scenario 3: Permission Denied

**Before:**
```
failed to sending sms message. SMS permission is denied
```

**After:**
```
[TOOL_ERROR] permission_denied: Permission denied for "SMS sending". Suggestion: Request SMS permission in system settings and retry.
```

**LLM Benefit:** Tells LLM exactly what the user needs to do.

---

### Scenario 4: SMS Send Fails

**Before:**
```
failed to sending sms message; may be an issue with the phone, provider, or SIM balance
```

**After:**
```
[TOOL_ERROR] execution_failed: SMS sending failed during transmission: Permission denied. Suggestion: Verify SIM status, network connection, and provider support.
```

**LLM Benefit:** Specific recovery checklist for debugging.

---

## URL Launcher (urlluancher.dart)

### Scenario 1: Missing URL Parameter

**Before:**
```
failed to open url for user
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "url" is missing or empty. Suggestion: Provide a valid URL (e.g., "https://example.com").
```

**LLM Benefit:** Clear example of expected input format.

---

### Scenario 2: URL Launch Fails

**Before:**
```
failed to open url for user
```

**After:**
```
[TOOL_ERROR] execution_failed: Failed to open URL. Suggestion: Verify the URL is valid and a compatible app is available.
```

**LLM Benefit:** Distinguishes between invalid format and unavailable handler.

---

## Terminal (terminal.dart)

### Scenario 1: Missing Command Parameter

**Before:**
```
Error: 'command' is required.
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "command" is missing or empty. Suggestion: Provide a valid shell command (e.g., "ls -la", "cat file.txt").
```

**LLM Benefit:** Examples of valid commands provided.

---

### Scenario 2: Command Execution Fails (Non-zero Exit Code)

**Before:**
```
[Exit code: 1]
```

**After:**
```
[TOOL_ERROR] execution_failed: Command exited with code 1. Suggestion: Review the error output above and adjust the command if needed.
```

**LLM Benefit:** Structured error with direction to review output.

---

### Scenario 3: Command Exception

**Before:**
```
Error executing command: /bin/sh: apt-get: not found
```

**After:**
```
[TOOL_ERROR] execution_failed: Command execution failed: /bin/sh: apt-get: not found. Suggestion: Verify the command syntax and ensure all required tools are installed.
```

**LLM Benefit:** Clear distinction between tool availability and command syntax.

---

## File Manager (filemanager.dart)

### Scenario 1: Missing Action Parameter

**Before:**
```
{"error": "'action' is a required parameter for fileManager."}
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "action" is missing or empty. Suggestion: Provide one of: list, tree, read, create, delete, search, copy, move.
```

**LLM Benefit:** Immediate feedback on valid options.

---

### Scenario 2: Invalid Action Value

**Before:**
```
{"error": "'action' must be one of: list, tree, read, create, delete, search, copy, move."}
```

**After:**
```
[TOOL_ERROR] invalid_argument: Invalid "action": "remove" is not supported. Suggestion: Use one of: list, tree, read, create, delete, search, copy, move.
```

**LLM Benefit:** Shows the wrong value, correct options, and pattern.

---

### Scenario 3: Path Not Found

**Before:**
```
{"error": "Directory not found or inaccessible."}
```

**After:**
```
[TOOL_ERROR] not_found: Directory "/home/user/missing_dir" not found. Suggestion: Verify the path exists and is accessible.
```

**LLM Benefit:** Exact path included for debugging.

---

### Scenario 4: File Creation Missing Parameters

**Before:**
```
{"error": "'path' and 'content' are required for the 'create' action."}
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "content" is missing or empty. Suggestion: Provide both a file path and content string.
```

**LLM Benefit:** Identifies which parameter is missing, not both at once.

---

## Download Manager (download.dart)

### Scenario 1: Conflicting Actions

**Before:**
```
Error: Specify only one action (checkStatus or cancelTask).
```

**After:**
```
[TOOL_ERROR] invalid_argument: Both checkStatus and cancelTask are true. Suggestion: Specify only one action per call: either checkStatus or cancelTask.
```

**LLM Benefit:** Explains the conflict and how to resolve it.

---

### Scenario 2: Task Not Found

**Before:**
```
No download task found with ID: abc123
```

**After:**
```
[TOOL_ERROR] not_found: Download task with ID "abc123" not found. Suggestion: Verify the taskId from a previous download call or check active/completed tasks.
```

**LLM Benefit:** Directs user to valid sources for taskId.

---

### Scenario 3: Empty Task List

**Before:**
```
There are no active or recent download tasks.
```

**After:**
```
[TOOL_ERROR] not_found: Active or recent download tasks not found. Suggestion: Start a download first using the downloader tool with a URL.
```

**LLM Benefit:** Clear call-to-action for next step.

---

### Scenario 4: Invalid Task ID for Cancellation

**Before:**
```
Error: A "taskId" is required to cancel a task.
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "taskId" is missing or empty. Suggestion: Provide a valid taskId from a previous download operation.
```

**LLM Benefit:** References where to find valid taskId.

---

### Scenario 5: Cancellation Failed

**Before:**
```
Failed to cancel task: abc123. It may not exist or may have already completed.
```

**After:**
```
[TOOL_ERROR] execution_failed: Failed to cancel task. Suggestion: The task may not exist or may have already completed. Verify the taskId.
```

**LLM Benefit:** Actionable checklist for debugging.

---

### Scenario 6: APK Not Android Platform

**Before:**
```
APK installation is only supported on Android devices.
```

**After:**
```
[TOOL_ERROR] execution_failed: APK installation not supported on this platform. Suggestion: APK installation is only available on Android devices.
```

**LLM Benefit:** Clear that this is a platform limitation, not user error.

---

### Scenario 7: Invalid APK Path

**Before:**
```
Error: APK file not found at path: /sdcard/missing.apk
```

**After:**
```
[TOOL_ERROR] not_found: APK file at "/sdcard/missing.apk" not found. Suggestion: Verify the file path is correct and the APK file exists.
```

**LLM Benefit:** Clear distinction between missing file and missing parameter.

---

### Scenario 8: APK Installation Fails

**Before:**
```
APK installation error: No status returned. Check logs or try manually.
```

**After:**
```
[TOOL_ERROR] execution_failed: APK installation returned no status. Suggestion: Check device logs or try manual installation.
```

**LLM Benefit:** Clear next steps for user troubleshooting.

---

## Key Improvements Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Format** | Varied, natural language | Consistent `[TOOL_ERROR] code: msg. Suggestion: hint` |
| **Machine Parsing** | Difficult/impossible | Easy via regex on error code |
| **Actionability** | Generic "check X" | Specific "do Y to recover" |
| **Parameter Context** | Sometimes missing | Always included |
| **Recovery Hints** | Vague | Concrete and specific |
| **LLM Self-Correction** | Difficult | Enabled by design |

---

## How LLM Uses These Improvements

### Example Interaction 1: Missing Contact

```
User: "Send SMS to john"

LLM: Calls TfSMSSender(contact="john", message=None)

Tool: [TOOL_ERROR] invalid_input: Required parameter "message" is missing. Suggestion: Provide message content.

LLM parses error:
- Code: "invalid_input"
- Missing param: "message"
- Next action: Ask user

LLM: "What message would you like to send to john?"

User: "I'm on my way"

LLM: Calls TfSMSSender(contact="john", message="I'm on my way")

Tool: "Successfully sent SMS to john."

✅ Success with automatic recovery!
```

### Example Interaction 2: Typo in Contact

```
User: "Send SMS to jon"

LLM: Calls TfSMSSender(contact="jon", message="Hello")

Tool: [TOOL_ERROR] not_found: Contact "jon" not found. Suggestion: Try spelling variations like "John" or verify the exact contact name.

LLM parses error:
- Code: "not_found"
- Missing item: Contact "jon"
- Hint: Try variations

LLM: "I couldn't find a contact named 'jon'. Did you mean 'John'? Or could you provide the exact contact name?"

User: "Yes, it's John"

LLM: Calls TfSMSSender(contact="John", message="Hello")

Tool: "Successfully sent SMS to John."

✅ User corrected with LLM guidance!
```

This is the power of standardized error patterns for LLM self-correction.
