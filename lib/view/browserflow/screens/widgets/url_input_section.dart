import 'package:flutter/material.dart';

class URLInputSection extends StatelessWidget {
  final TextEditingController urlController;
  final VoidCallback onAddSingle;
  final VoidCallback onAddBatch;
  final bool isRunning;

  const URLInputSection({
    Key? key,
    required this.urlController,
    required this.onAddSingle,
    required this.onAddBatch,
    required this.isRunning,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add URLs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Single URL or paste multiple URLs (one per line)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              enabled: !isRunning,
              maxLines: null,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter URL (e.g., example.com or https://example.com)\nOr paste multiple URLs (one per line)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning ? null : onAddSingle,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Single'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: isRunning ? null : onAddBatch,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add Batch'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
