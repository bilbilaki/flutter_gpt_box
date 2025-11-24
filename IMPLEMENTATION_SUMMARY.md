# Tool Error Patterns Implementation - Summary

## Completed Tasks ✅

### 1. Created ToolError Class (`type.dart`)
- Standardized error class with `code`, `description`, and `suggestion` fields
- Factory constructors for common error patterns:
  - `invalidInput()` - Required parameters missing/empty
  - `notFound()` - Resource doesn't exist  
  - `permissionDenied()` - Access denied
  - `invalidArgument()` - Invalid parameter value
  - `executionFailed()` - Operation failed during execution
- Custom constructor for specialized errors
- `toMessage()` method formats errors as: `[TOOL_ERROR] code: description. Suggestion: hint`

### 2. Updated SMS Tool (`contectsms.dart` - TfSMSSender)
**Changes:**
- ✅ Fixed `findContactNumber()` to return empty string instead of error text
- ✅ Standardized SMS validation errors with `invalidInput()`
- ✅ Standardized permission errors with `permissionDenied()`
- ✅ Standardized contact lookup failures with `notFound()`
- ✅ Standardized execution failures with `executionFailed()`

**Before:**
```
"failed to sending sms message: invalid contact or message"
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "contact" is missing or empty. Suggestion: Provide both a contact name and message content.
```

### 3. Updated URL Launcher (`urlluancher.dart` - TfUrlLuancher)
**Changes:**
- ✅ Standardized URL validation with `invalidInput()`
- ✅ Added proper error handling for launch failures
- ✅ Removed dead code and malformed logic
- ✅ Execution errors now include recovery suggestions

**Before:**
```
"failed to open url for user"
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "url" is missing or empty. Suggestion: Provide a valid URL (e.g., "https://example.com").
```

### 4. Updated Terminal (`terminal.dart` - TfTerminal)
**Changes:**
- ✅ Standardized command validation with `invalidInput()`
- ✅ Non-zero exit codes now return structured error info
- ✅ Execution exceptions include actionable suggestions

**Before:**
```
Error executing command: Permission denied
```

**After:**
```
[TOOL_ERROR] execution_failed: Command execution failed: Permission denied. Suggestion: Verify the command syntax and ensure all required tools are installed.
```

### 5. Updated File Manager (`filemanager.dart` - TfFileManager)
**Changes:**
- ✅ Removed dead code (`return null;` after all branches)
- ✅ Standardized all 8 action cases with ToolError
- ✅ Removed JSON error objects in favor of structured errors
- ✅ Updated all validation errors for: list, tree, read, create, delete, copy, move, search

**Before:**
```
{"error": "'path' is required for the 'list' action."}
```

**After:**
```
[TOOL_ERROR] invalid_input: Required parameter "path" is missing or empty. Suggestion: Provide a directory path.
```

### 6. Updated Download Manager (`download.dart` - TfDownloader)
**Changes:**
- ✅ Standardized action validation conflicts with `invalidArgument()`
- ✅ Task not found errors use `notFound()` with recovery hints
- ✅ APK path validation uses `invalidInput()` and `notFound()`
- ✅ Platform check errors use `executionFailed()`
- ✅ Installation errors include device/permission suggestions
- ✅ Fallback error for invalid arguments
- ✅ All 7+ error cases now follow the pattern

**Before:**
```
Error: Specify only one action (checkStatus or cancelTask).
Failed to cancel task: $taskId. It may not exist or may have already completed.
```

**After:**
```
[TOOL_ERROR] invalid_argument: Both checkStatus and cancelTask are true. Suggestion: Specify only one action per call: either checkStatus or cancelTask.

[TOOL_ERROR] execution_failed: Failed to cancel task. Suggestion: The task may not exist or may have already completed. Verify the taskId.
```

## Error Pattern Consistency

All tools now follow the same error message format:

```
[TOOL_ERROR] error_code: description. Suggestion: actionable_hint
```

### Error Code Mapping

| Error Type | Code | Tools |
|------------|------|-------|
| Missing/Empty Required Params | `invalid_input` | All 6 tools |
| Resource Not Found | `not_found` | SMS, Download, FileManager |
| Permission Denied | `permission_denied` | SMS, Terminal (implied) |
| Invalid Parameter Value | `invalid_argument` | FileManager, Download, Terminal |
| Operation Execution Failure | `execution_failed` | All 6 tools |

## Benefits for LLM Self-Correction

1. **Parseable Format** - Error codes can be extracted via regex: `\[TOOL_ERROR\] (\w+):`
2. **Actionable Suggestions** - Each error includes specific recovery steps
3. **Consistent Across Tools** - LLM learns one pattern that works everywhere
4. **Context Preservation** - Failed parameter names included for better reprompting
5. **Machine-Readable** - Enables automated recovery without user intervention

## Documentation Created

1. **TOOL_ERROR_IMPROVEMENTS.md** - Comprehensive guide with:
   - Problem statement and solution overview
   - ToolError class details and usage
   - Implementation across all 6 tools (before/after examples)
   - Benefits for LLM self-correction
   - Migration guide for new tools
   - Testing recommendations
   - Future improvements

2. **TOOL_ERROR_QUICK_REFERENCE.md** - Developer quick reference with:
   - Basic usage patterns
   - Output format examples
   - Error codes table
   - Common implementation patterns
   - Best practices and anti-patterns
   - LLM integration details

## Code Quality

- ✅ Build succeeds: `dart run build_runner build` (92s, 11 outputs)
- ✅ No new compilation errors introduced
- ✅ Removed 1 instance of dead code
- ✅ Improved type safety with structured errors
- ✅ Better logging integration

## Files Modified (6)

1. `lib/core/util/tool_func/type.dart` - Added ToolError class (65 lines)
2. `lib/core/util/tool_func/func/contectsms.dart` - Updated SMS error handling
3. `lib/core/util/tool_func/func/urlluancher.dart` - Updated URL error handling
4. `lib/core/util/tool_func/func/terminal.dart` - Updated terminal error handling
5. `lib/core/util/tool_func/func/filemanager.dart` - Updated file operation error handling
6. `lib/core/util/tool_func/func/download.dart` - Updated download error handling

## Files Created (2)

1. `TOOL_ERROR_IMPROVEMENTS.md` - Full implementation guide
2. `TOOL_ERROR_QUICK_REFERENCE.md` - Developer quick reference

## Next Steps (Optional)

1. **Extend to Remaining Tools** - Apply same pattern to:
   - PDFTool (`pdftool.dart`)
   - HTTPReq (`http.dart`)
   - WebBuilder (`webbuilder.dart`)
   - ZipManager (`ziptool.dart`)
   - Memory (`memory.dart`)
   - History (`history.dart`)

2. **Error Analytics** - Track error codes in logs for debugging

3. **Localization** - Translate suggestions to supported languages

4. **LLM Training** - Use [TOOL_ERROR] prefix in system prompts to teach models recovery patterns

5. **Testing** - Add unit tests for error message format consistency

## Example LLM Recovery Flow

```
User: "Send text to john"
  ↓
LLM calls TfSMSSender(contact="john", message=null)
  ↓
Tool returns: [TOOL_ERROR] invalid_input: Required parameter "message" is missing...
  ↓
LLM parses error code: "invalid_input"
  ↓
LLM reads suggestion: "Provide message content"
  ↓
LLM asks user: "What message should I send to John?"
  ↓
User provides message
  ↓
LLM retries with complete parameters → Success ✅
```

This pattern enables smooth, corrective interactions without requiring users to debug tool calls manually.
