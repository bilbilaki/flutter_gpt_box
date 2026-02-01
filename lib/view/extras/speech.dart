import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/res/openai.dart';
import '../page/home/home.dart';

class OpenAITTSPage extends StatefulWidget {
  const OpenAITTSPage({super.key});

  @override
  State<OpenAITTSPage> createState() => _OpenAITTSPageState();
}

class _OpenAITTSPageState extends State<OpenAITTSPage> {
  final TextEditingController _inputController = TextEditingController();
  
  
  final List<String> _voices = [
    'alloy', 'ash', 'echo', 'ballad', 'sage', 'coral', 'shimmer'
  ];
  String _selectedVoice = 'alloy';
  
   final List<String> _models = [
    'tts-1-hd', 'tts-1', 'gpt-4o-mini-tts-2025-03-20', 'whisper-1', 
  ];
  String _selectedmodel = 'gpt-4o-mini-tts-2025-03-20';
  
  bool _isLoading = false;
  Uint8List? _audioBytes;
  
  
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0B0B0F);
  static const border = Color(0xFF24242C);
  static const accent = Color(0xFF7C4DFF);

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  

  
  Future<void> _pickAndReadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        
        try {
          String content = await file.readAsString();
          setState(() {
            _inputController.text = content;
          });
        } catch (e) {
          _showSnack("Could not read file as text. Binary file?");
        }
      }
    } catch (e) {
      _showSnack("Error picking file: $e");
    }
  }

  
  Future<void> _generateSpeech() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      _showSnack("Please enter text or pick a file.");
      return;
    }

    setState(() {
      _isLoading = true;
      _audioBytes = null; 
    });

        final url = Uri.parse('${Cfg.current.url}/audio/speech');
    
    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer ${Cfg.current.key}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _selectedmodel,
          "input": text,
          "voice": _selectedVoice,
        }),
      );


      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('application/json') == true) {
           
           _showSnack("API Error: ${response.body}");
        } else {
          
          setState(() {
            _audioBytes = response.bodyBytes;
          });
        }
      } else {
        _showSnack("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      _showSnack("Connection error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  
  Future<void> _saveFile() async {
    if (_audioBytes == null) return;

    String fileName = "speech_${DateTime.now().millisecondsSinceEpoch}.mp3";

    try {
      String? savePath;

      if (Platform.isAndroid) {
        
        await _handleAndroidPermissions();
        
        
        Directory? directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
        
        if (directory != null) {
          savePath = "${directory.path}/$fileName";
          final file = File(savePath);
          await file.writeAsBytes(_audioBytes!);
          _showSnack("Saved to: $savePath");
        } else {
          _showSnack("Could not determine storage directory");
        }

      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Audio',
          fileName: fileName,
          type: FileType.audio,
          allowedExtensions: ['mp3'],
        );

        if (savePath != null) {
          final file = File(savePath);
          await file.writeAsBytes(_audioBytes!);
          _showSnack("Saved to: $savePath");
        }
      } else {
        
        final directory = await getApplicationDocumentsDirectory();
        savePath = "${directory.path}/$fileName";
        File(savePath).writeAsBytesSync(_audioBytes!);
        _showSnack("Saved to app documents: $fileName");
      }
    } catch (e) {
      debugPrint(e.toString());
      _showSnack("Error saving file: $e");
    }
  }

  Future<void> _handleAndroidPermissions() async {
    if (Platform.isAndroid) {
      
      
      
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      
      if (await Permission.audio.status.isDenied) {
        await Permission.audio.request();
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  

  @override
  Widget build(BuildContext context) {
    
    
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
    );

    
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);
    final theme = base.copyWith(textTheme: textTheme);

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("AI Text to Speech"),
          backgroundColor: bg,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              
              DropdownButtonFormField<String>(
                value: _selectedVoice,
                decoration: const InputDecoration(
                  labelText: "Select Voice",
                  prefixIcon: Icon(Icons.record_voice_over),
                ),
                items: _voices.map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(v.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVoice = val);
                },
              ),
              
              const SizedBox(height: 20),
   DropdownButtonFormField<String>(
                value: _selectedmodel,
                decoration: const InputDecoration(
                  labelText: "Select Model",
                  prefixIcon: Icon(Icons.record_voice_over),
                ),
                items: _models.map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(v.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedmodel = val);
                },
              ),
              
              const SizedBox(height: 20),
              
              TextField(
                controller: _inputController,
                maxLines: 6,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Enter text here or pick a file...",
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.upload_file),
                    tooltip: "Pick text file",
                    onPressed: _pickAndReadFile,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateSpeech,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.graphic_eq),
                  label: Text(_isLoading ? "Generating..." : "Generate Speech"),
                ),
              ),

              const SizedBox(height: 30),

              
              if (_isLoading)
                 Center(
                   child: Column(
                     children: [
                       const CircularProgressIndicator(color: accent),
                       const SizedBox(height: 10),
                       Text("Waiting for OpenAI...", style: TextStyle(color: Colors.grey.shade400)),
                     ],
                   ),
                 ),

              if (!_isLoading && _audioBytes != null) ...[
                const Text("Generated Audio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                
                AudioPlayerTile(
                  bytes: _audioBytes!,
                  autoPlay: true, 
                ),

                const SizedBox(height: 15),

                
                OutlinedButton.icon(
                  onPressed: _saveFile,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("Save to Device"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}