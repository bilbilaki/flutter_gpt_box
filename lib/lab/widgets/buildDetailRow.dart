part of '../main.dart';

Widget buildDetailRow(
  BuildContext context,
  String label,
  String value, {
  bool isCopyToClipboard = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120, // Align labels
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(
          child: Row(
            children: [
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
              if (isCopyToClipboard)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
                  onPressed: () {
                    // Simple function: Copy text to clipboard
                    print('Copied "$value" to clipboard');
                    // Clipboard.setData(ClipboardData(text: value)); // Requires flutter/services
                  },
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
