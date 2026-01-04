import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_ffmpeg_kit_full/ffmpeg_kit.dart';
import 'package:flutter_ffmpeg_kit_full/ffprobe_kit.dart';
import 'package:flutter_ffmpeg_kit_full/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

// FFmpeg Imports

import '../../../core/util/utils.dart';
import '../../../data/res/openai.dart';

class MediaLabPage extends StatefulWidget {
  const MediaLabPage({super.key});

  @override
  State<MediaLabPage> createState() => _MediaLabPageState();
}

class _MediaLabPageState extends State<MediaLabPage> {
  // Theme Constants
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0B0B0F);
  static const border = Color(0xFF24242C);
  static const accent = Color(0xFF7C4DFF);

  // Selection State
  String? _videoPath;
  String? _audioPath;
  String? _subtitlePath;

  // Process State
  bool _isProcessing = false;
  final TextEditingController _logController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // --- UI Helpers ---

  void _log(String message) {
    setState(() {
      _logController.text += "\n> $message";
    });
    // Auto scroll to bottom
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _clearLog() => setState(() => _logController.clear());

  Future<void> _pickFile(FileType type, Function(String) onPicked) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
      );
      if (result != null && result.files.single.path != null) {
        onPicked(result.files.single.path!);
        _log("Selected ${type.name}: ${result.files.single.name}");
      }
    } catch (e) {
      _log("Error picking file: $e");
    }
  }

  // --- FFmpeg Functions ---

  /// 1. Extract Audio Tracks (Handles Multi-track)
  Future<void> _extractAudioTracks() async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    // First, probe to find how many audio streams exist
    FFprobeKit.getMediaInformation(_videoPath!).then((session) async {
      final info = session.getMediaInformation();
      final streams = info?.getStreams() ?? [];

      int audioCount = 0;
      for (var stream in streams) {
        if (stream.getType() == "audio") {
          final index = stream.getIndex();
          final outPathf = await getTargetDirectory(
            folderUnderApp: 'extracted_audio',
          );
          final outPath = p.join(outPathf.path, "extracted_audio_track_$index.mp3");
          _log("Extracting Audio Track #$index...");

          // -map 0:a:N selects the Nth audio track
          // -vn disables video
          await FFmpegKit.execute(
            '-y -i "$_videoPath" -map 0:$index -vn -acodec libmp3lame "$outPath"',
          ).then((s) async {
            if (ReturnCode.isSuccess(await s.getReturnCode())) {
              _log("Saved: $outPath");
            } else {
              _log("Failed to extract track $index");
            }
          });
          audioCount++;
        }
      }

      if (audioCount == 0) _log("No audio tracks found.");
      _endProcess();
    });
  }

  /// 2. Extract Subtitle Tracks (Handles Multi-track)
  Future<void> _extractSubtitleTracks() async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    FFprobeKit.getMediaInformation(_videoPath!).then((session) async {
      final info = session.getMediaInformation();
      final streams = info?.getStreams() ?? [];

      int subCount = 0;
      for (var stream in streams) {
        if (stream.getType() == "subtitle") {
          final index = stream.getIndex();
          final outPathf = await getTargetDirectory(
            folderUnderApp: 'extracted_sub',
          );
          final outPath = p.join(outPathf.path,  "extracted_sub_track_$index.srt",
          );

          _log("Extracting Subtitle Track #$index...");

          // -map 0:s:N selects Nth subtitle track
          await FFmpegKit.execute(
            '-y -i "$_videoPath" -map 0:$index "$outPath"',
          ).then((s) async {
            if (ReturnCode.isSuccess(await s.getReturnCode())) {
              _log("Saved: $outPath");
            } else {
              _log(
                "Failed to extract subtitle $index (Check if format is supported)",
              );
            }
          });
          subCount++;
        }
      }
      if (subCount == 0) _log("No subtitle tracks found.");
      _endProcess();
    });
  }

  /// 3. Attach Audio to Video (Set as default)
  Future<void> _attachAudioToVideo() async {
    if (_videoPath == null || _audioPath == null) {
      return _log("Need Video and Audio selected.");
    }
    _startProcess();

   final outPathf = await getTargetDirectory(
            folderUnderApp: 'merged_video',
          );
          final outPath = p.join(outPathf.path,  "video_new_audio_${DateTime.now().millisecondsSinceEpoch}.mp4",
    );

    // -map 0:v (Take video from file 0)
    // -map 1:a (Take audio from file 1)
    // -c:v copy (Copy video stream, no re-encode)
    // -c:a aac (Encode audio to aac)
    // -shortest (Stop when the shortest stream ends)
    final cmd =
        '-y -i "$_videoPath" -i "$_audioPath" -map 0:v -map 1:a -c:v copy -c:a aac -shortest "$outPath"';

    _log("Muxing audio to video...");
    await FFmpegKit.execute(cmd).then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        _log("Success! Saved to: $outPath");
      } else {
        _log("Error Muxing: ${await session.getOutput()}");
      }
      _endProcess();
    });
  }

  /// 4. Attach Subtitle to Video
  Future<void> _attachSubtitleToVideo() async {
    if (_videoPath == null || _subtitlePath == null)
      return _log("Need Video and Subtitle selected.");
    _startProcess();

     final outPathf = await getTargetDirectory(
            folderUnderApp: 'merged_video',
          );
          final outPath = p.join(outPathf.path,   "video_with_subs_${DateTime.now().millisecondsSinceEpoch}.mp4",
    );

    // -c:s mov_text (Standard MP4 subtitle format)
    // -metadata:s:s:0 language=eng (Example setting metadata)
    final cmd =
        '-y -i "$_videoPath" -i "$_subtitlePath" -map 0 -map 1 -c copy -c:s mov_text "$outPath"';

    _log("Embedding subtitles...");
    await FFmpegKit.execute(cmd).then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        _log("Success! Saved to: $outPath");
      } else {
        _log("Error: ${await session.getOutput()}");
        _log(
          "Note: embedding subtitles usually requires 'ffmpeg_kit_flutter_full_gpl' package.",
        );
      }
      _endProcess();
    });
  }

  /// 5. Split Audio (Custom Time)
  Future<void> _splitAudio() async {
    if (_audioPath == null) return _log("No Audio selected.");

    // Demo: Split from 00:00 to 00:10. In a real app, use input fields for start/duration.
    const start = "00:00:00";
    const duration = "10"; // seconds

    _startProcess();
      final outPathf = await getTargetDirectory(
            folderUnderApp: 'split_audio',
          );
          final outPath = p.join(outPathf.path,   "split_audio_${DateTime.now().millisecondsSinceEpoch}.mp3",
    );

    // -ss (start) -t (duration)
    final cmd =
        '-y -i "$_audioPath" -ss $start -t $duration -c copy "$outPath"';

    _log("Splitting audio (First 10s)...");
    await FFmpegKit.execute(cmd).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Success! Saved to: $outPath");
      } else {
        _log("Error splitting audio.");
      }
      _endProcess();
    });
  }

  // --- OpenAI Functions ---

  /// 6. Translate Audio (Whisper)
  Future<void> _translateAudio() async {
    final fileToUse = _audioPath ?? _videoPath; // Can translate video audio too
    if (fileToUse == null) return _log("Select Audio or Video file first.");

    _startProcess();
    _log("Uploading to OpenAI for Translation (Whisper)...");

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Cfg.current.url}/audio/translations"),
      );

      request.headers['Authorization'] = "Bearer ${Cfg.current.key}";
      request.fields['model'] = "whisper-1";
      // request.fields['prompt'] = "English translation"; // Optional
      request.files.add(await http.MultipartFile.fromPath('file', fileToUse));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _log(
          "Translation Result:\n----------------\n${data['text']}\n----------------",
        );
      } else {
        _log("API Error: ${response.body}");
      }
    } catch (e) {
      _log("Network Error: $e");
    } finally {
      _endProcess();
    }
  }

  /// 7. Transcribe Audio (Verbose JSON + Segments)
  Future<void> _transcribeAudio() async {
    final fileToUse = _audioPath ?? _videoPath;
    if (fileToUse == null) return _log("Select Audio or Video file first.");

    _startProcess();
    _log("Uploading to OpenAI for Transcription (Verbose)...");

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${Cfg.current.url}/audio/transcriptions"),
      );

      request.headers['Authorization'] = "Bearer ${Cfg.current.key}";
      request.fields['model'] =
          "whisper-1"; // or gpt-4o-transcribe if available
      request.fields['response_format'] = "verbose_json";

      // Necessary for segment data (like the JSON example provided)
      request.fields['timestamp_granularities[]'] = "segment";

      request.files.add(await http.MultipartFile.fromPath('file', fileToUse));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // Print general info
        _log("Language: ${data['language']}");
        _log("Duration: ${data['duration']}s");
        _log("Full Text: ${data['text']}");

        // Print Segments
        List segments = data['segments'] ?? [];
        _log("--- Segments (${segments.length}) ---");
        for (var seg in segments) {
          _log("[${seg['start']} - ${seg['end']}]: ${seg['text']}");
        }
      } else {
        _log("API Error: ${response.body}");
      }
    } catch (e) {
      _log("Network Error: $e");
    } finally {
      _endProcess();
    }
  }

  void _startProcess() {
    setState(() => _isProcessing = true);
  }

  void _endProcess() {
    setState(() => _isProcessing = false);
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    // Recreate the Theme
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
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);
    final theme = base.copyWith(textTheme: textTheme);

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Media Lab (FFmpeg + AI)"),
          backgroundColor: bg,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              onPressed: _clearLog,
              tooltip: "Clear Log",
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. File Selection Area
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFileSelector(
                    "Video Source",
                    Icons.videocam,
                    _videoPath,
                    () => _pickFile(
                      FileType.video,
                      (p) => setState(() => _videoPath = p),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFileSelector(
                    "Audio Source",
                    Icons.audiotrack,
                    _audioPath,
                    () => _pickFile(
                      FileType.audio,
                      (p) => setState(() => _audioPath = p),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFileSelector(
                    "Subtitle Source",
                    Icons.subtitles,
                    _subtitlePath,
                    () => _pickFile(
                      FileType.any,
                      (p) => setState(() => _subtitlePath = p),
                    ), // FileType.any because .srt sometimes not recognized
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text(
                    "Operations",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionBtn(
                        "Extr. Audio Tracks",
                        Icons.library_music,
                        _extractAudioTracks,
                        enabled: _videoPath != null,
                      ),
                      _buildActionBtn(
                        "Extr. Sub Tracks",
                        Icons.closed_caption,
                        _extractSubtitleTracks,
                        enabled: _videoPath != null,
                      ),
                      _buildActionBtn(
                        "Attach Audio",
                        Icons.add_link,
                        _attachAudioToVideo,
                        enabled: _videoPath != null && _audioPath != null,
                      ),
                      _buildActionBtn(
                        "Attach Subtitle",
                        Icons.post_add,
                        _attachSubtitleToVideo,
                        enabled: _videoPath != null && _subtitlePath != null,
                      ),
                      _buildActionBtn(
                        "Split Audio (10s)",
                        Icons.cut,
                        _splitAudio,
                        enabled: _audioPath != null,
                      ),
                      _buildActionBtn(
                        "AI Translate",
                        Icons.translate,
                        _translateAudio,
                        enabled: _audioPath != null || _videoPath != null,
                        isAi: true,
                      ),
                      _buildActionBtn(
                        "AI Transcribe",
                        Icons.description,
                        _transcribeAudio,
                        enabled: _audioPath != null || _videoPath != null,
                        isAi: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Console/Log Area
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF111118),
                child: Stack(
                  children: [
                    TextField(
                      controller: _logController,
                      readOnly: true,
                      maxLines: null,
                      scrollController: _scrollController,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: const Color(0xFFEDEDF5),
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                        hintText: "Process logs will appear here...",
                      ),
                    ),
                    if (_isProcessing)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Processing...",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector(
    String title,
    IconData icon,
    String? path,
    VoidCallback onTap,
  ) {
    bool hasFile = path != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasFile ? accent : border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasFile
                    ? accent.withOpacity(0.1)
                    : const Color(0xFF1C1C24),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: hasFile ? accent : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path != null
                        ? path.split('/').last
                        : "Tap to select file...",
                    style: TextStyle(
                      fontSize: 12,
                      color: path != null ? Colors.white70 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasFile)
              const Icon(Icons.check_circle, size: 18, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool enabled = true,
    bool isAi = false,
  }) {
    return Opacity(
      opacity: enabled && !_isProcessing ? 1.0 : 0.5,
      child: ElevatedButton.icon(
        onPressed: enabled && !_isProcessing ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isAi
              ? const Color(0xFF00E5FF).withOpacity(0.15)
              : surface,
          foregroundColor: isAi ? const Color(0xFF00E5FF) : Colors.white,
          side: BorderSide(
            color: isAi ? const Color(0xFF00E5FF).withOpacity(0.3) : border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
