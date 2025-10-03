import 'dart:async'; // Import for Future.wait
import 'file.dart';
import 'service.dart';
import 'models.dart';
import 'app.dart'; // Import app.dart to access _cleanAIResponse

class BatchProcessor {
  final AIService _aiService;

  BatchProcessor(this._aiService);

  Future<BatchRequestResult> processBatchRequests(
    List<AIRequestObject> objects,
  ) async {
    final List<AIRequestObject> completedObjects = [];
    final List<String> collectiveResponses = [];

    // Set all objects to processing state
    for (var object in objects) {
      object.setProcessing(true);
    }

    // Create futures for all batch requests
    final futures = <Future<void>>[];

    for (final object in objects) {
      final future = _processSingleObject(object).then((response) {
        collectiveResponses.add(response);
      });
      futures.add(future);
    }

    // Wait for all requests to complete
    await Future.wait(futures);

    // Filter completed objects after all processing is done
    for (final object in objects) {
      if (object.isCompleted) {
        completedObjects.add(object);
      }
    }

    final cleanedCollectiveResponse = _cleanAIResponse(
      collectiveResponses.join('\n\n---\n\n'),
    );

    return BatchRequestResult(
      processedObjects: completedObjects,
      collectiveResponse: cleanedCollectiveResponse,
      timestamp: DateTime.now(),
    );
  }

  Future<String> _processSingleObject(AIRequestObject object) async {
    try {
      final response = await _aiService.sendBatchRequest(object.content);
      final cleanedResponse = _cleanAIResponse(
        response,
      ); // Clean individual response
      object.setResponse(cleanedResponse);

      // Save individual response
      await FileService.saveObjectResponse(object, cleanedResponse);

      return cleanedResponse;
    } catch (e) {
      object.setResponse('Error: $e');
      return 'Error processing object ${object.objectNumber}: $e';
    }
  }

  // Moved _cleanAIResponse from here to app.dart (or shared utility)
  // as it's a UI-level requirement for display and saving collective response.
  // For individual cleaning, I'll pass it from app.dart context or make it a global util.
  // For now, I'll make it available as a top-level function if imported.
  String _cleanAIResponse(String response) {
    // Regex to remove the specific data:application/octet-stream pattern
    final regex = RegExp(
      r'\n{2,}data:application/octet-stream;base64,[A-Za-z0-9+/=]+\n{2,}',
    );
    String cleaned = response.replaceAll(
      regex,
      '\n\n',
    ); // Replace with just newlines to keep separation
    // Remove any remaining metadata if present
    cleaned = cleaned.replaceAll(
      RegExp(
        r'--- Selected Files Export ---.*?Export Date:.*?\n\n#+ File:.*?\n```dart.*?```\n\n',
        dotAll: true,
      ),
      '',
    );
    return cleaned.trim(); // Trim leading/trailing whitespace
  }
}
