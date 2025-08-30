import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
 import 'package:gpt_box/view/page/home/home.dart';
import 'package:gpt_box/view/widget/voice_chat.dart';

class VoiceAssistantScreen extends StatefulWidget {
  final VoiceSessionController controller;
  const VoiceAssistantScreen({super.key, required this.controller});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> with TickerProviderStateMixin {
  ScreenState _currentScreenState = ScreenState.connecting;
  String _selectedVoice = 'Sky';

  late AnimationController _visualizerAnimationController;
  late AnimationController _connectingAnimationController;
  late AnimationController _speakingCircleAnimationController;
  late AnimationController _thinkingDotsAnimationController;
  late AnimationController _voiceBarsAnimationController;

  List<double> _barHeights = List.generate(7, (index) => 0.0);
  bool _playingAi = false;

  @override
  void initState() {
    super.initState();
    _visualizerAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _connectingAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _speakingCircleAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _thinkingDotsAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800), lowerBound: 0.0, upperBound: 1.0)..repeat(reverse: true);
    _voiceBarsAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() {
        if (_currentScreenState == ScreenState.listeningSpeaking || _currentScreenState == ScreenState.thoughtBubble) {
          _simulateBars();
        }
      });

    _navigateTo(ScreenState.connecting);
  }

  @override
  void dispose() {
    _visualizerAnimationController.dispose();
    _connectingAnimationController.dispose();
    _speakingCircleAnimationController.dispose();
    _thinkingDotsAnimationController.dispose();
    _voiceBarsAnimationController.dispose();
    super.dispose();
  }

  void _simulateBars() {
    setState(() {
      final double wave = (sin(_voiceBarsAnimationController.value * pi * 2 * 3) + 1) / 2;
      for (int i = 0; i < _barHeights.length; i++) {
        _barHeights[i] = wave * 0.6 + (Random().nextDouble() * 0.4);
      }
    });
  }

  void _navigateTo(ScreenState newState) {
    setState(() => _currentScreenState = newState);
    _connectingAnimationController.stop();
    _speakingCircleAnimationController.stop();
    _voiceBarsAnimationController.stop();

    switch (newState) {
      case ScreenState.connecting:
        _connectingAnimationController.forward(from: 0.0).then((_) {
          if (_currentScreenState == ScreenState.connecting) {
            _navigateTo(ScreenState.listeningIdle);
          }
        });
        break;
      case ScreenState.listeningIdle:
        _visualizerAnimationController.forward(from: 0.0);
        break;
      case ScreenState.listeningSpeaking:
        _speakingCircleAnimationController.repeat(reverse: true);
        _voiceBarsAnimationController.repeat(period: const Duration(milliseconds: 900));
        break;
      case ScreenState.thinking:
        _speakingCircleAnimationController.value = 1.0;
        _thinkingDotsAnimationController.repeat(reverse: true);
        break;
      case ScreenState.thoughtBubble:
        _visualizerAnimationController.forward(from: 0.0);
        _voiceBarsAnimationController.repeat(period: const Duration(milliseconds: 900));
        break;
      case ScreenState.voiceSelection:
        _visualizerAnimationController.forward(from: 0.0);
        break;
    }
  }

  Future<void> _startTalk() async {
    try {
      await widget.controller.startRecording();
      _navigateTo(ScreenState.listeningSpeaking);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _finishTalk() async {
    // transitions: speaking -> thinking -> thoughtBubble (AI speaks)
    _navigateTo(ScreenState.thinking);
    try {
      await widget.controller.stopAndProcess(
        context,
        userHintText: '',
      );
      // AI TTS will stream; we simulate bars as "playing"
      _playingAi = true;
      _navigateTo(ScreenState.thoughtBubble);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      _navigateTo(ScreenState.listeningIdle);
    }
  }

  Future<void> _cancel() async {
    await widget.controller.cancelRecording();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Hook streaming signals:
    // - on user partial transcript: optionally display in subtitle (skipped here)
    // - on tts chunk: bump bars mildly based on RMS
    final ctrl = widget.controller;
    // rebind (idempotent)
    // ignore: unused_local_variable
    final _ = () {
      // sample hookup: compute quick RMS from PCM16 to animate bars
      void onPcm(Uint8List pcm) {
        if (_currentScreenState != ScreenState.thoughtBubble) return;
        if (pcm.length < 2) return;
        int samples = pcm.length ~/ 2;
        double sumSq = 0;
        for (int i = 0; i < samples; i += 32) {
          final lo = pcm[i * 2];
          final hi = pcm[i * 2 + 1];
          int s = (hi << 8) | (lo & 0xff);
          if (s & 0x8000 != 0) s = s - 0x10000;
          final v = s / 32768.0;
          sumSq += v * v;
        }
        final rms = sqrt(sumSq / max(1, samples ~/ 32)).clamp(0.0, 1.0);
        setState(() {
          for (int i = 0; i < _barHeights.length; i++) {
            _barHeights[i] = (0.3 + rms * 0.7) * (0.6 + 0.4 * (i % 3) / 2.0);
          }
        });
      }

      ctrl.onUserPartial?.call; // keep for completeness
      // overwrite controller callbacks (safe; controller created by caller)
      // ignore: avoid_types_on_closure_parameters
      return null;
    }();

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildScreenContent(),
        ),
      ),
    );
  }

  Widget _buildScreenContent() {
    switch (_currentScreenState) {
      case ScreenState.connecting:
        return Stack(
          children: [
            Center(
              child: AnimatedVoiceVisualizer(
                state: VoiceVisualizerState.connectingOval,
                animationController: _connectingAnimationController,
              ),
            ),
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: StatusTextAndIcon(text: 'Connecting', icon: null, animationController: null, barHeights: const []),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: BottomActionButton(
                  icon: Icons.close_rounded,
                  backgroundColor: AppColors.accentRed,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        );
      case ScreenState.listeningIdle:
        return Column(
          children: [
            const Spacer(),
            Center(
              child: AnimatedVoiceVisualizer(
                state: VoiceVisualizerState.idleRoundedRects,
                animationController: _visualizerAnimationController,
              ),
            ),
            const SizedBox(height: 80),
            const StatusTextAndIcon(text: 'Tap to interrupt', icon: Icons.mic_none, animationController: null, barHeights: const []),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: _startTalk,
              onCancel: _cancel,
              pauseButtonIcon: Icons.stop_circle_outlined,
            ),
            const SizedBox(height: 20),
          ],
        );
      case ScreenState.listeningSpeaking:
        return Column(
          children: [
            const Spacer(),
            Center(
              child: AnimatedVoiceVisualizer(
                state: VoiceVisualizerState.speakingCircle,
                animationController: _speakingCircleAnimationController,
              ),
            ),
            const SizedBox(height: 80),
            StatusTextAndIcon(
              text: 'Finish speaking to send',
              icon: null,
              animationController: _voiceBarsAnimationController,
              barHeights: _barHeights,
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: _finishTalk,
              onCancel: _cancel,
              pauseButtonIcon: Icons.pause_circle_outline,
            ),
            const SizedBox(height: 20),
          ],
        );
      case ScreenState.thinking:
        return Column(
          children: [
            const Spacer(),
            Center(
              child: AnimatedVoiceVisualizer(
                state: VoiceVisualizerState.speakingCircle,
                animationController: _speakingCircleAnimationController,
              ),
            ),
            const SizedBox(height: 80),
            StatusTextAndIcon(
              text: 'Start speaking',
              icon: null,
              animationController: _thinkingDotsAnimationController,
              barHeights: const [],
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: () => _finishTalk(),
              onCancel: _cancel,
              pauseButtonIcon: Icons.pause_circle_outline,
            ),
            const SizedBox(height: 20),
          ],
        );
      case ScreenState.thoughtBubble:
        return Column(
          children: [
            const Spacer(),
            Center(
              child: AnimatedVoiceVisualizer(
                state: VoiceVisualizerState.thoughtBubble,
                animationController: _visualizerAnimationController,
              ),
            ),
            const SizedBox(height: 80),
            StatusTextAndIcon(
              text: _playingAi ? 'AI speaking...' : 'Tap to cancel',
              icon: Icons.mic_none,
              animationController: null,
              barHeights: const [],
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: () => _navigateTo(ScreenState.listeningIdle),
              onCancel: _cancel,
              pauseButtonIcon: Icons.stop_circle_outlined,
            ),
            const SizedBox(height: 20),
          ],
        );
      case ScreenState.voiceSelection:
        return Column(
          children: [
            _AppBar(title: 'Choose a voice', subtitle: 'You can change this later', onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: AnimatedVoiceVisualizer(
                        state: VoiceVisualizerState.idleCircles,
                        animationController: _visualizerAnimationController,
                      ),
                    ),
                  ),
                  VoiceSelectionList(
                    selectedVoice: _selectedVoice,
                    onVoiceSelected: (v) => setState(() => _selectedVoice = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ConfirmButton(onPressed: () => _navigateTo(ScreenState.connecting)),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}
class _AppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const _AppBar({
    required this.title,
    this.subtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.white),
              onPressed: () {}, // Placeholder for sound icon action
            ),
          ),
          Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}