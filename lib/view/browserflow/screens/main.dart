import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;
import '../tasks/pdf_task.dart';
import '../tasks/screenshot_fullpage_task.dart';
import '../tasks/screenshot_element_task.dart';
import '../tasks/page_content_task.dart';
import '../tasks/screencast_task.dart';
import 'widgets/url_input_section.dart';
import 'widgets/task_configuration_section.dart';
import 'widgets/url_list_section.dart';
import 'widgets/progress_tracker_section.dart';
import 'widgets/action_button.dart';
class PDFGeneratorWidget extends StatefulWidget {
  const PDFGeneratorWidget({Key? key}) : super(key: key);

  @override
  State<PDFGeneratorWidget> createState() => _PDFGeneratorWidgetState();
}

class _PDFGeneratorWidgetState extends State<PDFGeneratorWidget> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _selectorController = TextEditingController(text: 'input[id="search-box"]');
  final List<String> _urls = [];
  int _totalUrls = 0;
  int _completedUrls = 0;
  bool _isRunning = false;
  String _currentUrl = '';
  
  // Task selection
  String _selectedTask = 'pdf'; // 'pdf' | 'screenshot' | 'element' | 'html' | 'screencast'
  
  // Configuration
  String _selectedDevice = 'none'; // Device type
  String _selectedWaitRule = 'networkAlmostIdle'; // Wait condition
  
  // Screencast configuration
  int _screencastWidth = 1280;
  int _screencastHeight = 720;
  int _screencastDuration = 5; // seconds

  @override
  void dispose() {
    _urlController.dispose();
    _selectorController.dispose();
    super.dispose();
  }

  void _addUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }
    
    final validatedUrl = _validateAndFormatUrl(url);
    setState(() {
      _urls.add(validatedUrl);
      _urlController.clear();
      _totalUrls = _urls.length;
    });
  }

  void _removeUrl(int index) {
    setState(() {
      _urls.removeAt(index);
      _totalUrls = _urls.length;
    });
  }

  void _clearAllUrls() {
    setState(() {
      _urls.clear();
      _totalUrls = 0;
      _completedUrls = 0;
      _currentUrl = '';
    });
  }

  String _validateAndFormatUrl(String url) {
    url = url.trim();
    
    // If URL already starts with http:// or https://, return as is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // Otherwise, add https://
    return 'https://$url';
  }

  void _addBatchUrls() {
    final batchText = _urlController.text.trim();
    if (batchText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter URLs (one per line)')),
      );
      return;
    }

    final lines = batchText.split('\n');
    final validUrls = <String>[];
    
    for (final line in lines) {
      final url = line.trim();
      if (url.isNotEmpty) {
        validUrls.add(_validateAndFormatUrl(url));
      }
    }

    if (validUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid URLs found')),
      );
      return;
    }

    setState(() {
      _urls.addAll(validUrls);
      _urlController.clear();
      _totalUrls = _urls.length;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${validUrls.length} URLs')),
    );
  }

  Future<void> _startGeneration() async {
    if (_urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one URL')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _completedUrls = 0;
    });

    final waitRule = _getWaitRule(_selectedWaitRule);
    
    try {
      if (_selectedTask == 'pdf') {
        await generatePDFTask(
          _urls,
          waitRule,
          context,
          onProgress: (completed, currentUrl) {
            setState(() {
              _completedUrls = completed;
              _currentUrl = currentUrl;
            });
          },
        );
      } else if (_selectedTask == 'screenshot') {
        final device = _getDevice(_selectedDevice);
        await screenshotFullPageTask(
          _urls,
          waitRule,
          device,
          context,
          onProgress: (completed, currentUrl) {
            setState(() {
              _completedUrls = completed;
              _currentUrl = currentUrl;
            });
          },
        );
      } else if (_selectedTask == 'element') {
        final selector = _selectorController.text.trim();
        if (selector.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a CSS selector')),
          );
          setState(() {
            _isRunning = false;
          });
          return;
        }
        await screenshotElementTask(
          _urls,
          selector,
          waitRule,
          context,
          onProgress: (completed, currentUrl) {
            setState(() {
              _completedUrls = completed;
              _currentUrl = currentUrl;
            });
          },
        );
      } else if (_selectedTask == 'html') {
        await pageContentTask(
          _urls,
          waitRule,
          context,
          onProgress: (completed, currentUrl) {
            setState(() {
              _completedUrls = completed;
              _currentUrl = currentUrl;
            });
          },
        );
      } else if (_selectedTask == 'screencast') {
        await screencastTask(
          _urls,
          waitRule,
           _screencastWidth,
           _screencastHeight,
           _screencastDuration,
          context,
          onProgress: (completed, currentUrl) {
            setState(() {
              _completedUrls = completed;
              _currentUrl = currentUrl;
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() {
      _isRunning = false;
    });
  }
  
  pup.Until _getWaitRule(String rule) {
    switch (rule) {
      case 'domContentLoaded':
        return pup.Until.domContentLoaded;
      case 'networkIdle':
        return pup.Until.networkIdle;
      case 'networkAlmostIdle':
      default:
        return pup.Until.networkAlmostIdle;
    }
  }
  
  pup.Device? _getDevice(String deviceName) {
    // Return null for desktop (no device emulation)
    // For mobile devices, we can use the device emulation
    // The device parameter will be null for desktop mode
    if (deviceName == 'none') {
      return null;
    }
    
    // For now, we'll just return null since device construction is complex
    // The screenshot function will need to handle device emulation differently
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL Input Section
          URLInputSection(
            urlController: _urlController,
            onAddSingle: _addUrl,
            onAddBatch: _addBatchUrls,
            isRunning: _isRunning,
          ),
          const SizedBox(height: 16),

          // Task and Configuration Section
          TaskConfigurationSection(
            selectedTask: _selectedTask,
            onTaskChanged: (value) {
              setState(() {
                _selectedTask = value ?? 'pdf';
              });
            },
            selectedDevice: _selectedDevice,
            onDeviceChanged: (value) {
              setState(() {
                _selectedDevice = value ?? 'none';
              });
            },
            selectorController: _selectorController,
            screencastWidth: _screencastWidth,
            screencastHeight: _screencastHeight,
            screencastDuration: _screencastDuration,
            onWidthChanged: (value) {
              setState(() {
                _screencastWidth = value ?? _screencastWidth;
              });
            },
            onHeightChanged: (value) {
              setState(() {
                _screencastHeight = value ?? _screencastHeight;
              });
            },
            onDurationChanged: (value) {
              setState(() {
                _screencastDuration = value ?? _screencastDuration;
              });
            },
            selectedWaitRule: _selectedWaitRule,
            onWaitRuleChanged: (value) {
              setState(() {
                _selectedWaitRule = value ?? 'networkAlmostIdle';
              });
            },
            isRunning: _isRunning,
          ),
          const SizedBox(height: 16),

          // URL List Section
          URLListSection(
            urls: _urls,
            onClearAll: _clearAllUrls,
            onRemoveUrl: _removeUrl,
            isRunning: _isRunning,
          ),
          const SizedBox(height: 24),

          // Progress Tracker Section
          ProgressTrackerSection(
            totalUrls: _totalUrls,
            completedUrls: _completedUrls,
            isRunning: _isRunning,
            currentUrl: _currentUrl,
          ),
          const SizedBox(height: 24),

          // Run Button
          ActionButton(
            onPressed: _startGeneration,
            isRunning: _isRunning,
          ),
        ],
      ),
    );
  }
}



