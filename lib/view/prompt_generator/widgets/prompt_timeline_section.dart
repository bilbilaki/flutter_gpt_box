import 'package:flutter/material.dart';
import 'package:gpt_box/view/prompt_generator/models/prompt_settings.dart';

class PromptTimelineSection extends StatefulWidget {
  final List<SavedPrompt> savedPrompts;
  final String? selectedPromptId;
  final ValueChanged<SavedPrompt> onSelectPrompt;
  final ValueChanged<String> onDeletePrompt;
  final ValueChanged<String> onLastUsedTextChanged;

  const PromptTimelineSection({
    super.key,
    required this.savedPrompts,
    this.selectedPromptId,
    required this.onSelectPrompt,
    required this.onDeletePrompt,
    required this.onLastUsedTextChanged,
  });

  @override
  State<PromptTimelineSection> createState() => _PromptTimelineSectionState();
}

class _PromptTimelineSectionState extends State<PromptTimelineSection> {
  late TextEditingController _lastUsedPromptController;

  @override
  void initState() {
    super.initState();
    _lastUsedPromptController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant PromptTimelineSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPromptId != null) {
      final selected = widget.savedPrompts.firstWhere(
        (p) => p.id == widget.selectedPromptId,
        orElse: () => SavedPrompt(name: '', promptContent: ''),
      );
      if (_lastUsedPromptController.text != selected.promptContent) {
        _lastUsedPromptController.text = selected.promptContent;
      }
    } else if (widget.selectedPromptId == null &&
        _lastUsedPromptController.text.isNotEmpty) {
      // If no prompt is selected, but the text field has content, it's user-typed
      // We don't want to clear it unless the user explicitly clears it.
    }
  }

  @override
  void dispose() {
    _lastUsedPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last Used Prompt (or type by self):',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _lastUsedPromptController,
          onChanged: widget.onLastUsedTextChanged,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter a previous prompt to maintain context...',
          ),
        ),
        const SizedBox(height: 16),
        Text('Saved Prompts:', style: Theme.of(context).textTheme.bodyMedium),
        widget.savedPrompts.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'No saved prompts yet.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(fontStyle: FontStyle.italic),
                ),
              )
            : SizedBox(
                height: 150, // Fixed height for scrollable list
                child: ListView.builder(
                  itemCount: widget.savedPrompts.length,
                  itemBuilder: (context, index) {
                    final prompt = widget.savedPrompts[index];
                    final isSelected = widget.selectedPromptId == prompt.id;
                    return Card(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2)
                          : Theme.of(context).cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          prompt.name,
                          style: Theme.of(context).textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          prompt.promptContent,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => widget.onDeletePrompt(prompt.id),
                        ),
                        onTap: () {
                          widget.onSelectPrompt(prompt);
                        },
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}
