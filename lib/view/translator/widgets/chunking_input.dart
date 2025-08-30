part of '../interfaces/chunker_translator.dart';

Widget _buildChunkingInputs() {
    return Column(
      children: [
        if (selectedChunkingMethod == ChunkingMethod.lines)
          TextField(
            controller: linesPerChunkController,
            decoration: const InputDecoration(
              labelText: 'Lines per chunk',
              prefixIcon: Icon(Icons.wrap_text),
            ),
            keyboardType: TextInputType.number,
          )
        else if (selectedChunkingMethod == ChunkingMethod.words)
          TextField(
            controller: wordsPerChunkController,
            decoration: const InputDecoration(
              labelText: 'Words per chunk',
              prefixIcon: Icon(Icons.format_list_bulleted),
            ),
            keyboardType: TextInputType.number,
          )
        else if (selectedChunkingMethod == ChunkingMethod.characters)
          TextField(
            controller: charactersPerChunkController,
            decoration: const InputDecoration(
              labelText: 'Characters per chunk',
              prefixIcon: Icon(Icons.text_increase),
            ),
            keyboardType: TextInputType.number,
          )
        else
          TextField(
            controller: regexPatternController,
            decoration: const InputDecoration(
              labelText: 'Regex Pattern',
              prefixIcon: Icon(Icons.functions),
            ),
          ),
        const SizedBox(height: 8),
        if (selectedChunkingMethod != ChunkingMethod.regex)
          TextField(
            controller: overlapController,
            decoration: InputDecoration(
              labelText: 'Overlap (${selectedChunkingMethod.name})',
              prefixIcon: const Icon(Icons.flip),
            ),
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

