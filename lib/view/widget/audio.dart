part of '../page/home/home.dart';

// ignore: must_be_immutable
class AudioPlayerTile extends StatefulWidget {
   Uint8List bytes;
   bool autoPlay;
   File? file;

   AudioPlayerTile({
    super.key,
    required this.bytes,
    this.autoPlay = false,
    this.file,
  });

  @override
  State<AudioPlayerTile> createState() => _AudioPlayerTileState();
}

class _AudioPlayerTileState extends State<AudioPlayerTile> {
  AudioPlayer _player = AudioPlayer();
  IOS9SiriWaveformController _siriController = IOS9SiriWaveformController(
    amplitude: 0.0,
    speed: 0.1,
  );

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();

    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playerState = state);
      _updateWaveform();
    });

    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });

    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _player.setSource(BytesSource(widget.bytes));
      if (ss.voicePlayedUntilNow.get() == false) {
        ss.voicePlayedUntilNow.set(true);

        await _play();
      }
    } catch (e) {
      debugPrint("Error setting audio source: $e");
      debugPrint("Stack trace: ${StackTrace.current}");
    }
  }

  void _updateWaveform() {
    _siriController.amplitude = _isPlaying ? 0.7 : 0.0;
  }

  Future<void> _play() async {
    if (_playerState == PlayerState.completed ||
        _playerState == PlayerState.stopped) {
      await _player.play(BytesSource(widget.bytes));
      setState(() {
        _playerState = PlayerState.playing;
      });
      // await _player.resume();
    } else if (_playerState == PlayerState.paused) {
      await _player.resume();
      setState(() {
        _playerState = PlayerState.playing;
      });

    } else if (_playerState == PlayerState.playing) {
      await _player.pause();
      setState(() {
        _playerState = PlayerState.paused;
      });
    }
  }

  // Future<void> _pause() async {
  //   await _player.pause();
  // }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin:  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding:  EdgeInsets.all(12.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              ),
              iconSize: 48,
             // color: theme.primaryColor,
              onPressed: _play,
            ),
             SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SiriWaveform.ios9(
                    controller: _siriController,
                    options:  IOS9SiriWaveformOptions(
                      height: 60,
                      width: double.infinity,
                    ),
                  ),
                   SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                       // style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        _formatDuration(_duration),
                    //    style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// import 'dart:async';
// import 'dart:io';

// import 'package:audioplayers/audioplayers.dart';
// import 'package:fl_lib/fl_lib.dart';
// import 'package:flutter/material.dart';
// import 'package:gpt_box/data/model/app/audio_play.dart';
// import 'package:gpt_box/data/res/l10n.dart';

// final _audioPlayer = AudioPlayer();
// // Map for audio player value notifiers which stores the current playing status
// final _audioPlayerMap = <String, ValueNotifier<AudioPlayStatus>>{};
// String? _nowPlayingId;

// final class AudioCard extends StatefulWidget {
//   static final loadingMap = <String, Completer>{};

//   final String path;
//   final String id;
//   final bool buildSlider;
//   final void Function()? onDelete;

//   const AudioCard({
//     super.key,
//     required this.id,
//     required this.path,
//     this.buildSlider = true,
//     this.onDelete,
//   });

//   @override
//   State<AudioCard> createState() => _AudioCardState();

//   static void listenAudioPlayer() {
//     _audioPlayer.onPositionChanged.listen((position) {
//       final status = _audioPlayerMap[_nowPlayingId];
//       if (status == null) return;
//       status.value = status.value.copyWith(played: position.inMilliseconds);
//     });
//     _audioPlayer.onPlayerStateChanged.listen((state) {
//       final status = _audioPlayerMap[_nowPlayingId];
//       if (status == null) return;
//       if (state == PlayerState.completed) {
//         _nowPlayingId = null;
//         status.value = status.value.copyWith(playing: false, played: 0);
//       }
//     });

//     /// This functions works wrong
//     // _audioPlayer.onPlayerComplete.listen((_) {
//     //   final status = _audioPlayerMap[_nowPlayingId];
//     //   if (status == null) return;
//     //   _nowPlayingId = null;
//     //   status.value = status.value.copyWith(playing: false, played: 0);
//     //   print('Audio completed');
//     // });
//   }
// }

// class _AudioCardState extends State<AudioCard> {
//   File get _file => File(widget.path);

//   @override
//   Widget build(BuildContext context) {
//     return FutureWidget(
//       future: () async {
//         await AudioCard.loadingMap[widget.id]?.future;
//         AudioCard.loadingMap.remove(widget.id);
//         if (!await _file.exists()) {
//           throw l10n.fileNotFound(widget.path);
//         }

//         var durationInited = true;
//         final listenable = _audioPlayerMap.putIfAbsent(
//           widget.id,
//           () {
//             durationInited = false;
//             return ValueNotifier(AudioPlayStatus(id: widget.id));
//           },
//         );
//         if (!durationInited) {
//           final player = AudioPlayer();
//           player.setSource(DeviceFileSource(widget.path));
//           final duration = await player.getDuration();

//           listenable.value = listenable.value.copyWith(
//             total: duration?.inMilliseconds ?? 0,
//           );
//         }
//         return listenable;
//       }(),
//       error: (error, trace) {
//         return Text('$error');
//       },
//       loading: SizedLoading.medium,
//       success: (listenable) {
//         if (listenable == null) return UIs.placeholder;
//         return _buildItem(listenable);
//       },
//     );
//   }

//   Widget _buildItem(ValueNotifier<AudioPlayStatus> listenable) {
//     return ValueListenableBuilder(
//       valueListenable: listenable,
//       builder: (_, val, __) {
//         if (!widget.buildSlider) {
//           return Column(
//             mainAxisSize: MainAxisSize.min,
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               UIs.height7,
//               Text(
//                 widget.id,
//                 style: UIs.text13Bold,
//                 maxLines: 1,
//                 overflow: TextOverflow.fade,
//               ),
//               UIs.height7,
//               Text(listenable.value.progress),
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     icon: val.playing
//                         ? const Icon(Icons.stop, size: 19)
//                         : const Icon(Icons.play_arrow, size: 19),
//                     onPressed: () => _onTapAudioCtrl(
//                       widget.id,
//                       listenable,
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () async {
//                       _audioPlayerMap.remove(widget.id);
//                       listenable.dispose();
//                       await _file.delete();
//                       widget.onDelete?.call();
//                     },
//                     icon: const Icon(Icons.delete),
//                   ),
//                 ],
//               )
//             ],
//           ).cardx;
//         }

//         final sliderVal = () {
//           if (val.total == 0) return 0.0;
//           return val.played / val.total;
//         }();
//         return ListTile(
//           leading: IconButton(
//             icon: val.playing
//                 ? const Icon(Icons.stop, size: 19)
//                 : const Icon(Icons.play_arrow, size: 19),
//             onPressed: () => _onTapAudioCtrl(widget.id, listenable),
//           ),
//           title: Slider(
//             value: sliderVal,
//             onChanged: (v) {
//               final nowMilli = (val.total * v).toInt();
//               final duration = Duration(milliseconds: nowMilli);
//               _audioPlayer.seek(duration);
//               listenable.value = val.copyWith(played: nowMilli);
//             },
//           ),
//         ).cardx;
//       },
//     );
//   }

//   void _onTapAudioCtrl(
//     String id,
//     ValueNotifier<AudioPlayStatus> listenable,
//   ) async {
//     final val = listenable.value;
//     if (val.playing) {
//       _audioPlayer.pause();
//       _nowPlayingId = null;
//       listenable.value = val.copyWith(playing: false);
//     } else {
//       if (_nowPlayingId == id) {
//         _audioPlayer.resume();
//         _nowPlayingId = id;
//         listenable.value = val.copyWith(playing: true);
//         return;
//       } else {
//         if (_nowPlayingId != null) {
//           final last = _audioPlayerMap[_nowPlayingId];
//           if (last != null) {
//             _audioPlayer.pause();
//             _nowPlayingId = null;
//             last.value = last.value.copyWith(playing: false);
//           }
//         }
//       }
//       _nowPlayingId = id;
//       listenable.value = val.copyWith(playing: true);
//       _audioPlayer.play(DeviceFileSource(_file.absolute.path));
//     }
//   }
// }
