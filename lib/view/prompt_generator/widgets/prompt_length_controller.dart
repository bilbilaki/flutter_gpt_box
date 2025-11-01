import 'package:flutter/material.dart';

class PromptLengthController extends StatefulWidget {
  final int? maxLength;
  final int? maxTokens;
  final ValueChanged<int?> onMaxLengthChanged;
  final ValueChanged<int?> onMaxTokensChanged;

  const PromptLengthController({
    super.key,
    this.maxLength,
    this.maxTokens,
    required this.onMaxLengthChanged,
    required this.onMaxTokensChanged,
  });

  @override
  State<PromptLengthController> createState() => _PromptLengthControllerState();
}

class _PromptLengthControllerState extends State<PromptLengthController> {
  late TextEditingController _maxLengthController;
  late TextEditingController _maxTokensController;

  @override
  void initState() {
    super.initState();
    _maxLengthController = TextEditingController(
      text: widget.maxLength?.toString() ?? '',
    );
    _maxTokensController = TextEditingController(
      text: widget.maxTokens?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant PromptLengthController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxLength != widget.maxLength) {
      _maxLengthController.text = widget.maxLength?.toString() ?? '';
    }
    if (oldWidget.maxTokens != widget.maxTokens) {
      _maxTokensController.text = widget.maxTokens?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _maxLengthController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum Prompt Length (characters):',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _maxLengthController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g., 500',
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _maxLengthController.clear();
                widget.onMaxLengthChanged(null);
              },
            ),
          ),
          onChanged: (value) {
            widget.onMaxLengthChanged(int.tryParse(value));
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Maximum Tokens for AI Response:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _maxTokensController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g., 150',
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _maxTokensController.clear();
                widget.onMaxTokensChanged(null);
              },
            ),
          ),
          onChanged: (value) {
            widget.onMaxTokensChanged(int.tryParse(value));
          },
        ),
      ],
    );
  }
}
