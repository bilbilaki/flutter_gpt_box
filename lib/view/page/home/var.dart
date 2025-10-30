part of 'home.dart';

final inputCtrl = TextEditingController();
final _chatScrollCtrl = ScrollController()
  ..addListener(() {
    Fns.throttle(_chatFabRN.notify, id: 'chat_fab_rn', duration: 30);
  });
final _historyScrollCtrl = ScrollController()
  ..addListener(_locateHistoryListener);
final _pageCtrl = PageController(initialPage: _curPage.value.index);
final _screenshotCtrl = ScreenshotController();

final _timeRN = RNode();

/// Map for [ChatHistoryItem]'s [RNode]
final _chatItemRNMap = <String, RNode>{};

/// Audio / Image / File path
final _filesPicked = <String>[].vn;

/// Body chat view
final _chatRN = RNode();
final _historyRN = RNode();
final _appbarTitleVN = nvn<String>();
final _locateHistoryBtn = false.vn;
final _chatFabRN = RNode();
final _homeBottomRN = RNode();

var allHistories = <String, ChatHistory>{};
ChatHistory? _curChat;
final _curChatId = 'fake-non-exist-id'.vn..addListener(_onCurChatIdChanged);
void _onCurChatIdChanged() {
  _curChat = allHistories[_curChatId.value];
  _chatRN.notify();
  _appbarTitleVN.value = _curChat?.name;
}

/// Folder management
final _allFolders = <String, ChatFolder>{}.vn;

/// [ChatHistory.id] or [ChatHistoryItem.id]
final _loadingChatIds = <String>{}.vn;
final _chatStreamSubs = <String, StreamSubscription>{};

final _curPage = HomePageEnum.chat.vn;

final _imeFocus = FocusNode();

final _isDesktop = false.vn..addListener(_onIsWideChanged);
void _onIsWideChanged() {
  _curPage.value = HomePageEnum.chat;
}

/// Mobile has higher density.
final _historyItemHeight = isDesktop ? 73.0 : 79.0;

/// The pixel tollerance
final _historyLocateTollerance = _historyItemHeight / 3;

const _durationShort = Durations.short4;
const _durationMedium = Durations.medium1;

// ignore: unused_element
KeyboardCtrlListener? _keyboardSendListener;

/// If current `ts > this + duration`, then no delete confirmation required.
var _noChatDeleteConfirmTS = 0;

final _autoHideCtrl = AutoHideController();

var _userStoppedScroll = false;

class _StreamingPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _stopped = false;
  File? _currentFile;
  int _segmentIndex = 0;
  final Directory _tmpDir;

  _StreamingPlayer._(this._tmpDir);

  static Future<_StreamingPlayer> create() async {
    final d = await Directory.systemTemp.createTemp('tts_stream_');
    return _StreamingPlayer._(d);
  }

  /// Append bytes for a segment and play sequentially.
  /// Caller should ensure bytes form a valid WAV (or PCM turned into a WAV header prior).
  Future<void> appendAndPlay(Uint8List bytes, {bool isLast = false}) async {
    if (_stopped) return;
    final path = p.join(_tmpDir.path, 'seg_${_segmentIndex++}.wav');
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    // If nothing playing, play immediately, otherwise queue by waiting
    if (!_playing) {
      _playFileAndWait(f);
    }
  }

  Future<void> _playFileAndWait(File f) async {
    _playing = true;
    _currentFile = f;
    try {
      await _player.play(DeviceFileSource(f.path));
      // wait until completion or stop called
      // audioplayers emits onPlayerComplete if needed - but simple await above usually returns immediately
      // Best: listen to player state
      final completer = Completer<void>();
      void handleComplete(_) {
        completer.complete();
      }

      _player.onPlayerComplete.listen(handleComplete);
      await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      // cleanup
      try { await f.delete(); } catch (_) {}
    } catch (_) {}
    _playing = false;
  }

  Future<void> stop() async {
    _stopped = true;
    try { await _player.stop(); } catch (_) {}
    // cleanup tmp dir
    try { if (_tmpDir.existsSync()) _tmpDir.deleteSync(recursive: true); } catch (_) {}
  }
}


/// Returns the current local time as a [DateTime] object.
DateTime getDeviceLocalTime() {
  return DateTime.now();
}

/// Returns the current local time as a formatted string.
///
/// [showSeconds] determines whether seconds should be included in the output.
/// The format will be 'HH:mm' or 'HH:mm:ss'.
String getDeviceLocalTimeString({bool showSeconds = true}) {
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  final second = now.second.toString().padLeft(2, '0');

  if (showSeconds) {
    return '$hour:$minute:$second';
  } else {
    return '$hour:$minute';
  }
}

/// Returns the current local date as a formatted string.
///
/// The format will be 'YYYY-MM-DD'.
String getDeviceLocalDateString() {
  final now = DateTime.now();
  final year = now.year.toString();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

/// Returns the current local date and time as a single formatted string.
///
/// [showSeconds] determines whether seconds should be included in the time part.
/// The format will be 'YYYY-MM-DD HH:mm' or 'YYYY-MM-DD HH:mm:ss'.
String getDeviceLocalDateTimeString({bool showSeconds = true}) {
  final datePart = getDeviceLocalDateString();
  final timePart = getDeviceLocalTimeString(showSeconds: showSeconds);
  return '$datePart $timePart';
}