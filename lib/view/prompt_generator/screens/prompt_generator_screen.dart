import 'package:flutter/material.dart';
import 'package:gpt_box/view/prompt_generator/services/prompt_builder.dart';
import 'package:gpt_box/view/prompt_generator/widgets/format_type_selector.dart';
import 'package:gpt_box/view/prompt_generator/widgets/prompt_length_controller.dart';
import 'package:gpt_box/view/prompt_generator/widgets/prompt_templating_section.dart';
import 'package:gpt_box/view/prompt_generator/widgets/prompt_timeline_section.dart';
import 'package:gpt_box/view/prompt_generator/widgets/target_selector.dart';
import 'package:gpt_box/view/prompt_generator/widgets/topic_details_input.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:gpt_box/view/prompt_generator/models/prompt_settings.dart';


class PromptGeneratorScreen extends StatefulWidget {
  const PromptGeneratorScreen({super.key});

  @override
  State<PromptGeneratorScreen> createState() => _PromptGeneratorScreenState();
}

class _PromptGeneratorScreenState extends State<PromptGeneratorScreen> {
  final PromptSettings _settings = PromptSettings();
  String _generatedPrompt = '';
  String _aiResponse = '';
  final TextEditingController _openAiApiKeyController = TextEditingController();

  List<SavedPrompt> _savedPrompts = [];
  List<PromptTemplate> _savedTemplates = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPrompts();
    _loadSavedTemplates();
  }

  @override
  void dispose() {
    _openAiApiKeyController.dispose();
    super.dispose();
  }



  Future<void> _loadSavedPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? promptsJson = prefs.getString('saved_prompts');
    if (promptsJson != null) {
      final List<dynamic> jsonList = jsonDecode(promptsJson);
      setState(() {
        _savedPrompts = jsonList
            .map((json) => SavedPrompt.fromJson(json))
            .toList();
      });
    }
  }

  Future<void> _savePrompt(String promptContent) async {
    final String name =
        'Prompt ${DateTime.now().toIso8601String().substring(0, 16)}';
    final newPrompt = SavedPrompt(name: name, promptContent: promptContent);
    setState(() {
      _savedPrompts.add(newPrompt);
    });
    final prefs = await SharedPreferences.getInstance();
    final String promptsJson = jsonEncode(
      _savedPrompts.map((p) => p.toJson()).toList(),
    );
    await prefs.setString('saved_prompts', promptsJson);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Prompt "$name" saved!')));
  }

  Future<void> _loadSavedTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final String? templatesJson = prefs.getString('saved_templates');
    if (templatesJson != null) {
      final List<dynamic> jsonList = jsonDecode(templatesJson);
      setState(() {
        _savedTemplates = jsonList
            .map((json) => PromptTemplate.fromJson(json))
            .toList();
      });
    }
  }

  Future<void> _saveTemplate(PromptTemplate template) async {
    // Check if template with same ID already exists, update it, otherwise add new
    final int existingIndex = _savedTemplates.indexWhere(
      (t) => t.id == template.id,
    );
    setState(() {
      if (existingIndex != -1) {
        _savedTemplates[existingIndex] = template;
      } else {
        _savedTemplates.add(template);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    final String templatesJson = jsonEncode(
      _savedTemplates.map((t) => t.toJson()).toList(),
    );
    await prefs.setString('saved_templates', templatesJson);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "${template.name}" saved!')),
    );
  }

  Future<void> _deleteTemplate(String templateId) async {
    setState(() {
      _savedTemplates.removeWhere((t) => t.id == templateId);
      if (_settings.activeTemplate?.id == templateId) {
        _settings.activeTemplate = null; // Clear active template if deleted
      }
    });
    final prefs = await SharedPreferences.getInstance();
    final String templatesJson = jsonEncode(
      _savedTemplates.map((t) => t.toJson()).toList(),
    );
    await prefs.setString('saved_templates', templatesJson);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Template deleted!')));
  }

  void _generatePrompt() {
    final PromptBuilder builder = PromptBuilder(_settings);
    setState(() {
      _generatedPrompt = builder.buildPrompt();
      _aiResponse = ''; // Clear previous AI response
    });
  }

  Future<void> _sendPromptToAI() async {
    setState(() {
      _aiResponse = 'Sending prompt to AI...';
    });
    final PromptBuilder builder = PromptBuilder(
      _settings,
    );
    final String? response = await builder.sendPromptToAI();
    setState(() {
      _aiResponse = response??'failed to get response';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prompt Customization',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Format Type
            _buildCard(
              title: 'Format Type',
              child: FormatTypeSelector(
                selectedType: _settings.formatType,
                onChanged: (type) {
                  setState(() {
                    _settings.formatType = type;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Target of Generated Prompt for AI
            _buildCard(
              title: 'Target of Generated Prompt for AI',
              child: TargetSelector(
                selectedPresets: _settings.selectedTargetPresets,
                customTarget: _settings.customTarget,
                onPresetChanged: (presets) {
                  setState(() {
                    _settings.selectedTargetPresets = presets;
                  });
                },
                onCustomTargetChanged: (target) {
                  setState(() {
                    _settings.customTarget = target;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Prompt Timeline
            _buildCard(
              title: 'Prompt Timeline',
              child: PromptTimelineSection(
                savedPrompts: _savedPrompts,
                selectedPromptId: _settings.lastUsedPromptId,
                onSelectPrompt: (prompt) {
                  setState(() {
                    _settings.lastUsedPromptId = prompt.id;
                    _settings.lastUsedPromptText = prompt.promptContent;
                  });
                },
                onDeletePrompt: (promptId) {
                  setState(() {
                    _savedPrompts.removeWhere((p) => p.id == promptId);
                    if (_settings.lastUsedPromptId == promptId) {
                      _settings.lastUsedPromptId = null;
                      _settings.lastUsedPromptText = null;
                    }
                  });
                  // Also persist changes
                  SharedPreferences.getInstance().then((prefs) {
                    final String promptsJson = jsonEncode(
                      _savedPrompts.map((p) => p.toJson()).toList(),
                    );
                    prefs.setString('saved_prompts', promptsJson);
                  });
                },
                onLastUsedTextChanged: (text) {
                  setState(() {
                    _settings.lastUsedPromptText = text;
                    _settings.lastUsedPromptId =
                        null; // Clear selection if typing custom
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Prompt Templating
            _buildCard(
              title: 'Prompt Templating',
              child: PromptTemplatingSection(
                templates: _savedTemplates,
                activeTemplate: _settings.activeTemplate,
                onTemplateSelected: (template) {
                  setState(() {
                    _settings.activeTemplate = template;
                  });
                },
                onTemplateVariablesChanged: (updatedTemplate) {
                  setState(() {
                    // Update variables in the active template
                    _settings.activeTemplate = updatedTemplate;
                    // Also update in saved templates list if it exists
                    final int index = _savedTemplates.indexWhere(
                      (t) => t.id == updatedTemplate.id,
                    );
                    if (index != -1) {
                      _savedTemplates[index] = updatedTemplate;
                    }
                  });
                },
                onSaveTemplate: (template) => _saveTemplate(template),
                onDeleteTemplate: (id) => _deleteTemplate(id),
              ),
            ),
            const SizedBox(height: 16),

            // Length of Prompt
            _buildCard(
              title: 'Length of Prompt',
              child: PromptLengthController(
                maxLength: _settings.maxPromptLength,
                maxTokens: _settings.maxTokens,
                onMaxLengthChanged: (length) {
                  setState(() {
                    _settings.maxPromptLength = length;
                  });
                },
                onMaxTokensChanged: (tokens) {
                  setState(() {
                    _settings.maxTokens = tokens;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Topic Details
            _buildCard(
              title: 'Topic Details',
              child: TopicDetailsInput(
                keywords: _settings.topicKeywords,
                onKeywordsChanged: (keywords) {
                  setState(() {
                    _settings.topicKeywords = keywords;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // Generate Prompt Button
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('GENERATE PROMPT'),
              onPressed: _generatePrompt,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 24),

            // Generated Prompt Display
            if (_generatedPrompt.isNotEmpty) ...[
              Text(
                'Generated Prompt:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: SelectableText(
                  _generatedPrompt,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Prompt'),
                    onPressed: () => _savePrompt(_generatedPrompt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send to AI'),
                    onPressed: _sendPromptToAI,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // AI Response Display
            if (_aiResponse.isNotEmpty) ...[
              Text(
                'AI Response:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.lightGreen),
                ),
                child: SelectableText(
                  _aiResponse,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(color: Colors.white),
            ),
            const Divider(height: 24, color: Colors.white38),
            child,
          ],
        ),
      ),
    );
  }

}