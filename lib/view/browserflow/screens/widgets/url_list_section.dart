import 'package:flutter/material.dart';

class URLListSection extends StatelessWidget {
  final List<String> urls;
  final VoidCallback onClearAll;
  final Function(int) onRemoveUrl;
  final bool isRunning;

  const URLListSection({
    Key? key,
    required this.urls,
    required this.onClearAll,
    required this.onRemoveUrl,
    required this.isRunning,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'URLs to Process',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: isRunning ? null : onClearAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(urls[index]),
                  trailing: IconButton(
                    onPressed: isRunning ? null : () => onRemoveUrl(index),
                    icon: const Icon(Icons.delete),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
