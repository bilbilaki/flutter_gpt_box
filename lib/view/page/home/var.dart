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

var _allHistories = <String, ChatHistory>{};
ChatHistory? _curChat;
final _curChatId = 'fake-non-exist-id'.vn..addListener(_onCurChatIdChanged);
void _onCurChatIdChanged() {
  _curChat = _allHistories[_curChatId.value];
  _chatRN.notify();
  _appbarTitleVN.value = _curChat?.name;
}

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