import 'dart:convert';
import 'dart:typed_data';

class AudioUtils {
  static bool looksLikeWav(Uint8List b) {
    if (b.length < 12) return false;
    return b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x41 &&
        b[10] == 0x56 &&
        b[11] == 0x45;
  }

  static Uint8List pcm16ToWav(
    Uint8List pcm, {
    int sampleRate = 24000,
    int channels = 1,
  }) {
    final dataLen = pcm.length;
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final header = BytesBuilder();

    void writeStr(String s) => header.add(ascii.encode(s));
    void write32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      header.add(b.buffer.asUint8List());
    }

    void write16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      header.add(b.buffer.asUint8List());
    }

    writeStr('RIFF');
    write32(36 + dataLen);
    writeStr('WAVE');
    writeStr('fmt ');
    write32(16);
    write16(1);
    write16(channels);
    write32(sampleRate);
    write32(byteRate);
    write16(blockAlign);
    write16(16);
    writeStr('data');
    write32(dataLen);

    final out = BytesBuilder();
    out.add(header.toBytes());
    out.add(pcm);
    return out.toBytes();
  }

  static Uint8List ensureWav(
    Uint8List bytes, {
    int sampleRate = 24000,
    int channels = 1,
  }) {
    return looksLikeWav(bytes)
        ? bytes
        : pcm16ToWav(bytes, sampleRate: sampleRate, channels: channels);
  }

  static String dataUriAudioWavBase64(String b64) =>
      'data:audio/wav;base64,$b64';
  static String dataUriImageBase64(String mime, String b64) =>
      'data:$mime;base64,$b64';

  static int totalSizeBytes(Iterable<int> sizes) =>
      sizes.fold(0, (a, b) => a + b);
  static bool underLimitBytes(
    Iterable<int> sizes, {
    int maxBytes = 30 * 1024 * 1024,
  }) {
    return totalSizeBytes(sizes) <= maxBytes;
  }
}
