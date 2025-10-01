import 'package:flutter/material.dart';
import 'package:gpt_box/view/prompt_generator/models/prompt_settings.dart';

class PromptTemplatingSection extends StatefulWidget {
  final List<PromptTemplate> templates;
  final PromptTemplate? activeTemplate;
  final ValueChanged<PromptTemplate?> onTemplateSelected;
  final ValueChanged<PromptTemplate> onTemplateVariablesChanged;
  final ValueChanged<PromptTemplate> onSaveTemplate;
  final ValueChanged<String> onDeleteTemplate;

  const PromptTemplatingSection({
    super.key,
    required this.templates,
    this.activeTemplate,
    required this.onTemplateSelected,
    required this.onTemplateVariablesChanged,
    required this.onSaveTemplate,
    required this.onDeleteTemplate,
  });

  @override
  State<PromptTemplatingSection> createState() =>
      _PromptTemplatingSectionState();
}

class _PromptTemplatingSectionState extends State<PromptTemplatingSection> {
  late TextEditingController _templateNameController;
  late TextEditingController _templateStringController;
  PromptTemplate? _currentEditingTemplate;

  @override
  void initState() {
    super.initState();
    _resetEditingControllers(widget.activeTemplate);
  }

  @override
  void didUpdateWidget(covariant PromptTemplatingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTemplate?.id != oldWidget.activeTemplate?.id ||
        widget.activeTemplate?.templateString !=
            oldWidget.activeTemplate?.templateString) {
      _resetEditingControllers(widget.activeTemplate);
    }
  }

  void _resetEditingControllers(PromptTemplate? template) {
    _currentEditingTemplate = template;
    _templateNameController = TextEditingController(text: template?.name ?? '');
    _templateStringController = TextEditingController(
      text: template?.templateString ?? '',
    );
    if (_currentEditingTemplate != null) {
      for (var placeholder in _currentEditingTemplate!.getPlaceholders()) {
        if (!_currentEditingTemplate!.variables.containsKey(placeholder)) {
          _currentEditingTemplate!.variables[placeholder] =
              ''; // Initialize unset variables
        }
      }
    }
  }

  void _showTemplateManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage Templates'),
          content: SizedBox(
            width: double.maxFinite,
            child: widget.templates.isEmpty
                ? const Text('No templates saved yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.templates.length,
                    itemBuilder: (ctx, index) {
                      final template = widget.templates[index];
                      return ListTile(
                        title: Text(template.name),
                        subtitle: Text(
                          template.templateString,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            widget.onDeleteTemplate(template.id);
                            Navigator.of(
                              ctx,
                            ).pop(); // Close dialog after deletion
                          },
                        ),
                        onTap: () {
                          widget.onTemplateSelected(template);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _templateStringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Active Template: ${_currentEditingTemplate?.name ?? 'None'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => _showTemplateManagementDialog(context),
              child: const Text('Manage Templates'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _templateNameController,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'e.g., Code Generation Template',
          ),
          onChanged: (value) {
            if (_currentEditingTemplate != null) {
              _currentEditingTemplate!.name = value;
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _templateStringController,
          decoration: const InputDecoration(
            labelText: 'Template String',
            hintText:
                'e.g., username is \$USERNAME and you must say that \$HIWORD',
          ),
          maxLines: 5,
          onChanged: (value) {
            setState(() {
              if (_currentEditingTemplate != null) {
                _currentEditingTemplate!.templateString = value;
                // Re-evaluate placeholders if template string changes
                final newPlaceholders = _currentEditingTemplate!
                    .getPlaceholders();
                final currentVariables = Map<String, String>.from(
                  _currentEditingTemplate!.variables,
                );
                _currentEditingTemplate!.variables.clear();
                for (var ph in newPlaceholders) {
                  _currentEditingTemplate!.variables[ph] =
                      currentVariables[ph] ?? '';
                }
              } else {
                _currentEditingTemplate = PromptTemplate(
                  name: _templateNameController.text.isEmpty
                      ? 'New Template'
                      : _templateNameController.text,
                  templateString: value,
                );
              }
            });
          },
        ),
        const SizedBox(height: 12),
        if (_currentEditingTemplate != null &&
            _currentEditingTemplate!.getPlaceholders().isNotEmpty) ...[
          Text(
            'Template Variables:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ..._currentEditingTemplate!.getPlaceholders().map((placeholder) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: TextField(
                controller: TextEditingController(
                  text: _currentEditingTemplate!.variables[placeholder],
                ),
                onChanged: (value) {
                  _currentEditingTemplate!.variables[placeholder] = value;
                  widget.onTemplateVariablesChanged(_currentEditingTemplate!);
                },
                decoration: InputDecoration(
                  labelText: placeholder.substring(1), // Remove '$' prefix
                  hintText: 'Value for $placeholder',
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(
              _currentEditingTemplate?.id == null
                  ? 'Save New Template'
                  : 'Update Template',
            ),
            onPressed:
                _currentEditingTemplate == null ||
                    _templateStringController.text.isEmpty
                ? null
                : () {
                    // Ensure name is set if user just typed a template string
                    if (_currentEditingTemplate!.name.isEmpty) {
                      _currentEditingTemplate!.name =
                          'New Template (${DateTime.now().second})';
                    }
                    widget.onSaveTemplate(_currentEditingTemplate!);
                    // After saving, consider making it the active one if it wasn't
                    if (widget.activeTemplate?.id !=
                        _currentEditingTemplate!.id) {
                      widget.onTemplateSelected(_currentEditingTemplate!);
                    }
                  },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          ),
        ),
      ],
    );
  }
}
