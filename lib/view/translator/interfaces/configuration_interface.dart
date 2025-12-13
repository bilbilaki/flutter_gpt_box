import 'package:flutter/material.dart';
import 'package:gpt_box/main.dart';
import 'package:gpt_box/view/translator/configuration/translator_config.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late final TextEditingController _apiKey;
  late final TextEditingController _geminiApiKey;
  late final TextEditingController _baseUrl;
  late final TextEditingController _rateLimitReq;
  late final TextEditingController _rateLimitToken;
  late final TextEditingController _inputCost;
  late final TextEditingController _outputCost;
  late final TextEditingController _waitSec;
  late final TextEditingController _inputLang;
  late final TextEditingController _outputLang;
  late final TextEditingController _batchN;
  late final TextEditingController _outputFormat;
  late final TextEditingController _modelId;
  late final TextEditingController _systemPrompt;
  late final TextEditingController _geminiPrompt;
  late bool _autoDetectInput;
  late double _temp;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: translatorConfig.apiKey);
    _geminiApiKey = TextEditingController(text: translatorConfig.geminiApi);
    _baseUrl = TextEditingController(text: translatorConfig.baseUrl);
    _rateLimitReq = TextEditingController(
      text: translatorConfig.rateLimitReq.toString(),
    );
    _rateLimitToken = TextEditingController(
      text: translatorConfig.rateLimitToken.toString(),
    );
    _inputCost = TextEditingController(
      text: translatorConfig.inputCost.toString(),
    );
    _outputCost = TextEditingController(
      text: translatorConfig.outputCost.toString(),
    );
    _waitSec = TextEditingController(text: translatorConfig.waitSec.toString());
    _inputLang = TextEditingController(text: translatorConfig.inputLang);
    _outputLang = TextEditingController(text: translatorConfig.outputLang);
    _batchN = TextEditingController(text: translatorConfig.batchN.toString());
    _outputFormat = TextEditingController(text: translatorConfig.outputFormat);
    _modelId = TextEditingController(text: translatorConfig.modelId);
    _systemPrompt = TextEditingController(text: translatorConfig.systemPrompt);
    _geminiPrompt = TextEditingController(text: translatorConfig.geminiPrompt);
    _autoDetectInput = translatorConfig.autoDetectInput;
    _temp = translatorConfig.temp;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _geminiApiKey.dispose();
    _baseUrl.dispose();
    _rateLimitReq.dispose();
    _rateLimitToken.dispose();
    _inputCost.dispose();
    _outputCost.dispose();
    _waitSec.dispose();
    _inputLang.dispose();
    _outputLang.dispose();
    _batchN.dispose();
    _outputFormat.dispose();
    _modelId.dispose();
    _systemPrompt.dispose();
    _geminiPrompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      translatorConfig
        ..apiKey = _apiKey.text
        ..geminiApi = _geminiApiKey.text
        ..baseUrl = _baseUrl.text
        ..rateLimitReq =
            int.tryParse(_rateLimitReq.text) ?? translatorConfig.rateLimitReq
        ..rateLimitToken =
            int.tryParse(_rateLimitToken.text) ??
            translatorConfig.rateLimitToken
        ..inputCost =
            double.tryParse(_inputCost.text) ?? translatorConfig.inputCost
        ..outputCost =
            double.tryParse(_outputCost.text) ?? translatorConfig.outputCost
        ..waitSec = int.tryParse(_waitSec.text) ?? translatorConfig.waitSec
        ..inputLang = _inputLang.text
        ..outputLang = _outputLang.text
        ..autoDetectInput = _autoDetectInput
        ..batchN = int.tryParse(_batchN.text) ?? translatorConfig.batchN
        ..outputFormat = _outputFormat.text
        ..modelId = _modelId.text
        ..systemPrompt = _systemPrompt.text
        ..geminiPrompt = _geminiPrompt.text
        ..temp = _temp;

      final box = Hive.box<TranslatorConfig>('app_config');
      await box.put('config', translatorConfig);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    TextInputType? kt,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: kt,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('API', style: TextStyle(fontWeight: FontWeight.bold)),
            _field(_apiKey, 'API Key', kt: TextInputType.visiblePassword),
            _field(
              _geminiApiKey,
              'Gemini API Key',
              kt: TextInputType.visiblePassword,
            ),
            _field(_baseUrl, 'Base URL'),
            const SizedBox(height: 10),
            const Text(
              'Limits (per minute)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _rateLimitReq,
                    'Request Limit',
                    kt: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                    _rateLimitToken,
                    'Token Limit',
                    kt: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Pricing (per 1M tokens)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _inputCost,
                    'Input Cost',
                    kt: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                    _outputCost,
                    'Output Cost',
                    kt: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Languages & Format',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(child: _field(_inputLang, 'Input Lang')),
                const SizedBox(width: 8),
                Expanded(child: _field(_outputLang, 'Output Lang')),
              ],
            ),
            SwitchListTile(
              title: const Text('Auto-detect input'),
              value: _autoDetectInput,
              onChanged: (v) => setState(() => _autoDetectInput = v),
            ),
            _field(_outputFormat, 'Output Format'),
            const SizedBox(height: 10),
            const Text(
              'Model & Behavior',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(child: _field(_modelId, 'Model ID')),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(_batchN, 'Batch N', kt: TextInputType.number),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Temperature : ${translatorConfig.temp}'),
              subtitle: Slider(
                value: _temp,
                min: 0,
                max: 1,
                divisions: 10,
                label: _temp.toStringAsFixed(1),
                onChanged: (v) => setState(() => _temp = v),
              ),
            ),
            _field(_systemPrompt, 'System Prompt', maxLines: 8),
            _field(_geminiPrompt, 'Gemini Ocr Prompt', maxLines: 8),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Save'),
      ),
    );
  }
}
