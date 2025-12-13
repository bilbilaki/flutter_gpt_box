import '../configuration/config.dart';

/// Service class responsible for text chunking operations.
class TextChunkerService {
  static List<String> chunkText({
    required String originalContent,
    required ChunkingMethod method,
    int linesPerChunk = 10,
    int wordsPerChunk = 100,
    int charactersPerChunk = 500,
    String regexPattern = r'\n\n+',
    int overlap = 0,
  }) {
    if (originalContent.isEmpty) return [];

    if (overlap < 0) {
      throw ArgumentError('Overlap must be a non-negative number.');
    }

    List<String> chunks = [];

    switch (method) {
      case ChunkingMethod.lines:
        if (linesPerChunk <= 0) {
          throw ArgumentError('Lines per chunk must be a positive number.');
        }
        if (overlap >= linesPerChunk) {
          throw ArgumentError('Overlap must be smaller than lines per chunk.');
        }

        final List<String> contentLines = originalContent.split('\n');
        int step = linesPerChunk - overlap;
        if (step <= 0) step = 1;

        for (int i = 0; i < contentLines.length; i += step) {
          int end = (i + linesPerChunk > contentLines.length)
              ? contentLines.length
              : i + linesPerChunk;
          chunks.add(contentLines.sublist(i, end).join('\n'));
          if (end == contentLines.length) break;
        }
        break;

      case ChunkingMethod.words:
        if (wordsPerChunk <= 0) {
          throw ArgumentError('Words per chunk must be a positive number.');
        }
        if (overlap >= wordsPerChunk) {
          throw ArgumentError('Overlap must be smaller than words per chunk.');
        }

        final List<String> contentWords = originalContent
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
        int step = wordsPerChunk - overlap;
        if (step <= 0) step = 1;

        for (int i = 0; i < contentWords.length; i += step) {
          int end = (i + wordsPerChunk > contentWords.length)
              ? contentWords.length
              : i + wordsPerChunk;
          chunks.add(contentWords.sublist(i, end).join(' '));
          if (end == contentWords.length) break;
        }
        break;

      case ChunkingMethod.characters:
        if (charactersPerChunk <= 0) {
          throw ArgumentError(
            'Characters per chunk must be a positive number.',
          );
        }
        if (overlap >= charactersPerChunk) {
          throw ArgumentError(
            'Overlap must be smaller than characters per chunk.',
          );
        }

        final String content = originalContent;
        int step = charactersPerChunk - overlap;
        if (step <= 0) step = 1;

        for (int i = 0; i < content.length; i += step) {
          int end = (i + charactersPerChunk > content.length)
              ? content.length
              : i + charactersPerChunk;
          chunks.add(content.substring(i, end));
          if (end == content.length) break;
        }
        break;

      case ChunkingMethod.regex:
        if (regexPattern.isEmpty) {
          throw ArgumentError('Regex pattern cannot be empty.');
        }
        final RegExp regExp = RegExp(regexPattern);
        chunks = originalContent
            .split(regExp)
            .where((s) => s.isNotEmpty)
            .toList();
        break;
    }

    if (chunks.isEmpty && originalContent.isNotEmpty) {
      chunks.add(originalContent);
    }
    return chunks;
  }
}
