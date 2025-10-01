import 'package:flutter/material.dart';

import 'package:gpt_box/view/prompt_generator/models/prompt_settings.dart';
import 'package:gpt_box/view/prompt_generator/services/prompt_builder.dart'; // For extension

class TargetSelector extends StatefulWidget {
  final List<PromptTargetPreset> selectedPresets;
  final String customTarget;
  final ValueChanged<List<PromptTargetPreset>> onPresetChanged;
  final ValueChanged<String> onCustomTargetChanged;

  const TargetSelector({
    super.key,
    required this.selectedPresets,
    required this.customTarget,
    required this.onPresetChanged,
    required this.onCustomTargetChanged,
  });

  @override
  State<TargetSelector> createState() => _TargetSelectorState();
}

class _TargetSelectorState extends State<TargetSelector> {
  late TextEditingController _customTargetController;

  @override
  void initState() {
    super.initState();
    _customTargetController = TextEditingController(text: widget.customTarget);
  }

  @override
  void didUpdateWidget(covariant TargetSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customTarget != widget.customTarget) {
      _customTargetController.text = widget.customTarget;
    }
  }

  @override
  void dispose() {
    _customTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Target:', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _customTargetController,
          onChanged: widget.onCustomTargetChanged,
          decoration: const InputDecoration(
            hintText: 'e.g., Enabling Personalized Content Delivery...',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Text('Preset Targets:', style: Theme.of(context).textTheme.bodyMedium),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: PromptTargetPreset.values.map((preset) {
            final isSelected = widget.selectedPresets.contains(preset);
            return FilterChip(
              label: Text(preset.description),
              selected: isSelected,
              onSelected: (selected) {
                final List<PromptTargetPreset> updatedPresets = List.from(
                  widget.selectedPresets,
                );
                if (selected) {
                  updatedPresets.add(preset);
                } else {
                  updatedPresets.remove(preset);
                }
                widget.onPresetChanged(updatedPresets);
              },
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.3),
              checkmarkColor: Theme.of(context).colorScheme.onPrimary,
            );
          }).toList(),
        ),
      ],
    );
  }
}
