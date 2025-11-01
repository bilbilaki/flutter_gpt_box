import 'package:flutter/material.dart';
import 'package:gpt_box/data/res/openai.dart';
import 'batch.dart';
import 'file.dart';
import 'service.dart';
import 'models.dart';
import 'package:flutter/services.dart'; // Import for Clipboard

class AIBatchProcessorScreen extends StatefulWidget {
  @override
  _AIBatchProcessorScreenState createState() => _AIBatchProcessorScreenState();
}

class _AIBatchProcessorScreenState extends State<AIBatchProcessorScreen> {
  final TextEditingController _initialMessageController =
      TextEditingController();
  final TextEditingController _objectCountController = TextEditingController(
    text: '1',
  );
  final TextEditingController _promptTemplateController =
      TextEditingController(); // New controller for prompt template
  final TextEditingController _templateNameController =
      TextEditingController(); // New controller for saving template name
  final TextEditingController _regexPatternController =
      TextEditingController(); // For custom regex
  final TextEditingController _regexReplacementController =
      TextEditingController(); // For custom regex replacement

  List<AIRequestObject> _objects = [];
  AIService? _aiService;
  BatchProcessor? _batchProcessor;
  bool _isProcessing = false;
  String _statusMessage = '';
  final ScrollController _objectsScrollController = ScrollController();
  String _outputPath = 'Default App Directory';

  List<String> _savedTemplateNames = [];
  String? _selectedTemplateName;

  @override
  void initState() {
    super.initState();
    _loadCurrentOutputPath();
    _loadSavedTemplates();
    _initializeAIService();
  }

  Future<void> _loadCurrentOutputPath() async {
    final path = await FileService.getCurrentOutputPath();
    setState(() {
      _outputPath = path;
    });
  }

  void _initializeAIService() {
    if (Cfg.current.key.isNotEmpty) {
      _aiService = AIService(Cfg.current.key);
      _batchProcessor = BatchProcessor(_aiService!);
      _updateStatus('AI Service initialized.');
    } else {
      _updateStatus('Please enter an API Key.');
    }
  }

  void _createObjects() {
    final count = int.tryParse(_objectCountController.text) ?? 1;
    if (count <= 0) return;

    setState(() {
      // Dispose old controllers before creating new objects
      for (var object in _objects) {
        object.dispose();
      }

      _objects = List.generate(
        count,
        (index) => AIRequestObject(
          objectNumber: index + 1,
          content: '', // Start with empty content
        ),
      );
      _statusMessage = 'Created $count empty objects';
    });
  }

  void _setInitialMessageForAll() {
    if (_initialMessageController.text.isEmpty) {
      _updateStatus('Please enter an initial message');
      return;
    }
    if (_objects.isEmpty) {
      _updateStatus('Please create objects first');
      return;
    }

    setState(() {
      for (var object in _objects) {
        object.updateContent(_initialMessageController.text);
      }
      _statusMessage = 'Set initial message for all ${_objects.length} objects';
    });
  }

  void _applyPromptTemplateToObjects() {
    if (_promptTemplateController.text.isEmpty) {
      _updateStatus('Please enter a prompt template.');
      return;
    }
    if (_objects.isEmpty) {
      _updateStatus('Please create objects first.');
      return;
    }

    final String template = _promptTemplateController.text;
    final String regexPattern = _regexPatternController.text;
    final String regexReplacement = _regexReplacementController.text;

    setState(() {
      for (var object in _objects) {
        String message = template.replaceAll(
          '\$INDEX',
          object.objectNumber.toString(),
        );

        if (regexPattern.isNotEmpty && regexReplacement.isNotEmpty) {
          try {
            final regex = RegExp(regexPattern);
            message = message.replaceAll(regex, regexReplacement);
          } catch (e) {
            _updateStatus('Invalid regex pattern: $e');
            return;
          }
        }
        object.updateContent(message);
      }
      _statusMessage =
          'Applied prompt template for all ${_objects.length} objects';
    });
  }

  Future<void> _processBatchRequests() async {
    if (_batchProcessor == null || _objects.isEmpty) {
      _updateStatus('Initialize service and create objects first.');
      return;
    }

    // Check if all objects have content
    final emptyObjects = _objects.where((obj) => obj.content.isEmpty).toList();
    if (emptyObjects.isNotEmpty) {
      _updateStatus(
        'Some objects are empty. Please add content to all objects.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing batch requests...';
    });

    try {
      final result = await _batchProcessor!.processBatchRequests(_objects);

      setState(() {
        _statusMessage =
            'Batch processing completed: ${result.processedObjects.length} objects processed';
        _objects = result.processedObjects;
      });

      // Save collective result
      await FileService.saveCollectiveResponse(
        'batch_result_${DateTime.now().millisecondsSinceEpoch}',
        _cleanAIResponse(
          result.collectiveResponse,
        ), // Clean collective response
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Batch processing error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickOutputDirectory() async {
    try {
      final String? selectedDirectory = await FileService.pickOutputDirectory();
      if (selectedDirectory != null) {
        setState(() {
          _outputPath = selectedDirectory;
        });
        _updateStatus('Output directory set to: $selectedDirectory');
      }
    } catch (e) {
      _updateStatus('Error selecting directory: $e');
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_promptTemplateController.text.isEmpty) {
      _updateStatus('Template content cannot be empty.');
      return;
    }
    if (_templateNameController.text.isEmpty) {
      _updateStatus('Please enter a name for the template.');
      return;
    }

    final String templateName = _templateNameController.text.trim();
    try {
      await FileService.saveTemplate(
        'template_$templateName.json',
        _promptTemplateController.text,
      );
      await _loadSavedTemplates(); // Reload the list of templates
      _updateStatus('Template "$templateName" saved.');
    } catch (e) {
      _updateStatus('Failed to save template: $e');
    }
  }

  Future<void> _loadSavedTemplates() async {
    try {
      final templates = await FileService.getSavedTemplates();
      setState(() {
        _savedTemplateNames = templates
            .map(
              (name) =>
                  name.replaceFirst('template_', '').replaceFirst('.json', ''),
            )
            .toList();
        _selectedTemplateName = null; // Reset selected template
      });
    } catch (e) {
      _updateStatus('Failed to load saved templates: $e');
    }
  }

  Future<void> _loadSelectedTemplate(String? name) async {
    if (name == null) {
      _promptTemplateController.clear();
      _templateNameController.clear();
      _selectedTemplateName = null;
      return;
    }
    try {
      final content = await FileService.loadTemplate('template_$name.json');
      if (content != null) {
        setState(() {
          _promptTemplateController.text = content;
          _templateNameController.text = name;
          _selectedTemplateName = name;
        });
        _updateStatus('Template "$name" loaded.');
      } else {
        _updateStatus('Template "$name" not found or empty.');
      }
    } catch (e) {
      _updateStatus('Failed to load template "$name": $e');
    }
  }

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  void _updateObjectContent(int index, String content) {
    if (index >= 0 && index < _objects.length) {
      setState(() {
        _objects[index].updateContent(content);
      });
    }
  }

  // Utility to clean AI responses
  String _cleanAIResponse(String response) {
    // Regex to remove the specific data:application/octet-stream pattern
    final regex = RegExp(
      r'\n{2,}data:application/octet-stream;base64,[A-Za-z0-9+/=]+\n{2,}',
    );
    String cleaned = response.replaceAll(
      regex,
      '\n\n',
    ); // Replace with just newlines to keep separation
    // Remove any remaining metadata if present
    cleaned = cleaned.replaceAll(
      RegExp(
        r'--- Selected Files Export ---.*?Export Date:.*?\n\n#+ File:.*?\n```dart.*?```\n\n',
        dotAll: true,
      ),
      '',
    );
    return cleaned.trim(); // Trim leading/trailing whitespace
  }

  Widget _buildObjectsSection() {
    final completedCount = _objects.where((obj) => obj.isCompleted).length;
    final totalCount = _objects.length;

    return Card(
      color: Colors.grey[850],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.green[400]),
                SizedBox(width: 8),
                Text(
                  'Objects ($totalCount)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                if (totalCount > 0)
                  Chip(
                    label: Text(
                      '$completedCount/$totalCount Completed',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    backgroundColor: Colors.green[800],
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (_objects.isEmpty)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Center(
                  child: Text(
                    'No objects created yet. Set object count and click "Create Objects".',
                    style: TextStyle(color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Container(
                height: 400, // Fixed height for scrollable list
                child: Scrollbar(
                  controller: _objectsScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _objectsScrollController,
                    itemCount: _objects.length,
                    itemBuilder: (context, index) {
                      final object = _objects[index];
                      return _buildObjectListItem(object, index);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectListItem(AIRequestObject object, int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: object.isCompleted
              ? Colors.green[600]!
              : object.isProcessing
              ? Colors.orange[600]!
              : Colors.blue[600]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Object Header
          Row(
            children: [
              // Object Number Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: object.isCompleted
                      ? Colors.green[600]
                      : object.isProcessing
                      ? Colors.orange[600]
                      : Colors.blue[600],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${object.objectNumber}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Status
              if (object.aiResponse != null) ...[
                Icon(Icons.check_circle, size: 18, color: Colors.green[400]),
                SizedBox(width: 6),
                Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else if (object.isProcessing) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orange[400]!,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'Processing...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Icon(Icons.edit, size: 18, color: Colors.blue[400]),
                SizedBox(width: 6),
                Text(
                  'Ready',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              Spacer(),
              if (object.content.isNotEmpty)
                Text(
                  '${object.content.length} chars',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),
          SizedBox(height: 12),
          // Content Editor
          TextField(
            controller: object.contentController,
            minLines: 3,
            maxLines: null,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Object ${object.objectNumber} Content',
              labelStyle: TextStyle(color: Colors.grey[400]),
              hintStyle: TextStyle(color: Colors.grey[500]),
              hintText: 'Enter content for this object...',
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
              ),
              contentPadding: EdgeInsets.all(16),
            ),
            onChanged: (value) {
              _updateObjectContent(index, value);
            },
          ),
          // Response Preview
          if (object.aiResponse != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[900]!,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[700]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy, size: 14, color: Colors.green[400]),
                      SizedBox(width: 6),
                      Text(
                        'AI Response:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[400],
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                        tooltip: 'Copy Response',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: object.aiResponse!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('AI response copied!'),
                              backgroundColor: Colors.grey[800],
                           //   contentTextStyle: TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    object.aiResponse!.length > 150
                        ? '${object.aiResponse!.substring(0, 150)}...'
                        : object.aiResponse!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Dark theme colors
    final Color primaryDark = Colors.grey[900]!;
    final Color secondaryDark = Colors.grey[850]!;
    final Color accentGreen = Colors.green[400]!;
    final Color accentBlue = Colors.blue[400]!;
    final Color accentPurple = Colors.purple[400]!;
    final Color textLight = Colors.white;
    final Color textSecondary = Colors.grey[400]!;

    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: Text('AI Batch Processor', style: TextStyle(color: textLight)),
        backgroundColor: Colors.grey[800],
        foregroundColor: textLight,
        elevation: 2,
        actions: [
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textLight),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // API Key Input
          Card(
            color: secondaryDark,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Object Management
          Card(
            color: secondaryDark,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Object Management',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textLight,
                    ),
                  ),
                  SizedBox(height: 12),
                  // Initial Message for All
                  TextField(
                    controller: _initialMessageController,
                    maxLines: null,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      labelText: 'Initial Message for All Objects',
                      labelStyle: TextStyle(color: textSecondary),
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      hintText: 'Enter message to set for all objects...',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: accentBlue, width: 2),
                      ),
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _objectCountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textLight),
                          decoration: InputDecoration(
                            labelText: 'Number of Objects',
                            labelStyle: TextStyle(color: textSecondary),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: accentBlue,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _createObjects,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Create Objects'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _setInitialMessageForAll,
                        icon: Icon(Icons.copy_all, color: textLight),
                        label: Text(
                          'Set Message to All',
                          style: TextStyle(color: textLight),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _processBatchRequests,
                        icon: Icon(Icons.play_arrow, color: textLight),
                        label: Text(
                          'Batch Process',
                          style: TextStyle(color: textLight),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Prompt Template Tools
          Card(
            color: secondaryDark,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt Template Tools',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textLight,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _promptTemplateController,
                    minLines: 3,
                    maxLines: null,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      labelText:
                          'Prompt Template (use \$INDEX for object number)',
                      labelStyle: TextStyle(color: textSecondary),
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      hintText:
                          'e.g., "Review this item \$INDEX: [item description]"',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: accentPurple, width: 2),
                      ),
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Regex fields
                  if (!isMobile)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _regexPatternController,
                            style: TextStyle(color: textLight),
                            decoration: InputDecoration(
                              labelText: 'Regex Pattern (optional)',
                              labelStyle: TextStyle(color: textSecondary),
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              hintText: 'e.g., r"\\d+"',
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[700]!,
                                ),
                              ),
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _regexReplacementController,
                            style: TextStyle(color: textLight),
                            decoration: InputDecoration(
                              labelText: 'Regex Replacement (optional)',
                              labelStyle: TextStyle(color: textSecondary),
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              hintText: 'e.g., "NUMBER"',
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[700]!,
                                ),
                              ),
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        TextField(
                          controller: _regexPatternController,
                          style: TextStyle(color: textLight),
                          decoration: InputDecoration(
                            labelText: 'Regex Pattern (optional)',
                            labelStyle: TextStyle(color: textSecondary),
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            hintText: 'e.g., r"\\d+"',
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _regexReplacementController,
                          style: TextStyle(color: textLight),
                          decoration: InputDecoration(
                            labelText: 'Regex Replacement (optional)',
                            labelStyle: TextStyle(color: textSecondary),
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            hintText: 'e.g., "NUMBER"',
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _applyPromptTemplateToObjects,
                        icon: Icon(Icons.send, color: textLight),
                        label: Text(
                          'Apply Prompt Template',
                          style: TextStyle(color: textLight),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPurple,
                          foregroundColor: textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Save Template Name Field (flexible width)
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: TextField(
                          controller: _templateNameController,
                          style: TextStyle(color: textLight),
                          decoration: InputDecoration(
                            labelText: 'Template Name',
                            labelStyle: TextStyle(color: textSecondary),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saveAsTemplate,
                        icon: Icon(Icons.save, color: textLight),
                        label: Text(
                          'Save Template',
                          style: TextStyle(color: textLight),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      // Load Template Dropdown
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTemplateName,
                          hint: Text(
                            'Load Template',
                            style: TextStyle(color: textSecondary),
                          ),
                          style: TextStyle(color: textLight),
                          dropdownColor: Colors.grey[800],
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: textSecondary,
                          ),
                          onChanged: (String? newValue) {
                            _loadSelectedTemplate(newValue);
                          },
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'Clear Selection',
                                style: TextStyle(color: textSecondary),
                              ),
                            ),
                            ..._savedTemplateNames
                                .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: TextStyle(color: textLight),
                                    ),
                                  );
                                })
                                .toList(),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadSavedTemplates,
                        icon: Icon(Icons.refresh, color: textSecondary),
                        tooltip: 'Refresh Templates',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Output Path Selection
          Card(
            color: secondaryDark,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Output Directory',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textLight,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.folder, color: accentPurple),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _outputPath,
                          style: TextStyle(fontSize: 14, color: textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _pickOutputDirectory,
                        icon: Icon(Icons.folder_open, color: textLight),
                        label: Text(
                          'Change',
                          style: TextStyle(color: textLight),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPurple,
                          foregroundColor: textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Status Message
          if (_statusMessage.isNotEmpty)
            Card(
              color: _statusMessage.contains('Error')
                  ? Colors.red[900]
                  : _statusMessage.contains('completed')
                  ? Colors.green[900]
                  : Colors.blue[900],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage.contains('Error')
                          ? Icons.error
                          : _statusMessage.contains('completed')
                          ? Icons.check_circle
                          : Icons.info,
                      color: _statusMessage.contains('Error')
                          ? Colors.red[400]
                          : _statusMessage.contains('completed')
                          ? accentGreen
                          : accentBlue,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: _statusMessage.contains('Error')
                              ? Colors.red[400]
                              : _statusMessage.contains('completed')
                              ? accentGreen
                              : accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 16),

          // Objects Section
          _buildObjectsSection(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var object in _objects) {
      object.dispose();
    }
    _initialMessageController.dispose();
    _objectCountController.dispose();
    _promptTemplateController.dispose();
    _templateNameController.dispose();
    _regexPatternController.dispose();
    _regexReplacementController.dispose();
    _objectsScrollController.dispose();
    super.dispose();
  }
}
