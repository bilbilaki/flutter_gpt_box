import 'package:flutter/material.dart';

class TopicDetailsInput extends StatefulWidget {
  final List<String> keywords;
  final ValueChanged<List<String>> onKeywordsChanged;

  const TopicDetailsInput({
    super.key,
    required this.keywords,
    required this.onKeywordsChanged,
  });

  @override
  State<TopicDetailsInput> createState() => _TopicDetailsInputState();
}

class _TopicDetailsInputState extends State<TopicDetailsInput> {
  final TextEditingController _keywordController = TextEditingController();

  void _addKeyword() {
    final String keyword = _keywordController.text.trim();
    if (keyword.isNotEmpty && !widget.keywords.contains(keyword)) {
      final List<String> updatedKeywords = List.from(widget.keywords)
        ..add(keyword);
      widget.onKeywordsChanged(updatedKeywords);
      _keywordController.clear();
    }
  }

  void _removeKeyword(String keyword) {
    final List<String> updatedKeywords = List.from(widget.keywords)
      ..remove(keyword);
    widget.onKeywordsChanged(updatedKeywords);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _keywordController,
          decoration: InputDecoration(
            hintText: 'Add a keyword (e.g., "Flutter UI")',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add, color: Colors.blueAccent),
              onPressed: _addKeyword,
            ),
          ),
          onSubmitted: (_) => _addKeyword(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: widget.keywords.map((keyword) {
            return Chip(
              label: Text(keyword),
              onDeleted: () => _removeKeyword(keyword),
              deleteIcon: const Icon(Icons.close, size: 18),
            );
          }).toList(),
        ),
      ],
    );
  }
}
