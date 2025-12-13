import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:gpt_box/main.dart';

import 'package:path/path.dart' as p;

class GeminiOcrService {
  Future<String> processFiles({
    required List<PlatformFile> files,
    required String apiKey,
    required Function(int completed, int total) onProgress,
  }) async {
    final StringBuffer combinedText = StringBuffer();
    int completedCount = 0;

    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
    );

    for (final file in files) {
      try {
        final String fileExtension = p.extension(file.name).toLowerCase();
        final bytes = await _readFileBytes(file);

        String? mimeType;
        if (fileExtension == '.pdf') {
          mimeType = 'application/pdf';
        } else if (fileExtension == '.png') {
          mimeType = 'image/png';
        } else if (['.jpeg', '.jpg'].contains(fileExtension)) {
          mimeType = 'image/jpeg';
        } else {
          completedCount++;
          onProgress(completedCount, files.length);
          combinedText.writeln(
            '\n\n--- SKIPPED unsupported file: ${file.name} ---\n\n',
          );
          continue;
        }

        // Prepare the prompt and the data part for the API
        final prompt = TextPart(translatorConfig.geminiPrompt);
        final dataPart = DataPart(mimeType, bytes);

        // Send the request to the Gemini API
        final response = await model.generateContent([
          Content.multi([prompt, dataPart]),
        ]);

        // Append the extracted text to the buffer
        if (response.text != null && response.text!.isNotEmpty) {
          combinedText.writeln(response.text);
        } else {
          combinedText.writeln(
            '\n\n--- No text found in file: ${file.name} ---\n\n',
          );
        }
        //  combinedText.writeln('\n\n--- End of File: ${file.name} ---\n\n');
      } catch (e) {
        // Append error message to the output to not lose progress
        combinedText.writeln(
          '\n\n--- ERROR processing file ${file.name}: $e ---\n\n',
        );
      } finally {
        completedCount++;
        onProgress(completedCount, files.length);
      }
    }
    return combinedText.toString();
  }

  /// Helper function to read file bytes regardless of the platform or source.
  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }
    if (file.path != null) {
      return await File(file.path!).readAsBytes();
    }
    if (file.readStream != null) {
      final builder = BytesBuilder();
      await for (final chunk in file.readStream!) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
    throw Exception('Could not read file data for ${file.name}');
  }
}
