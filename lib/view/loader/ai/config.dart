import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class Config {
  String apiKey = "";
  String baseUrl = "";
  String proxyUrl = "";
  String currentModel = "";
  bool autoAccept = true;
  bool firstSetup = true;

  static Future<Config> load() async {
    final path = _getConfigPath();
    final file = File(path);
    if (!await file.exists()) return Config();

    try {
      final content = await file.readAsString();
      final map = jsonDecode(content);
      return Config()
        ..apiKey = map['api_key'] ?? ""
        ..baseUrl = map['base_url'] ?? ""
        ..proxyUrl = map['proxy_url'] ?? ""
        ..currentModel = map['current_model'] ?? ""
        ..autoAccept = map['auto_accept'] ?? false
        ..firstSetup = map['first_setup'] ?? false;
    } catch (_) {
      return Config();
    }
  }

  Future<void> save() async {
    final path = _getConfigPath();
    final file = File(path);
    await file.parent.create(recursive: true);
    final encoder = JsonEncoder.withIndent("  ");
    await file.writeAsString(
      encoder.convert({
        'api_key': apiKey,
        'base_url': baseUrl,
        'proxy_url': proxyUrl,
        'current_model': currentModel,
        'auto_accept': autoAccept,
        'first_setup': firstSetup,
      }),
    );
  }

  static String _getConfigPath() {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    Directory(p.join(home!, '.config', 'ai2dart')).existsSync()
        ? null
        : Directory(p.join(home, '.config', 'ai2dart')).createSync();
    File(p.join(home, '.config', 'ai2dart', 'config.json')).existsSync()
        ? null
        : File(p.join(home, '.config', 'ai2dart', 'config.json')).createSync();
    return p.join(home, '.config', 'ai2dart', 'config.json');
  }
}

// UI Editor Widget
class ConfigEditor extends StatefulWidget {
  const ConfigEditor({Key? key}) : super(key: key);

  @override
  _ConfigEditorState createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  late Config config;
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _proxyUrlController;
  late TextEditingController _currentModelController;
  bool _autoAccept = true;
  bool _firstSetup = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      config = await Config.load();
      _apiKeyController = TextEditingController(text: config.apiKey);
      _baseUrlController = TextEditingController(text: config.baseUrl);
      _proxyUrlController = TextEditingController(text: config.proxyUrl);
      _currentModelController = TextEditingController(
        text: config.currentModel,
      );
      _autoAccept = config.autoAccept;
      _firstSetup = config.firstSetup;
      setState(() => _isLoading = false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load config: $e')));
      config = Config();
      _apiKeyController = TextEditingController(text: config.apiKey);
      _baseUrlController = TextEditingController(text: config.baseUrl);
      _proxyUrlController = TextEditingController(text: config.proxyUrl);
      _currentModelController = TextEditingController(
        text: config.currentModel,
      );
      _autoAccept = config.autoAccept;
      _firstSetup = config.firstSetup;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    config.apiKey = _apiKeyController.text;
    config.baseUrl = _baseUrlController.text;
    config.proxyUrl = _proxyUrlController.text;
    config.currentModel = _currentModelController.text;
    config.autoAccept = _autoAccept;
    config.firstSetup = _firstSetup;

    try {
      await config.save();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save config: $e')));
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _proxyUrlController.dispose();
    _currentModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Config Editor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an API key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(labelText: 'Base URL'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a base URL';
                  }
                  if (!Uri.tryParse(value)!.isAbsolute) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _proxyUrlController,
                decoration: const InputDecoration(
                  labelText: 'Proxy URL (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentModelController,
                decoration: const InputDecoration(labelText: 'Current Model'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a model name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto Accept'),
                value: _autoAccept,
                onChanged: (value) => setState(() => _autoAccept = value),
              ),
              SwitchListTile(
                title: const Text('First Setup'),
                value: _firstSetup,
                onChanged: (value) => setState(() => _firstSetup = value),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveConfig,
                child: const Text('Save Config'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
