import 'dart:convert';
import 'dart:async';
import 'dart:io' show File;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_ffmpeg_kit_full/ffmpeg_kit.dart';
import 'package:flutter_ffmpeg_kit_full/ffprobe_kit.dart';
import 'package:flutter_ffmpeg_kit_full/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

// FFmpeg Imports

import '../../core/util/utils.dart';
import '../../data/res/openai.dart';

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
  final TextEditingController _segmentDurationController =
      TextEditingController(text: "10");
  String _segmentDuration = "10";
  String _audioSplitDuration = "60";
  List<String> _concatFiles = [];
  String _selectedResolution = "1080p";
  Map<String, int> _cropParams = {
    'width': 1920,
    'height': 1080,
    'x': 0,
    'y': 0,
  };
  String _trimStart = "00:00:00";
  String _trimDuration = "10";
  String _rotateValue = "90";
  double _speedMultiplier = 1.0;
  Map<String, int> _watermarkParams = {'x': 0, 'y': 0, 'w': 100, 'h': 60};
  String? _overlayPath;
  double _volumeLevel = 1.0;
  String _audioTrimStart = "00:00:00";
  String _audioTrimDuration = "10";
  List<String> _mergeAudioPaths = [];
  int _sampleRate = 44100;
  String _bitrate = "192k";
  double _silenceDuration = 5.0;
  bool _audioExpanded = true;
  List<String> _recentFiles = [];
  Map<String, String> _fileInfo = {};
  bool _concatMultiSelect = true;

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
        final path = result.files.single.path!;
        onPicked(path);
        _addRecentFile(path);
        _loadFileInfo(path);
        _log("Selected ${type.name}: ${result.files.single.name}");
      }
    } catch (e) {
      _log("Error picking file: $e");
    }
  }

  Future<void> _selectConcatFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: _concatMultiSelect,
      );
      if (result != null) {
        final paths = result.paths
            .where((path) => path != null)
            .cast<String>()
            .toList();
        setState(() => _concatFiles = paths);
        _log(
          "Selected ${paths.length} file${paths.length == 1 ? "" : "s"} for concatenation.",
        );
        for (final pth in paths) {
          _addRecentFile(pth);
          _loadFileInfo(pth);
        }
      }
    } catch (e) {
      _log("Error picking concat files: $e");
    }
  }

  Future<void> _pickOverlayFile(Function(String) onPicked) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        onPicked(path);
        _addRecentFile(path);
        _loadFileInfo(path);
        _log("Selected Overlay: ${result.files.single.name}");
      }
    } catch (e) {
      _log("Error picking overlay: $e");
    }
  }

  Future<void> _pickMergeAudioFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: _concatMultiSelect,
      );
      if (result != null) {
        final paths = result.paths
            .where((path) => path != null)
            .cast<String>()
            .toList();
        setState(() => _mergeAudioPaths = paths);
        _log(
          "Selected ${paths.length} audio file${paths.length == 1 ? "" : "s"} to merge.",
        );
        for (final pth in paths) {
          _addRecentFile(pth);
          _loadFileInfo(pth);
        }
      }
    } catch (e) {
      _log("Error picking audio files: $e");
    }
  }

  void _addRecentFile(String path) {
    setState(() {
      _recentFiles.remove(path);
      _recentFiles.insert(0, path);
      if (_recentFiles.length > 5) {
        _recentFiles = _recentFiles.sublist(0, 5);
      }
    });
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return "${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}";
  }

  Future<void> _loadFileInfo(String path) async {
    try {
      final file = File(path);
      final size = await file.length();
      String infoText = _formatBytes(size);

      final session = await FFprobeKit.getMediaInformation(path);
      final mediaInfo = session.getMediaInformation();
      final durationStr = mediaInfo?.getDuration();
      if (durationStr != null) {
        final seconds = double.tryParse(durationStr) ?? 0;
        infoText = "${(seconds).toStringAsFixed(1)}s • $infoText";
      }

      if (mounted) {
        setState(() {
          _fileInfo[path] = infoText;
        });
      }
    } catch (e) {
      _log("Info load failed for $path: $e");
    }
  }

  void _clearAllFiles() {
    setState(() {
      _videoPath = null;
      _audioPath = null;
      _subtitlePath = null;
      _overlayPath = null;
      _concatFiles = [];
      _mergeAudioPaths = [];
      _fileInfo.clear();
    });
    _log("Cleared all selected files.");
  }

  Future<void> _chooseRecentDestination(String path) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text("Use as Video"),
              onTap: () {
                Navigator.pop(context);
                _assignFileToTarget(path, "video");
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.white),
              title: const Text("Use as Audio"),
              onTap: () {
                Navigator.pop(context);
                _assignFileToTarget(path, "audio");
              },
            ),
            ListTile(
              leading: const Icon(Icons.subtitles, color: Colors.white),
              title: const Text("Use as Subtitle"),
              onTap: () {
                Navigator.pop(context);
                _assignFileToTarget(path, "subtitle");
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers, color: Colors.white),
              title: const Text("Use as Overlay"),
              onTap: () {
                Navigator.pop(context);
                _assignFileToTarget(path, "overlay");
              },
            ),
          ],
        );
      },
    );
  }

  void _assignFileToTarget(String path, String target) {
    setState(() {
      switch (target) {
        case "video":
          _videoPath = path;
          break;
        case "audio":
          _audioPath = path;
          break;
        case "subtitle":
          _subtitlePath = path;
          break;
        case "overlay":
          _overlayPath = path;
          break;
      }
    });
    _addRecentFile(path);
    _loadFileInfo(path);
    _log("Assigned ${p.basename(path)} to $target.");
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
          final outPath = p.join(
            outPathf.path,
            "extracted_audio_track_$index.mp3",
          );
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
          final outPath = p.join(
            outPathf.path,
            "extracted_sub_track_$index.srt",
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

    final outPathf = await getTargetDirectory(folderUnderApp: 'merged_video');
    final outPath = p.join(
      outPathf.path,
      "video_new_audio_${DateTime.now().millisecondsSinceEpoch}.mp4",
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

    final outPathf = await getTargetDirectory(folderUnderApp: 'merged_video');
    final outPath = p.join(
      outPathf.path,
      "video_with_subs_${DateTime.now().millisecondsSinceEpoch}.mp4",
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
    final outPathf = await getTargetDirectory(folderUnderApp: 'split_audio');
    final outPath = p.join(
      outPathf.path,
      "split_audio_${DateTime.now().millisecondsSinceEpoch}.mp3",
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

  /// 5b. Split Audio into duration-based parts
  Future<void> _splitAudioIntoParts(int segmentSeconds) async {
    if (_audioPath == null) return _log("No Audio selected.");
    if (segmentSeconds <= 0) {
      return _log("Segment duration must be greater than 0 seconds.");
    }

    _startProcess();
    final outPathf = await getTargetDirectory(
      folderUnderApp: 'split_audio_parts',
    );
    final baseName = p.basenameWithoutExtension(_audioPath!);
    final ext = p.extension(_audioPath!);
    final outputPattern = p.join(outPathf.path, "${baseName}_part_%03d$ext");

    final cmd =
        '-y -i "$_audioPath" -f segment -segment_time $segmentSeconds -c copy "$outputPattern"';

    _log("Splitting audio into $segmentSeconds second parts...");
    try {
      await FFmpegKit.execute(cmd).then((session) async {
        if (ReturnCode.isSuccess(await session.getReturnCode())) {
          _log("Success! Segments saved to: ${outPathf.path}");
        } else {
          _log("Error: ${await session.getOutput()}");
        }
      });
    } finally {
      _endProcess();
    }
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

  ////TODO keep working on UI part to can be include all this blow new functions list
  //From this Part All function is new and should I create UI for them
  /// 1. Convert between any media formats (MP4, AVI, MKV, MOV, WebM, etc.)
  Future<void> _convertMediaFormat() async {
    if (_videoPath == null) return _log("No input file selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'converted_media',
    );
    final outPath = p.join(
      outPathf.path,
      "converted_output.mp4",
    ); // Adjust extension as needed
    _log("Converting format...");

    await FFmpegKit.execute('-y -i "$_videoPath" "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Converted: $outPath");
      } else {
        _log("Conversion failed.");
      }
    });

    _endProcess();
  }

  /// 2. Extract audio from video files
  Future<void> _extractAudioFromVideo() async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'extracted_audio',
    );
    final outPath = p.join(outPathf.path, "extracted_audio.mp3");
    _log("Extracting audio...");

    await FFmpegKit.execute('-y -i "$_videoPath" -vn "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Audio extracted: $outPath");
      } else {
        _log("Extraction failed.");
      }
    });

    _endProcess();
  }

  /// 3. Extract video from files
  Future<void> _extractVideoFromFile() async {
    if (_videoPath == null) return _log("No file selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'extracted_video',
    );
    final outPath = p.join(outPathf.path, "video_only.mp4");
    _log("Extracting video...");

    await FFmpegKit.execute('-y -i "$_videoPath" -an "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Video extracted: $outPath");
      } else {
        _log("Extraction failed.");
      }
    });

    _endProcess();
  }

  /// 4. Combine audio and video streams
  Future<void> _combineAudioVideoStreams(String audioPath) async {
    if (_videoPath == null || audioPath.isEmpty)
      return _log("Video or audio not selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'combined_media');
    final outPath = p.join(outPathf.path, "combined_output.mp4");
    _log("Combining streams...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -i "$audioPath" -c:v copy -c:a aac "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Combined: $outPath");
      } else {
        _log("Combination failed.");
      }
    });

    _endProcess();
  }

  /// 5. Split files into segments
  Future<void> _splitFileIntoSegments(int segmentTimeSeconds) async {
    if (_videoPath == null) return _log("No file selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'segments');
    final baseName = p.basenameWithoutExtension(_videoPath!);
    _log("Splitting into segments...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -f segment -segment_time $segmentTimeSeconds -c copy "${outPathf.path}/$baseName\/_%03d.mp4"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Segments saved in: ${outPathf.path}");
      } else {
        _log("Splitting failed.");
      }
    });

    _endProcess();
  }

  /// 6. Concatenate multiple files
  Future<void> _concatenateFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return _log("No files to concatenate.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'concatenated');
    final outPath = p.join(outPathf.path, "concatenated_output.mp4");
    final fileList = p.join(outPathf.path, "files.txt");

    // Create concat file list
    final file = File(fileList);
    await file.writeAsString(
      filePaths.map((path) => "file '$path'").join('\n'),
    );

    _log("Concatenating files...");

    await FFmpegKit.execute(
      '-y -f concat -safe 0 -i "$fileList" -c copy "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Concatenated: $outPath");
      } else {
        _log("Concatenation failed.");
      }
    });

    _endProcess();
  }

  /// 7. Change container format without re-encoding
  Future<void> _changeContainerFormat() async {
    if (_videoPath == null) return _log("No file selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'changed_container',
    );
    final outPath = p.join(
      outPathf.path,
      "container_changed.mkv",
    ); // Example to MKV
    _log("Changing container...");

    await FFmpegKit.execute('-y -i "$_videoPath" -c copy "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Container changed: $outPath");
      } else {
        _log("Failed to change container.");
      }
    });

    _endProcess();
  }

  /// 8. Probe Media Info
  Future<void> _probeMediaInfo() async {
    if (_videoPath == null) return _log("No file selected.");
    _startProcess();
    _log("Probing media information...");

    await FFprobeKit.getMediaInformation(_videoPath!).then((session) async {
      final info = session.getMediaInformation();
      if (info == null) {
        _log("Failed to retrieve media info.");
        _endProcess();
        return;
      }
      final streams = info.getStreams();
      _log("Found ${streams.length} stream(s).");
      for (var stream in streams) {
        final type = stream.getType() ?? "unknown";
        final codec = stream.getCodec() ?? "unknown codec";
        final index = stream.getIndex();
        final detail = [
          if (stream.getWidth() != null)
            "${stream.getWidth()}x${stream.getHeight()}",
          if (stream.getSampleRate() != null) "sr:${stream.getSampleRate()}",
          if (stream.getChannelLayout() != null)
            "ch:${stream.getChannelLayout()}",
        ].join(" ");
        _log(
          "Stream #$index [$type]: $codec ${detail.isNotEmpty ? detail : ""}"
              .trim(),
        );
      }
      _endProcess();
    });
  }

  /// 1. Resize/Scale: Change resolution (1080p, 720p, 480p, etc.)
  Future<void> _resizeVideo(int width, int height) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'resized_video');
    final outPath = p.join(outPathf.path, "resized_output.mp4");
    _log("Resizing video...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf scale=$width:$height "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Resized: $outPath");
      } else {
        _log("Resize failed.");
      }
    });

    _endProcess();
  }

  /// 2. Crop: Remove unwanted edges
  Future<void> _cropVideo(int width, int height, int x, int y) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'cropped_video');
    final outPath = p.join(outPathf.path, "cropped_output.mp4");
    _log("Cropping video...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf crop=$width:$height:$x:$y "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Cropped: $outPath");
      } else {
        _log("Crop failed.");
      }
    });

    _endProcess();
  }

  /// 3. Trim: Cut specific segments
  Future<void> _trimVideo(String startTime, String duration) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'trimmed_video');
    final outPath = p.join(outPathf.path, "trimmed_output.mp4");
    _log("Trimming video...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -ss $startTime -t $duration "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Trimmed: $outPath");
      } else {
        _log("Trim failed.");
      }
    });

    _endProcess();
  }

  /// 4. Rotate/Flip: Change orientation
  Future<void> _rotateFlipVideo(String mode) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'rotated_video');
    final outPath = p.join(outPathf.path, "rotated_output.mp4");
    final filter = () {
      switch (mode) {
        case "180":
          return "transpose=1,transpose=1";
        case "270":
          return "transpose=2";
        case "Mirror":
          return "hflip";
        case "90":
        default:
          return "transpose=1";
      }
    }();

    _log("Rotating/flipping ($mode)...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf "$filter" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Rotated: $outPath");
      } else {
        _log("Rotation failed.");
      }
    });

    _endProcess();
  }

  /// 5. Speed up/Slow down: Adjust playback speed
  Future<void> _adjustVideoSpeed(double speedMultiplier) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'speed_adjusted_video',
    );
    final outPath = p.join(outPathf.path, "speed_output.mp4");
    final ptsValue = (1 / speedMultiplier).toStringAsFixed(2);
    _log("Adjusting speed...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -filter:v "setpts=$ptsValue*PTS" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Speed adjusted: $outPath");
      } else {
        _log("Speed adjustment failed.");
      }
    });

    _endProcess();
  }

  /// 6. Reverse: Play video backwards
  Future<void> _reverseVideo() async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'reversed_video');
    final outPath = p.join(outPathf.path, "reversed_output.mp4");
    _log("Reversing video...");

    await FFmpegKit.execute('-y -i "$_videoPath" -vf reverse "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Reversed: $outPath");
      } else {
        _log("Reversal failed.");
      }
    });

    _endProcess();
  }

  /// 7. Add/Remove watermarks
  Future<void> _removeWatermark(int x, int y, int w, int h) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'watermark_removed',
    );
    final outPath = p.join(outPathf.path, "no_watermark.mp4");
    _log("Removing watermark...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf delogo=x=$x:y=$y:w=$w:h=$h "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Watermark removed: $outPath");
      } else {
        _log("Failed to remove watermark.");
      }
    });

    _endProcess();
  }

  /// 8. Overlay: Picture-in-picture, text, images
  Future<void> _overlayVideo(String overlayPath, int x, int y) async {
    if (_videoPath == null || overlayPath.isEmpty)
      return _log("Video or overlay not selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'overlaid_video');
    final outPath = p.join(outPathf.path, "overlaid_output.mp4");
    _log("Overlaying...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -i "$overlayPath" -filter_complex "[0:v][1:v]overlay=$x:$y" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Overlaid: $outPath");
      } else {
        _log("Overlay failed.");
      }
    });

    _endProcess();
  }

  /// 9. Deinterlace: Remove interlacing artifacts
  Future<void> _deinterlaceVideo() async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'deinterlaced_video',
    );
    final outPath = p.join(outPathf.path, "deinterlaced_output.mp4");
    _log("Deinterlacing...");

    await FFmpegKit.execute('-y -i "$_videoPath" -vf yadif "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Deinterlaced: $outPath");
      } else {
        _log("Deinterlace failed.");
      }
    });

    _endProcess();
  }

  /// 10. Stabilize: Reduce camera shake
  Future<void> _stabilizeVideo() async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'stabilized_video',
    );
    final outPath = p.join(outPathf.path, "stabilized_output.mp4");
    _log("Stabilizing (multi-pass)...");

    // First pass
    await FFmpegKit.execute('-y -i "$_videoPath" -vf vidstabdetect -f null -');
    // Second pass (simplified)
    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf vidstabtransform "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Stabilized: $outPath");
      } else {
        _log("Stabilization failed.");
      }
    });

    _endProcess();
  }

  /// 11. Color correction: Adjust brightness, contrast, saturation
  Future<void> _correctVideoColor(
    double brightness,
    double contrast,
    double saturation,
  ) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'color_corrected',
    );
    final outPath = p.join(outPathf.path, "color_corrected.mp4");
    _log("Correcting color...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf eq=brightness=$brightness:contrast=$contrast:saturation=$saturation "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Color corrected: $outPath");
      } else {
        _log("Color correction failed.");
      }
    });

    _endProcess();
  }

  /// 12. Filters: Apply blur, sharpen, noise reduction, etc.
  Future<void> _applyVideoFilters(String filter) async {
    if (_videoPath == null) return _log("No video selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'filtered_video');
    final outPath = p.join(outPathf.path, "filtered_output.mp4");
    _log("Applying filters...");

    await FFmpegKit.execute(
      '-y -i "$_videoPath" -vf "$filter" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Filtered: $outPath");
      } else {
        _log("Filter application failed.");
      }
    });

    _endProcess();
  }

  /// 1. Convert formats (MP3, AAC, FLAC, WAV, OGG, etc.)
  Future<void> _convertAudioFormat(String inputAudioPath) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'converted_audio',
    );
    final outPath = p.join(outPathf.path, "converted_output.mp3");
    _log("Converting audio format...");

    await FFmpegKit.execute('-y -i "$inputAudioPath" "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Converted: $outPath");
      } else {
        _log("Conversion failed.");
      }
    });

    _endProcess();
  }

  /// 2. Extract audio from video files
  // (Same as Basic Operations #2)

  /// 3. Adjust volume (increase/decrease/normalize)
  Future<void> _adjustAudioVolume(String inputAudioPath, double volume) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(
      folderUnderApp: 'volume_adjusted',
    );
    final outPath = p.join(outPathf.path, "volume_output.mp3");
    _log("Adjusting volume...");

    await FFmpegKit.execute(
      '-y -i "$inputAudioPath" -filter:a "volume=$volume" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Volume adjusted: $outPath");
      } else {
        _log("Adjustment failed.");
      }
    });

    _endProcess();
  }

  /// 4. Trim audio segments
  Future<void> _trimAudio(
    String inputAudioPath,
    String startTime,
    String duration,
  ) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'trimmed_audio');
    final outPath = p.join(outPathf.path, "trimmed_output.mp3");
    _log("Trimming audio...");

    await FFmpegKit.execute(
      '-y -i "$inputAudioPath" -ss $startTime -t $duration "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Trimmed: $outPath");
      } else {
        _log("Trim failed.");
      }
    });

    _endProcess();
  }

  /// 5. Merge multiple audio files
  Future<void> _mergeAudioFiles(List<String> audioPaths) async {
    if (audioPaths.isEmpty) return _log("No audio files to merge.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'merged_audio');
    final outPath = p.join(outPathf.path, "merged_output.mp3");
    final concatCmd =
        '${audioPaths.map((path) => '-i "$path"').join(' ')} -filter_complex concat=n=${audioPaths.length}:v=0:a=1 "$outPath"';
    _log("Merging audio...");

    await FFmpegKit.execute('-y $concatCmd').then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Merged: $outPath");
      } else {
        _log("Merge failed.");
      }
    });

    _endProcess();
  }

  /// 6. Add/Remove audio tracks
  // (Handled via combine in Basic Operations #4)

  /// 7. Change sample rate/bitrate
  Future<void> _changeAudioSampleRate(
    String inputAudioPath,
    int sampleRate,
    String bitrate,
  ) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'audio_modified');
    final outPath = p.join(outPathf.path, "modified_output.mp3");
    _log("Changing sample rate/bitrate...");

    await FFmpegKit.execute(
      '-y -i "$inputAudioPath" -ar $sampleRate -ab $bitrate "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Modified: $outPath");
      } else {
        _log("Modification failed.");
      }
    });

    _endProcess();
  }

  /// 8. Apply audio filters (equalizer, compressor, reverb, echo)
  Future<void> _applyAudioFilters(String inputAudioPath, String filter) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'audio_filtered');
    final outPath = p.join(outPathf.path, "filtered_output.mp3");
    _log("Applying audio filters...");

    await FFmpegKit.execute(
      '-y -i "$inputAudioPath" -af "$filter" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Filtered: $outPath");
      } else {
        _log("Filter failed.");
      }
    });

    _endProcess();
  }

  /// 9. Remove/reduce noise
  Future<void> _reduceAudioNoise(String inputAudioPath) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'noise_reduced');
    final outPath = p.join(outPathf.path, "noise_reduced.mp3");
    _log("Reducing noise...");

    await FFmpegKit.execute(
      '-y -i "$inputAudioPath" -af "highpass=f=80,lowpass=f=3400" "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Noise reduced: $outPath");
      } else {
        _log("Noise reduction failed.");
      }
    });

    _endProcess();
  }

  /// 10. Extract specific channels (stereo to mono)
  Future<void> _extractAudioChannels(String inputAudioPath) async {
    if (inputAudioPath.isEmpty) return _log("No audio selected.");
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'mono_audio');
    final outPath = p.join(outPathf.path, "mono_output.mp3");
    _log("Extracting mono channel...");

    await FFmpegKit.execute('-y -i "$inputAudioPath" -ac 1 "$outPath"').then((
      session,
    ) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Mono extracted: $outPath");
      } else {
        _log("Extraction failed.");
      }
    });

    _endProcess();
  }

  /// 11. Generate silence
  Future<void> _generateSilence(double duration) async {
    _startProcess();

    final outPathf = await getTargetDirectory(folderUnderApp: 'silence');
    final outPath = p.join(outPathf.path, "silence.wav");
    _log("Generating silence...");

    await FFmpegKit.execute(
      '-y -f lavfi -i anullsrc=r=44100:cl=mono -t $duration "$outPath"',
    ).then((session) async {
      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        _log("Silence generated: $outPath");
      } else {
        _log("Generation failed.");
      }
    });

    _endProcess();
  }

  Future<void> transcribeToSrt(
    File audioFile, {
    String? languageIso6391,
  }) async {
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final outPathf = await getTargetDirectory(
      folderUnderApp: 'subtitels_original',
    );
    final outPath = p.join(
      outPathf.path,
      '${p.basename(audioFile.path)}${Random().nextInt(10000)}.srt',
    );

    _log("Generating Subtitle from provided file...");

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${Cfg.current.key}'
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path))
      ..fields['model'] = 'whisper-1'
      ..fields['response_format'] = 'srt';

    if (languageIso6391 != null && languageIso6391.isNotEmpty) {
      req.fields['language'] = languageIso6391; // e.g. "ja", "en"
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();
    File(outPath).createSync();
    File(outPath).writeAsStringSync(body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log('OpenAI STT failed ${res.statusCode}: $body');
    }

    // body is plain SRT text when response_format=srt
    return _log(
      'subtitle generated into $outPath  but check that , I now so lazy and not implanted checking if content is correct or not , maybe later doing that',
    );
  }

  Future<void> transcribeVerboseToSrt(
    File audioFile, {
    String? languageIso6391,
    bool includeWordTimestamps = false,
  }) async {
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final outPathf = await getTargetDirectory(
      folderUnderApp: 'subtitels_original',
    );
    final outPath = p.join(
      outPathf.path,
      '${p.basenameWithoutExtension(audioFile.path)}_verbose_${DateTime.now().millisecondsSinceEpoch}.srt',
    );

    _log("Generating Subtitle with verbose JSON (fallback method)...");

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${Cfg.current.key}'
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path))
      ..fields['model'] = 'whisper-1'
      ..fields['response_format'] = 'verbose_json'
      ..fields['timestamp_granularities[]'] = includeWordTimestamps
          ? 'word'
          : 'segment';

    if (languageIso6391 != null && languageIso6391.isNotEmpty) {
      req.fields['language'] = languageIso6391;
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log('OpenAI verbose STT failed ${res.statusCode}: $body');
      _log(
        'OpenAI verbose STT failed ${res.statusCode}: ${body.length > 200 ? body.substring(0, 200) + "..." : body}',
      );
    }

    try {
      final jsonResponse = jsonDecode(body) as Map<String, dynamic>;
      final segments = jsonResponse['segments'] as List?;

      if (segments == null || segments.isEmpty) {
        _log('No segments found in transcription');
        return;
      }

      // Convert segments to SRT
      final srtContent = _segmentsToSrt(segments);

      await File(outPath).writeAsString(srtContent);
      _log(
        'Verbose subtitle generated into $outPath (${segments.length} segments)',
      );

      return;
    } catch (e) {
      _log('Error parsing verbose JSON: $e');
      throw Exception('Failed to parse transcription response: $e');
    }
  }

  String _segmentsToSrt(List<dynamic> segments) {
    final buffer = StringBuffer();

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i] as Map<String, dynamic>;
      final start = (seg['start'] as num).toDouble();
      final end = (seg['end'] as num).toDouble();
      final text = (seg['text'] as String).trim();

      if (text.isEmpty) continue;

      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSrtTime(start)} --> ${_formatSrtTime(end)}');
      buffer.writeln(text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _formatSrtTime(double seconds) {
    final totalMs = (seconds * 1000).round();
    final ms = totalMs % 1000;
    final totalSeconds = totalMs ~/ 1000;
    final s = totalSeconds % 60;
    final totalMinutes = totalSeconds ~/ 60;
    final m = totalMinutes % 60;
    final h = totalMinutes ~/ 60;

    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')},${ms.toString().padLeft(3, '0')}';
  }

  Future<void> translateAudioToEnglishSrt(
    File audioFile, {
    String? prompt,
  }) async {
    final uri = Uri.parse('https://api.openai.com/v1/audio/translations');
    final outPathf = await getTargetDirectory(
      folderUnderApp: 'subtitels_translated',
    );
    final outPath = p.join(
      outPathf.path,
      '${p.basenameWithoutExtension(audioFile.path)}_en_${DateTime.now().millisecondsSinceEpoch}.srt',
    );

    _log("Translating audio to English SRT...");

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${Cfg.current.key}'
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path))
      ..fields['model'] = 'whisper-1'
      ..fields['response_format'] = 'srt';

    if (prompt != null && prompt.isNotEmpty) {
      req.fields['prompt'] = prompt;
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log('OpenAI audio translation failed ${res.statusCode}: $body');
      _log(
        'OpenAI audio translation failed ${res.statusCode}: ${body.length > 200 ? body.substring(0, 200) + "..." : body}',
      );
    }

    // Validate SRT format (basic check)
    if (!body.contains('-->') && !body.contains('\n\n')) {
      _log('Warning: Translation response may not be valid SRT format');
    }

    await File(outPath).writeAsString(body);
    _log('English translation SRT generated into $outPath');

    return;
  }


  Future<void> _showResizeDialog() async {
    final resolutionMap = {
      '1080p': [1920, 1080],
      '720p': [1280, 720],
      '480p': [854, 480],
    };
    String tempResolution = _selectedResolution;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
          title: const Text("Resize / Scale"),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempResolution,
                  dropdownColor: surface,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF14141A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: border),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => tempResolution = value);
                    }
                  },
                  items: resolutionMap.keys
                      .map(
                        (key) => DropdownMenuItem(value: key, child: Text(key)),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  "Target: ${resolutionMap[tempResolution]![0]}x${resolutionMap[tempResolution]![1]}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _selectedResolution = tempResolution);
                final dims = resolutionMap[tempResolution]!;
                _resizeVideo(dims[0], dims[1]);
              },
              child: const Text("Resize"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCropDialog() async {
    final widthController = TextEditingController(
      text: _cropParams['width'].toString(),
    );
    final heightController = TextEditingController(
      text: _cropParams['height'].toString(),
    );
    final xController = TextEditingController(
      text: _cropParams['x'].toString(),
    );
    final yController = TextEditingController(
      text: _cropParams['y'].toString(),
    );

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: border),
            ),
            title: const Text("Crop Video"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField("Width", widthController),
                  const SizedBox(height: 8),
                  _buildDialogTextField("Height", heightController),
                  const SizedBox(height: 8),
                  _buildDialogTextField("X Offset", xController),
                  const SizedBox(height: 8),
                  _buildDialogTextField("Y Offset", yController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final width =
                      int.tryParse(widthController.text) ??
                      _cropParams['width']!;
                  final height =
                      int.tryParse(heightController.text) ??
                      _cropParams['height']!;
                  final x = int.tryParse(xController.text) ?? _cropParams['x']!;
                  final y = int.tryParse(yController.text) ?? _cropParams['y']!;
                  setState(() {
                    _cropParams = {
                      'width': width,
                      'height': height,
                      'x': x,
                      'y': y,
                    };
                  });
                  _cropVideo(width, height, x, y);
                },
                child: const Text("Crop"),
              ),
            ],
          );
        },
      );
    } finally {
      widthController.dispose();
      heightController.dispose();
      xController.dispose();
      yController.dispose();
    }
  }

  Future<void> _showTrimDialog() async {
    final startController = TextEditingController(text: _trimStart);
    final durationController = TextEditingController(text: _trimDuration);

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: border),
            ),
            title: const Text("Trim Video"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField("Start Time (HH:MM:SS)", startController),
                const SizedBox(height: 8),
                _buildDialogTextField("Duration (s)", durationController),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final start = startController.text;
                  final duration = durationController.text;
                  setState(() {
                    _trimStart = start;
                    _trimDuration = duration;
                  });
                  _trimVideo(start, duration);
                },
                child: const Text("Trim"),
              ),
            ],
          );
        },
      );
    } finally {
      startController.dispose();
      durationController.dispose();
    }
  }

  Future<void> _showAudioSplitPartsDialog() async {
    final durationController = TextEditingController(text: _audioSplitDuration);

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF4CAF50)),
            ),
            title: const Text("Split Audio into Parts"),
            content: _buildDialogTextField(
              "Part Duration (s)",
              durationController,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final durationSeconds =
                      int.tryParse(durationController.text) ?? 0;
                  setState(() => _audioSplitDuration = durationController.text);
                  if (_audioPath == null) {
                    _log("Select an audio file first.");
                    return;
                  }
                  if (durationSeconds <= 0) {
                    _log("Enter a valid duration in seconds.");
                    return;
                  }
                  _splitAudioIntoParts(durationSeconds);
                },
                child: const Text("Split"),
              ),
            ],
          );
        },
      );
    } finally {
      durationController.dispose();
    }
  }

  Future<void> _showRotateDialog() async {
    const options = ["90", "180", "270", "Mirror"];
    String tempSelection = _rotateValue;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
          title: const Text("Rotate / Flip"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButtonFormField<String>(
                value: tempSelection,
                dropdownColor: surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF14141A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: border),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempSelection = value);
                  }
                },
                items: options
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _rotateValue = tempSelection);
                _rotateFlipVideo(tempSelection);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSpeedDialog() async {
    double tempSpeed = _speedMultiplier;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: accent),
          ),
          title: const Text("Speed Control"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: accent,
                    inactiveColor: accent.withOpacity(0.3),
                    value: tempSpeed,
                    onChanged: (v) => setDialogState(
                      () => tempSpeed = double.parse(v.toStringAsFixed(2)),
                    ),
                  ),
                  Text(
                    "${tempSpeed.toStringAsFixed(2)}x",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _speedMultiplier = tempSpeed);
                _adjustVideoSpeed(tempSpeed);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showWatermarkDialog() async {
    final xController = TextEditingController(
      text: _watermarkParams['x'].toString(),
    );
    final yController = TextEditingController(
      text: _watermarkParams['y'].toString(),
    );
    final wController = TextEditingController(
      text: _watermarkParams['w'].toString(),
    );
    final hController = TextEditingController(
      text: _watermarkParams['h'].toString(),
    );

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: accent),
            ),
            title: const Text("Remove Watermark"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField("X", xController),
                  const SizedBox(height: 8),
                  _buildDialogTextField("Y", yController),
                  const SizedBox(height: 8),
                  _buildDialogTextField("Width", wController),
                  const SizedBox(height: 8),
                  _buildDialogTextField("Height", hController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final x =
                      int.tryParse(xController.text) ?? _watermarkParams['x']!;
                  final y =
                      int.tryParse(yController.text) ?? _watermarkParams['y']!;
                  final w =
                      int.tryParse(wController.text) ?? _watermarkParams['w']!;
                  final h =
                      int.tryParse(hController.text) ?? _watermarkParams['h']!;
                  setState(() {
                    _watermarkParams = {'x': x, 'y': y, 'w': w, 'h': h};
                  });
                  _removeWatermark(x, y, w, h);
                },
                child: const Text("Remove"),
              ),
            ],
          );
        },
      );
    } finally {
      xController.dispose();
      yController.dispose();
      wController.dispose();
      hController.dispose();
    }
  }

  Future<void> _showOverlayDialog() async {
    String? tempPath = _overlayPath;
    double posX = 0;
    double posY = 0;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: accent),
          ),
          title: const Text("Overlay / PiP"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickOverlayFile((path) {
                      setDialogState(() => tempPath = path);
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: surface,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: border),
                    ),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text("Pick Overlay File"),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tempPath != null
                        ? "Selected: ${p.basename(tempPath!)}"
                        : "No overlay selected.",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Position X",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    min: 0,
                    max: 500,
                    divisions: 50,
                    activeColor: accent,
                    inactiveColor: accent.withOpacity(0.3),
                    value: posX,
                    onChanged: (v) => setDialogState(() => posX = v),
                  ),
                  const Text(
                    "Position Y",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    min: 0,
                    max: 500,
                    divisions: 50,
                    activeColor: accent,
                    inactiveColor: accent.withOpacity(0.3),
                    value: posY,
                    onChanged: (v) => setDialogState(() => posY = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Preview thumbnails not available in this build.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (tempPath == null) {
                  _log("Please select an overlay file first.");
                  return;
                }
                setState(() => _overlayPath = tempPath);
                _overlayVideo(tempPath!, posX.toInt(), posY.toInt());
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showColorDialog() async {
    double brightness = 0;
    double contrast = 1;
    double saturation = 1;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: accent),
          ),
          title: const Text("Color Correction"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSliderRow(
                    label: "Brightness",
                    value: brightness,
                    min: -1,
                    max: 1,
                    onChanged: (v) => setDialogState(() => brightness = v),
                  ),
                  _buildSliderRow(
                    label: "Contrast",
                    value: contrast,
                    min: 0,
                    max: 3,
                    onChanged: (v) => setDialogState(() => contrast = v),
                  ),
                  _buildSliderRow(
                    label: "Saturation",
                    value: saturation,
                    min: 0,
                    max: 3,
                    onChanged: (v) => setDialogState(() => saturation = v),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _correctVideoColor(
                  double.parse(brightness.toStringAsFixed(2)),
                  double.parse(contrast.toStringAsFixed(2)),
                  double.parse(saturation.toStringAsFixed(2)),
                );
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFiltersDialog() async {
    final filters = {
      "Blur": 'gblur=sigma=5',
      "Sharpen": 'unsharp=5:5:1.0:5:5:0.0',
      "Grayscale": 'format=gray',
      "Noise": 'noise=alls=20:allf=t',
    };
    String selected = "Blur";

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: accent),
          ),
          title: const Text("Filters"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButtonFormField<String>(
                value: selected,
                dropdownColor: surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF14141A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: border),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
                items: filters.keys
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _applyVideoFilters(filters[selected]!);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showVolumeDialog() async {
    double tempVolume = _volumeLevel;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4CAF50)),
          ),
          title: const Text("Adjust Volume"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _smallAudioChip("+10 dB", () {
                        setDialogState(() => tempVolume = 3.16);
                      }),
                      _smallAudioChip("+5 dB", () {
                        setDialogState(() => tempVolume = 1.78);
                      }),
                      _smallAudioChip("-10 dB", () {
                        setDialogState(() => tempVolume = 0.32);
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    activeColor: const Color(0xFF4CAF50),
                    inactiveColor: const Color(0xFF4CAF50).withOpacity(0.3),
                    value: tempVolume,
                    onChanged: (v) => setDialogState(
                      () => tempVolume = double.parse(v.toStringAsFixed(2)),
                    ),
                  ),
                  Text(
                    "Multiplier: ${tempVolume.toStringAsFixed(2)}x",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _volumeLevel = tempVolume);
                if (_audioPath == null) {
                  _log("Select an audio file first.");
                  return;
                }
                _adjustAudioVolume(_audioPath!, tempVolume);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAudioTrimDialog() async {
    final startController = TextEditingController(text: _audioTrimStart);
    final durationController = TextEditingController(text: _audioTrimDuration);

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF4CAF50)),
            ),
            title: const Text("Trim Audio"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField("Start Time (HH:MM:SS)", startController),
                const SizedBox(height: 8),
                _buildDialogTextField("Duration (s)", durationController),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final start = startController.text;
                  final duration = durationController.text;
                  setState(() {
                    _audioTrimStart = start;
                    _audioTrimDuration = duration;
                  });
                  if (_audioPath == null) {
                    _log("Select an audio file first.");
                    return;
                  }
                  _trimAudio(_audioPath!, start, duration);
                },
                child: const Text("Trim"),
              ),
            ],
          );
        },
      );
    } finally {
      startController.dispose();
      durationController.dispose();
    }
  }

  Future<void> _showSilenceDialog() async {
    double tempDuration = _silenceDuration;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4CAF50)),
          ),
          title: const Text("Generate Silence"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: const Color(0xFF4CAF50),
                    inactiveColor: const Color(0xFF4CAF50).withOpacity(0.3),
                    value: tempDuration,
                    onChanged: (v) => setDialogState(
                      () => tempDuration = double.parse(v.toStringAsFixed(1)),
                    ),
                  ),
                  Text(
                    "${tempDuration.toStringAsFixed(1)} seconds",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _silenceDuration = tempDuration);
                _generateSilence(tempDuration);
              },
              child: const Text("Generate"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSampleBitrateDialog() async {
    final sampleRates = [44100, 48000, 96000];
    final bitrates = ["128k", "192k", "256k", "320k"];
    int tempRate = _sampleRate;
    String tempBitrate = _bitrate;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4CAF50)),
          ),
          title: const Text("Sample Rate / Bitrate"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: tempRate,
                    dropdownColor: surface,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF14141A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => tempRate = v);
                    },
                    items: sampleRates
                        .map(
                          (rate) => DropdownMenuItem(
                            value: rate,
                            child: Text(
                              "${(rate / 1000).toStringAsFixed(1)} kHz",
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tempBitrate,
                    dropdownColor: surface,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF14141A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: border),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => tempBitrate = v);
                    },
                    items: bitrates
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _sampleRate = tempRate;
                  _bitrate = tempBitrate;
                });
                if (_audioPath == null) {
                  _log("Select an audio file first.");
                  return;
                }
                _changeAudioSampleRate(_audioPath!, tempRate, tempBitrate);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  void _startProcess() {
    setState(() => _isProcessing = true);
  }

  void _endProcess() {
    setState(() => _isProcessing = false);
  }

  @override
  void dispose() {
    _segmentDurationController.dispose();
    _logController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _clearAllFiles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1C24),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text("Clear All Files"),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Text(
                            "Multi-file concat",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Switch(
                            value: _concatMultiSelect,
                            activeColor: accent,
                            onChanged: (v) =>
                                setState(() => _concatMultiSelect = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.touch_app, color: Colors.white54, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Drag & drop files here to quick-select (hint only).",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_recentFiles.isNotEmpty) ...[
                    const Text(
                      "Recent Files",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentFiles
                          .map(
                            (path) => ActionChip(
                              backgroundColor: const Color(0xFF1C1C24),
                              side: const BorderSide(color: border),
                              label: Text(
                                p.basename(path),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              onPressed: () => _chooseRecentDestination(path),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text(
                    "Operations",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: accent.withOpacity(0.7),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.video_settings,
                                color: accent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "VIDEO EDITING",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildActionBtn(
                                "Resize/Scale",
                                Icons.photo_size_select_large,
                                _showResizeDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Crop",
                                Icons.crop,
                                _showCropDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Trim",
                                Icons.timeline,
                                _showTrimDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Rotate/Flip",
                                Icons.rotate_right,
                                _showRotateDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Speed Control",
                                Icons.speed,
                                _showSpeedDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Reverse Video",
                                Icons.replay,
                                _reverseVideo,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Remove Watermark",
                                Icons.blur_circular,
                                _showWatermarkDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Deinterlace",
                                Icons.grid_off,
                                _deinterlaceVideo,
                                enabled: _videoPath != null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _infoChip("Resolution: $_selectedResolution"),
                              _infoChip(
                                "Crop: ${_cropParams['width']}x${_cropParams['height']} @ ${_cropParams['x']},${_cropParams['y']}",
                              ),
                              _infoChip("Trim: $_trimStart / $_trimDuration s"),
                              _infoChip("Rotate: $_rotateValue"),
                              _infoChip(
                                "Speed: ${_speedMultiplier.toStringAsFixed(2)}x",
                              ),
                              _infoChip(
                                "Watermark: x${_watermarkParams['x']} y${_watermarkParams['y']} w${_watermarkParams['w']} h${_watermarkParams['h']}",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          listTileTheme: const ListTileThemeData(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: _audioExpanded,
                          onExpansionChanged: (v) =>
                              setState(() => _audioExpanded = v),
                          leading: const Icon(
                            Icons.audiotrack,
                            color: Color(0xFF4CAF50),
                            size: 18,
                          ),
                          title: const Text(
                            "AUDIO PROCESSING",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildAudioBtn(
                                  "Convert Audio",
                                  Icons.music_note,
                                  () {
                                    if (_audioPath == null) {
                                      _log("Select an audio file first.");
                                      return;
                                    }
                                    _convertAudioFormat(_audioPath!);
                                  },
                                  enabled: _audioPath != null,
                                ),
                               PopupMenuButton<String>(
  icon: Icon(Icons.subtitles, color: Colors.blue),
  itemBuilder: (context) => [
    PopupMenuItem(
      value: 'direct',
      child: Row(
        children: [
          Icon(Icons.subtitles, size: 20),
          SizedBox(width: 8),
          Text('Generate SRT (Direct)'),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'verbose',
      child: Row(
        children: [
          Icon(Icons.subtitles_outlined, size: 20),
          SizedBox(width: 8),
          Text('Generate SRT (Verbose)'),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'translate',
      child: Row(
        children: [
          Icon(Icons.translate, size: 20),
          SizedBox(width: 8),
          Text('Translate to English SRT'),
        ],
      ),
    ),
  ],
  onSelected: (value) {
    if (_audioPath == null) {
      _log("Select an audio file first.");
      return;
    }
    
    final audioFile = File(_audioPath!);
    
    switch (value) {
      case 'direct':
        transcribeToSrt(audioFile);
        break;
      case 'verbose':
        transcribeVerboseToSrt(audioFile);
        break;
      case 'translate':
        translateAudioToEnglishSrt(audioFile);
        break;
    }
  },
  child: Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.subtitles, color: Colors.white),
        SizedBox(width: 8),
        Text(
          'Generate Subtitles',
          style: TextStyle(color: Colors.white),
        ),
        Icon(Icons.arrow_drop_down, color: Colors.white),
      ],
    ),
  ),
),

                                _buildAudioBtn(
                                  "Volume Adjust",
                                  Icons.volume_up,
                                  _showVolumeDialog,
                                  enabled: _audioPath != null,
                                ),
                                _buildAudioBtn(
                                  "Trim Audio",
                                  Icons.content_cut,
                                  _showAudioTrimDialog,
                                  enabled: _audioPath != null,
                                ),
                                _buildAudioBtn(
                                  "Merge Audio",
                                  Icons.library_music,
                                  () => _mergeAudioFiles(
                                    List<String>.from(_mergeAudioPaths),
                                  ),
                                  enabled: _mergeAudioPaths.isNotEmpty,
                                ),
                                _buildAudioBtn(
                                  "Sample Rate/Bitrate",
                                  Icons.equalizer,
                                  _showSampleBitrateDialog,
                                  enabled: _audioPath != null,
                                ),
                                _buildAudioBtn(
                                  "Noise Reduction",
                                  Icons.noise_aware,
                                  () {
                                    if (_audioPath == null) {
                                      _log("Select an audio file first.");
                                      return;
                                    }
                                    _reduceAudioNoise(_audioPath!);
                                  },
                                  enabled: _audioPath != null,
                                ),
                                _buildAudioBtn(
                                  "Extract Mono",
                                  Icons.hearing,
                                  () {
                                    if (_audioPath == null) {
                                      _log("Select an audio file first.");
                                      return;
                                    }
                                    _extractAudioChannels(_audioPath!);
                                  },
                                  enabled: _audioPath != null,
                                ),
                                _buildAudioBtn(
                                  "Generate Silence",
                                  Icons.music_off,
                                  _showSilenceDialog,
                                  enabled: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _mergeAudioPaths.isEmpty
                                        ? "Pick audio files to merge."
                                        : "${_mergeAudioPaths.length} file${_mergeAudioPaths.length == 1 ? "" : "s"} ready.",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickMergeAudioFiles,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1C1C24),
                                    foregroundColor: const Color(0xFF4CAF50),
                                    side: const BorderSide(
                                      color: Color(0xFF4CAF50),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.folder_open, size: 18),
                                  label: const Text("Pick Audio Files"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _infoChip(
                                  _audioPath != null
                                      ? "Current audio: ${p.basename(_audioPath!)}"
                                      : "No audio selected",
                                ),
                                _infoChip(
                                  "Volume: ${_volumeLevel.toStringAsFixed(2)}x",
                                ),
                                _infoChip(
                                  "Trim: $_audioTrimStart / $_audioTrimDuration s",
                                ),
                                _infoChip(
                                  "Rate/BR: ${(_sampleRate / 1000).toStringAsFixed(1)}kHz / $_bitrate",
                                ),
                                _infoChip(
                                  "Silence: ${_silenceDuration.toStringAsFixed(1)}s",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: accent.withOpacity(0.7),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, color: accent, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "VIDEO EFFECTS",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildEffectBtn(
                                "Overlay / PiP",
                                Icons.layers,
                                _showOverlayDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildEffectBtn(
                                "Stabilize Video",
                                Icons.videocam_off,
                                _stabilizeVideo,
                                enabled: _videoPath != null,
                              ),
                              _buildEffectBtn(
                                "Color Correction",
                                Icons.color_lens,
                                _showColorDialog,
                                enabled: _videoPath != null,
                              ),
                              _buildEffectBtn(
                                "Filters",
                                Icons.filter_vintage,
                                _showFiltersDialog,
                                enabled: _videoPath != null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _infoChip(
                                _overlayPath != null
                                    ? "Overlay: ${p.basename(_overlayPath!)}"
                                    : "Overlay: none",
                              ),
                              _infoChip("Effects ready when video selected"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    color: surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: border, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "BASIC OPERATIONS",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildActionBtn(
                                "Convert Media Format",
                                Icons.sync_alt,
                                _convertMediaFormat,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Extract Audio",
                                Icons.headphones,
                                _extractAudioFromVideo,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Extract Video Only",
                                Icons.movie_filter,
                                _extractVideoFromFile,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Combine Audio+Video",
                                Icons.merge_type,
                                () => _combineAudioVideoStreams(_audioPath!),
                                enabled:
                                    _videoPath != null && _audioPath != null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: border, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ADVANCED FILE OPS",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _segmentDurationController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) =>
                                      setState(() => _segmentDuration = value),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Segment Duration (s)",
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF14141A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: border,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildActionBtn(
                                "Split into Segments",
                                Icons.segment,
                                () {
                                  final duration =
                                      int.tryParse(_segmentDuration) ?? 10;
                                  _splitFileIntoSegments(duration);
                                },
                                enabled: _videoPath != null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _concatFiles.isEmpty
                                      ? "No files selected for concatenation."
                                      : "${_concatFiles.length} file${_concatFiles.length == 1 ? "" : "s"} ready to merge.",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _selectConcatFiles,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: surface,
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: border),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.folder_open, size: 18),
                                label: const Text("Pick Files"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildActionBtn(
                                "Concatenate Files",
                                Icons.playlist_add_check,
                                () => _concatenateFiles(
                                  List<String>.from(_concatFiles),
                                ),
                                enabled:
                                    _videoPath != null &&
                                    _concatFiles.isNotEmpty,
                              ),
                              _buildActionBtn(
                                "Change Container",
                                Icons.change_circle,
                                _changeContainerFormat,
                                enabled: _videoPath != null,
                              ),
                              _buildActionBtn(
                                "Probe Media Info",
                                Icons.info,
                                _probeMediaInfo,
                                enabled: _videoPath != null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                        "Split Audio (Parts)",
                        Icons.call_split,
                        _showAudioSplitPartsDialog,
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
    final hasFile = path != null;
    final info = path != null ? _fileInfo[path] : null;
    if (hasFile && info == null) _loadFileInfo(path!);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                            ? p.basename(path)
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    info ?? (hasFile ? "Fetching info..." : "No file selected"),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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

  Widget _buildEffectBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled && !_isProcessing ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [accent, Color(0xFF00E5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: enabled && !_isProcessing ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _buildAudioBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled && !_isProcessing ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: enabled && !_isProcessing ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _smallAudioChip(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: const Color(0xFF1C1C24),
      side: const BorderSide(color: Color(0xFF4CAF50)),
      label: Text(label, style: const TextStyle(color: Color(0xFF4CAF50))),
      onPressed: onTap,
    );
  }

  Widget _buildDialogTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF14141A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Slider(
          min: min,
          max: max,
          activeColor: accent,
          inactiveColor: accent.withOpacity(0.3),
          value: value,
          onChanged: onChanged,
        ),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
