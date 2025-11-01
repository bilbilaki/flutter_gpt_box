import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

Future<Map<String, dynamic>?> showBrowserConfigDialog(BuildContext context) async {
  final browserUrlController = TextEditingController();
  final browserWsEndpointController = TextEditingController();
  String? selectedViewport;

  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Configure Browser Connection'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: browserUrlController,
              decoration: const InputDecoration(
                labelText: 'Browser URL',
                hintText: 'http://localhost:9222',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: browserWsEndpointController,
              decoration: const InputDecoration(
                labelText: 'Browser WS Endpoint',
                hintText: 'ws://localhost:9222/devtools/browser/...',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select Default Viewport'),
              value: selectedViewport,
              items: const [
                DropdownMenuItem(
                  value: 'notSpecified',
                  child: Text('Not Specified'),
                ),
                DropdownMenuItem(
                  value: 'notOverride',
                  child: Text('Not Override'),
                ),
              ],
              onChanged: (value) {
                selectedViewport = value;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (browserUrlController.text.isEmpty ||
                browserWsEndpointController.text.isEmpty ||
                selectedViewport == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }
            
            Navigator.pop(context, {
              'browserUrl': browserUrlController.text,
              'browserWsEndpoint': browserWsEndpointController.text,
              'defaultViewport': selectedViewport,
            });
          },
          child: const Text('Connect'),
        ),
      ],
    ),
  );
}

Future<String?> selectDirectory() async {
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
  return selectedDirectory;
}
