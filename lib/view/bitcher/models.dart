import 'package:flutter/material.dart';

class AIRequestObject {
  final int objectNumber;
  String content;
  String? aiResponse;
  bool isProcessing;
  bool isCompleted;
  final TextEditingController contentController;

  AIRequestObject({
    required this.objectNumber,
    required this.content,
    this.aiResponse,
    this.isProcessing = false,
    this.isCompleted = false,
  }) : contentController = TextEditingController(text: content);

  void updateContent(String newContent) {
    content = newContent;
    contentController.text = newContent; // Update controller text
    isCompleted = false; // Reset status if content changes
    isProcessing = false;
    aiResponse = null;
  }

  void setResponse(String response) {
    aiResponse = response;
    isCompleted = true;
    isProcessing = false;
  }

  void setProcessing(bool processing) {
    isProcessing = processing;
    if (processing) {
      isCompleted = false;
      aiResponse = null; // Clear previous response when starting new process
    }
  }

  void dispose() {
    contentController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'objectNumber': objectNumber,
      'content': content,
      'aiResponse': aiResponse,
      'isCompleted': isCompleted,
    };
  }

  factory AIRequestObject.fromJson(Map<String, dynamic> json) {
    return AIRequestObject(
      objectNumber: json['objectNumber'],
      content: json['content'],
      aiResponse: json['aiResponse'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class BatchRequestResult {
  final List<AIRequestObject> processedObjects;
  final String collectiveResponse;
  final DateTime timestamp;

  BatchRequestResult({
    required this.processedObjects,
    required this.collectiveResponse,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'processedObjects': processedObjects.map((obj) => obj.toJson()).toList(),
      'collectiveResponse': collectiveResponse,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
