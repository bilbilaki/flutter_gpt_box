import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isRunning;

  const ActionButton({
    Key? key,
    required this.onPressed,
    required this.isRunning,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isRunning ? null : onPressed,
      icon: isRunning
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.play_arrow),
      label: Text(isRunning ? 'Processing...' : 'Generate PDFs'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.green,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }
}
