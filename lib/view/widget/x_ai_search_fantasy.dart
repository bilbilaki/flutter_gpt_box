import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gpt_box/data/res/openai.dart';

class XAiSearchFantasy extends StatefulWidget {
  const XAiSearchFantasy({super.key});

  @override
  State<XAiSearchFantasy> createState() => _XAiSearchFantasyState();
}

class _XAiSearchFantasyState extends State<XAiSearchFantasy> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  String _loading = '';
  List<String> _citations = [];
  bool _isLoading = false;
  String _error = '';

  String _selectedSearchTool = 'web_search';
  bool _enableImageUnderstanding = false;
  bool _enableVideoUnderstanding = false;
  final TextEditingController _allowedDomainsController =
      TextEditingController();
  final TextEditingController _excludedDomainsController =
      TextEditingController();
  final TextEditingController _allowedHandlesController =
      TextEditingController();
  final TextEditingController _excludedHandlesController =
      TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // FBI/Fantasy Theme Colors
  static const Color _primaryColor = Color(0xFF58A6FF); // FBI Blue
  static const Color _accentColor = Color(0xFFF85149); // Alert Red
  static const Color _backgroundColor = Color(0xFF0D1117); // Dark Background
  static const Color _cardColor = Color(0xFF21262D); // Card Dark
  static const Color _textColor = Colors.white;

  Future<void> _performSearch(String query) async {
    if (Cfg.current.key.isEmpty) {
      setState(() {
        _error = 'API key is required. Please configure in settings.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loading =
          'Initiating Agentic Search with ${_selectedSearchTool == 'web_search' ? 'Web Search' : 'X Search'}...';
      _error = '';
      _result = '';
      _citations = [];
    });

    final url = Uri.parse('https://api.x.ai/v1/responses');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Cfg.current.key}',
    };

    // Build tool configuration
    final Map<String, dynamic> toolConfig = {'type': _selectedSearchTool};

    if (_selectedSearchTool == 'web_search') {
      // Web search parameters
      if (_allowedDomainsController.text.isNotEmpty) {
        toolConfig['allowed_domains'] = _allowedDomainsController.text
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();
      }
      if (_excludedDomainsController.text.isNotEmpty) {
        toolConfig['excluded_domains'] = _excludedDomainsController.text
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();
      }
      if (_enableImageUnderstanding) {
        toolConfig['enable_image_understanding'] = true;
      }
    } else if (_selectedSearchTool == 'x_search') {
      // X search parameters
      if (_allowedHandlesController.text.isNotEmpty) {
        toolConfig['allowed_x_handles'] = _allowedHandlesController.text
            .split(',')
            .map((h) => h.trim().replaceAll('@', ''))
            .where((h) => h.isNotEmpty)
            .toList();
      }
      if (_excludedHandlesController.text.isNotEmpty) {
        toolConfig['excluded_x_handles'] = _excludedHandlesController.text
            .split(',')
            .map((h) => h.trim().replaceAll('@', ''))
            .where((h) => h.isNotEmpty)
            .toList();
      }
      if (_fromDateController.text.isNotEmpty) {
        toolConfig['from_date'] = _fromDateController.text.trim();
      }
      if (_toDateController.text.isNotEmpty) {
        toolConfig['to_date'] = _toDateController.text.trim();
      }
      if (_enableImageUnderstanding) {
        toolConfig['enable_image_understanding'] = true;
      }
      if (_enableVideoUnderstanding) {
        toolConfig['enable_video_understanding'] = true;
      }
    }

    final body = jsonEncode({
      'model': 'grok-4-fast',
      'input': [
        {'role': 'user', 'content': query},
      ],
      'tools': [toolConfig],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract content from response
        String content = '';
        List<String> citations = [];

        // Parse the actual xAI response structure
        if (data['output'] != null &&
            data['output'] is List &&
            data['output'].isNotEmpty) {
          // Find the message in output array
          for (var item in data['output']) {
            if (item['type'] == 'message' && item['content'] != null) {
              // Extract text from content array
              if (item['content'] is List) {
                for (var contentItem in item['content']) {
                  if (contentItem['type'] == 'output_text' &&
                      contentItem['text'] != null) {
                    content = contentItem['text'].toString();
                  }

                  // Extract citations from annotations
                  if (contentItem['annotations'] != null &&
                      contentItem['annotations'] is List) {
                    for (var annotation in contentItem['annotations']) {
                      if (annotation['type'] == 'url_citation' &&
                          annotation['url'] != null) {
                        citations.add(annotation['url'].toString());
                      }
                    }
                  }
                }
              }
              break;
            }
          }
        }

        // Fallback parsing if the structure is different
        if (content.isEmpty) {
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            content = data['choices'][0]['message']['content'].toString();
          } else {
            content =
                'Response received but could not parse content. Status: ${data['status']}';
          }
        }

        setState(() {
          _result = content;
          _citations = citations;
          _loading = '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode} - ${response.body}';
          _loading = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.travel_explore, color: _accentColor, size: 24),
            SizedBox(width: 8),
            Text('xAI Agentic Search', style: TextStyle(color: _textColor)),
          ],
        ),
        backgroundColor: _cardColor,
        foregroundColor: _textColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Search Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Tool Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _cardColor,
            child: Row(
              children: [
                const Text(
                  'Search Tool: ',
                  style: TextStyle(color: _textColor),
                ),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'web_search',
                      label: Text('Web Search'),
                      icon: Icon(Icons.public),
                    ),
                    ButtonSegment(
                      value: 'x_search',
                      label: Text('X Search'),
                      icon: Icon(Icons.clear),
                    ),
                  ],
                  selected: {_selectedSearchTool},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedSearchTool = newSelection.first;
                    });
                  },
                ),
              ],
            ),
          ),
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: _textColor),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _selectedSearchTool == 'web_search'
                          ? 'Enter search query (e.g., "What is xAI?")'
                          : 'Enter X search query (e.g., "Latest news about xAI")',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _primaryColor),
                      ),
                      filled: true,
                      fillColor: _cardColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _performSearch(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: _backgroundColor,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _backgroundColor,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: _backgroundColor),
                ),
              ],
            ),
          ),
          // Loading/Error Display
          if (_loading.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _loading,
                      style: const TextStyle(color: _textColor),
                    ),
                  ),
                ],
              ),
            ),
          if (_error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: _accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error,
                      style: const TextStyle(color: _accentColor),
                    ),
                  ),
                ],
              ),
            ),
          // Results Display
          Expanded(
            child: _result.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedSearchTool == 'web_search'
                              ? Icons.public
                              : Icons.clear,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedSearchTool == 'web_search'
                              ? 'Ready for Web Search\nAsk anything and get answers from the web'
                              : 'Ready for X Search\nSearch posts and conversations on X',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Main Result Card
                      if (_result.isNotEmpty)
                        Card(
                          color: _cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: _primaryColor,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Search Results',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: _textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SelectableText(
                                  _result,
                                  style: const TextStyle(
                                    color: _textColor,
                                    height: 1.6,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Citations
                      if (_citations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: _cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.link,
                                      color: _primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Citations',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_citations.length}',
                                        style: const TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._citations
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${entry.key + 1}. ',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _launchUrl(entry.value),
                                                child: Text(
                                                  entry.value,
                                                  style: const TextStyle(
                                                    color: _primaryColor,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'Search Settings',
          style: TextStyle(color: _textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedSearchTool == 'web_search') ...[
                const Text(
                  'Web Search Settings',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _allowedDomainsController,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    labelText: 'Allowed Domains (comma-separated, max 5)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'e.g., wikipedia.org, github.com',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _excludedDomainsController,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    labelText: 'Excluded Domains (comma-separated, max 5)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'e.g., example.com',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Enable Image Understanding',
                    style: TextStyle(color: _textColor),
                  ),
                  subtitle: const Text(
                    'Process and analyze images (increases token usage)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _enableImageUnderstanding,
                  onChanged: (value) {
                    setState(() {
                      _enableImageUnderstanding = value;
                    });
                    Navigator.pop(context);
                    _showSettingsDialog();
                  },
                ),
              ] else ...[
                const Text(
                  'X Search Settings',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _allowedHandlesController,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    labelText: 'Allowed X Handles (comma-separated, max 10)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'e.g., elonmusk, xai',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _excludedHandlesController,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    labelText: 'Excluded X Handles (comma-separated, max 10)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'e.g., username',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fromDateController,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    labelText: 'From Date (YYYY-MM-DD)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: '2025-01-01',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _toDateController,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    labelText: 'To Date (YYYY-MM-DD)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: '2025-12-31',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _backgroundColor,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Enable Image Understanding',
                    style: TextStyle(color: _textColor),
                  ),
                  subtitle: const Text(
                    'Process and analyze images (increases token usage)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _enableImageUnderstanding,
                  onChanged: (value) {
                    setState(() {
                      _enableImageUnderstanding = value;
                    });
                    Navigator.pop(context);
                    _showSettingsDialog();
                  },
                ),
                SwitchListTile(
                  title: const Text(
                    'Enable Video Understanding',
                    style: TextStyle(color: _textColor),
                  ),
                  subtitle: const Text(
                    'Process and analyze videos (increases token usage)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _enableVideoUnderstanding,
                  onChanged: (value) {
                    setState(() {
                      _enableVideoUnderstanding = value;
                    });
                    Navigator.pop(context);
                    _showSettingsDialog();
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) {
    // Use url_launcher package if available; otherwise, print or handle differently
    debugPrint('Open URL: $url');
  }

  @override
  void dispose() {
    _controller.dispose();
    _allowedDomainsController.dispose();
    _excludedDomainsController.dispose();
    _allowedHandlesController.dispose();
    _excludedHandlesController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }
}
