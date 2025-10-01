import 'package:flutter/material.dart';
import 'package:gpt_box/view/prompt_generator/models/prompt_settings.dart';
import 'package:gpt_box/view/prompt_generator/services/prompt_builder.dart';
class FormatTypeSelector extends StatelessWidget {
  final PromptFormatType selectedType;
  final ValueChanged<PromptFormatType> onChanged;

  const FormatTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: PromptFormatType.values.map((type) {
        return RadioListTile<PromptFormatType>(
          title: Text(type.description),
          value: type,
          groupValue: selectedType,
          onChanged: (value) => onChanged(value!),
          activeColor: Theme.of(context).colorScheme.primary,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }
}
