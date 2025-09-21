import 'dart:convert';
import 'dart:io';

import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:path/path.dart' as p;
import 'package:record/record.dart';


final AudioRecorder _audioRecorder = AudioRecorder();

Future<bool> ensureRecordPermission() async {
  try {
    return await _audioRecorder.hasPermission();
  } catch (_) {
    return false;
  }
}

Future<String?> quickRecordWav({
  Duration duration = const Duration(seconds: 6),
}) async {
  if (!await ensureRecordPermission()) return null;
  final dir = Directory.systemTemp.createTempSync('rec_');
  final path = p.join(
    dir.path,
    'input_${DateTime.now().millisecondsSinceEpoch}.wav',
  );
  await _audioRecorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      bitRate: 128000,
    ),
    path: path,
  );
  try {
    await Future.delayed(duration);
  } finally {
    try {
      await _audioRecorder.stop();
    } catch (_) {}
  }
  return File(path).existsSync() ? path : null;
}

bool isImagePath(String path) {
  final ext = p.extension(path).toLowerCase();
  return [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
  ].contains(ext);
}

bool isAudioPath(String path) {
  final ext = p.extension(path).toLowerCase();
  return [
    '.wav',
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.oga',
    '.webm',
  ].contains(ext);
}

String mimeFromExt(String path) {
  final ext = p.extension(path).toLowerCase();
  switch (ext) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.bmp':
      return 'image/bmp';
    case '.heic':
      return 'image/heic';
    case '.heif':
      return 'image/heif';
       case '.pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

Future<String> fileToBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}

openai.ChatCompletionAudioVoice getOpenAIVoice(String voiceParams) {
  switch (voiceParams.toLowerCase()) {
    case 'alloy':
      return openai.ChatCompletionAudioVoice.alloy;
    case 'ash':
      return openai.ChatCompletionAudioVoice.ash;
    case 'echo':
      return openai.ChatCompletionAudioVoice.echo;
    case 'ballad':
      return openai.ChatCompletionAudioVoice.ballad;
    case 'sage':
      return openai.ChatCompletionAudioVoice.sage;
    case 'coral':
      return openai.ChatCompletionAudioVoice.coral;
    case 'shimmer':
      return openai.ChatCompletionAudioVoice.shimmer;
    default:
      return openai.ChatCompletionAudioVoice.alloy;
  }
}

Future<openai.ChatCompletionAudioVoice> getCurrentVoice() async {
  final dv = 'echo';
  final vv = getOpenAIVoice(dv);
  return vv;
}

Future<String> imagePathToDataUrl(String path) async {
  final mime = mimeFromExt(path);
  final b64 = await fileToBase64(path);
  return 'data:$mime;base64,$b64';
}

Future<openai.ChatCompletionMessageContentPart> contentFromPath(String path) async {
  if (isImagePath(path)) {
    final dataUrl = await imagePathToDataUrl(path);
    return openai.ChatCompletionMessageContentPart.image(imageUrl: openai.ChatCompletionMessageImageUrl(url: dataUrl));
  }
  return openai.ChatCompletionMessageContentPart.audio(inputAudio: openai.ChatCompletionMessageInputAudio(data: await saveBase64ToFile(path),format: openai.ChatCompletionMessageInputAudioFormat.wav));
}

Future<String> saveBase64ToFile(
  String base64Data, {
  String ext = '.wav',
}) async {
  final bytes = base64Decode(base64Data);
  final dir = await Directory.systemTemp.createTemp('oai_audio_');
  final path = p.join(
    dir.path,
    'out_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

Future<String?> ensureAudioInputPath(List<String> files) async {
  final audio = isAudioPath(files.first) == true ? files.first: null;
  if (audio != null) return audio;
  // fallback quick record if nothing provided
  return await quickRecordWav();
}
