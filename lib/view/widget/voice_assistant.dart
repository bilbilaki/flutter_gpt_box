// import 'dart:math';
// import 'dart:typed_data';

// import 'package:flutter/material.dart';
//  import 'package:gpt_box/view/page/home/home.dart';
// import 'package:gpt_box/view/widget/voice_chat.dart';

// class VoiceAssistantScreen extends StatefulWidget {
//   final VoiceSessionController controller;
//   const VoiceAssistantScreen({super.key, required this.controller});

//   @override
//   State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
// }

// class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> with TickerProviderStateMixin {
//   ScreenState _currentScreenState = ScreenState.connecting;
//   String _selectedVoice = 'Sky';

//   late AnimationController _visualizerAnimationController;
//   late AnimationController _connectingAnimationController;
//   late AnimationController _speakingCircleAnimationController;
//   late AnimationController _thinkingDotsAnimationController;
//   late AnimationController _voiceBarsAnimationController;

//   List<double> _barHeights = List.generate(7, (index) => 0.0);
//   bool _playingAi = false;

//   @override
//   void initState() {
//     super.initState();
//     _visualizerAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
//     _connectingAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
//     _speakingCircleAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
//     _thinkingDotsAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800), lowerBound: 0.0, upperBound: 1.0)..repeat(reverse: true);
//     _voiceBarsAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
//       ..addListener(() {
//         if (_currentScreenState == ScreenState.listeningSpeaking || _currentScreenState == ScreenState.thoughtBubble) {
//           _simulateBars();
//         }
//       });

//     _navigateTo(ScreenState.connecting);
//   }

//   @override
//   void dispose() {
//     _visualizerAnimationController.dispose();
//     _connectingAnimationController.dispose();
//     _speakingCircleAnimationController.dispose();
//     _thinkingDotsAnimationController.dispose();
//     _voiceBarsAnimationController.dispose();
//     super.dispose();
//   }

//   void _simulateBars() {
//     setState(() {
//       final double wave = (sin(_voiceBarsAnimationController.value * pi * 2 * 3) + 1) / 2;
//       for (int i = 0; i < _barHeights.length; i++) {
//         _barHeights[i] = wave * 0.6 + (Random().nextDouble() * 0.4);
//       }
//     });
//   }

//   void _navigateTo(ScreenState newState) {
//     setState(() => _currentScreenState = newState);
//     _connectingAnimationController.stop();
//     _speakingCircleAnimationController.stop();
//     _voiceBarsAnimationController.stop();

//     switch (newState) {
//       case ScreenState.connecting:
//         _connectingAnimationController.forward(from: 0.0).then((_) {
//           if (_currentScreenState == ScreenState.connecting) {
//             _navigateTo(ScreenState.listeningIdle);
//           }
//         });
//         break;
//       case ScreenState.listeningIdle:
//         _visualizerAnimationController.forward(from: 0.0);
//         break;
//       case ScreenState.listeningSpeaking:
//         _speakingCircleAnimationController.repeat(reverse: true);
//         _voiceBarsAnimationController.repeat(period: const Duration(milliseconds: 900));
//         break;
//       case ScreenState.thinking:
//         _speakingCircleAnimationController.value = 1.0;
//         _thinkingDotsAnimationController.repeat(reverse: true);
//         break;
//       case ScreenState.thoughtBubble:
//         _visualizerAnimationController.forward(from: 0.0);
//         _voiceBarsAnimationController.repeat(period: const Duration(milliseconds: 900));
//         break;
//       case ScreenState.voiceSelection:
//         _visualizerAnimationController.forward(from: 0.0);
//         break;
//     }
//   }

//   Future<void> _startTalk() async {
//     try {
//       await widget.controller.startRecording();
//       _navigateTo(ScreenState.listeningSpeaking);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
//       }
//     }
//   }

//   Future<void> _finishTalk() async {
//     // transitions: speaking -> thinking -> thoughtBubble (AI speaks)
//     _navigateTo(ScreenState.thinking);
//     try {
//       await widget.controller.stopAndProcess(
//         context,
//         userHintText: '',
//       );
//       // AI TTS will stream; we simulate bars as "playing"
//       _playingAi = true;
//       _navigateTo(ScreenState.thoughtBubble);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
//       }
//       _navigateTo(ScreenState.listeningIdle);
//     }
//   }

//   Future<void> _cancel() async {
//     await widget.controller.cancelRecording();
//     if (mounted) Navigator.of(context).pop();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Hook streaming signals:
//     // - on user partial transcript: optionally display in subtitle (skipped here)
//     // - on tts chunk: bump bars mildly based on RMS
//     final ctrl = widget.controller;
//     // rebind (idempotent)
//     // ignore: unused_local_variable
//     final _ = () {
//       // sample hookup: compute quick RMS from PCM16 to animate bars
//       void onPcm(Uint8List pcm) {
//         if (_currentScreenState != ScreenState.thoughtBubble) return;
//         if (pcm.length < 2) return;
//         int samples = pcm.length ~/ 2;
//         double sumSq = 0;
//         for (int i = 0; i < samples; i += 32) {
//           final lo = pcm[i * 2];
//           final hi = pcm[i * 2 + 1];
//           int s = (hi << 8) | (lo & 0xff);
//           if (s & 0x8000 != 0) s = s - 0x10000;
//           final v = s / 32768.0;
//           sumSq += v * v;
//         }
//         final rms = sqrt(sumSq / max(1, samples ~/ 32)).clamp(0.0, 1.0);
//         setState(() {
//           for (int i = 0; i < _barHeights.length; i++) {
//             _barHeights[i] = (0.3 + rms * 0.7) * (0.6 + 0.4 * (i % 3) / 2.0);
//           }
//         });
//       }

//       ctrl.onUserPartial?.call; // keep for completeness
//       // overwrite controller callbacks (safe; controller created by caller)
//       // ignore: avoid_types_on_closure_parameters
//       return null;
//     }();

//     return Scaffold(
//       body: SafeArea(
//         child: AnimatedSwitcher(
//           duration: const Duration(milliseconds: 300),
//           child: _buildScreenContent(),
//         ),
//       ),
//     );
//   }

//   Widget _buildScreenContent() {
//     switch (_currentScreenState) {
//       case ScreenState.connecting:
//         return Stack(
//           children: [
//             Center(
//               child: AnimatedVoiceVisualizer(
//                 state: VoiceVisualizerState.connectingOval,
//                 animationController: _connectingAnimationController,
//               ),
//             ),
//             Positioned(
//               bottom: 120,
//               left: 0,
//               right: 0,
//               child: StatusTextAndIcon(text: 'Connecting', icon: null, animationController: null, barHeights: const []),
//             ),
//             Positioned(
//               bottom: 40,
//               left: 0,
//               right: 0,
//               child: Center(
//                 child: BottomActionButton(
//                   icon: Icons.close_rounded,
//                   backgroundColor: AppColors.accentRed,
//                   onPressed: () => Navigator.of(context).pop(),
//                 ),
//               ),
//             ),
//           ],
//         );
//       case ScreenState.listeningIdle:
//         return Column(
//           children: [
//             const Spacer(),
//             Center(
//               child: AnimatedVoiceVisualizer(
//                 state: VoiceVisualizerState.idleRoundedRects,
//                 animationController: _visualizerAnimationController,
//               ),
//             ),
//             const SizedBox(height: 80),
//             const StatusTextAndIcon(text: 'Tap to interrupt', icon: Icons.mic_none, animationController: null, barHeights: const []),
//             const Spacer(),
//             BottomActionButtons(
//               onRecordPause: _startTalk,
//               onCancel: _cancel,
//               pauseButtonIcon: Icons.stop_circle_outlined,
//             ),
//             const SizedBox(height: 20),
//           ],
//         );
//       case ScreenState.listeningSpeaking:
//         return Column(
//           children: [
//             const Spacer(),
//             Center(
//               child: AnimatedVoiceVisualizer(
//                 state: VoiceVisualizerState.speakingCircle,
//                 animationController: _speakingCircleAnimationController,
//               ),
//             ),
//             const SizedBox(height: 80),
//             StatusTextAndIcon(
//               text: 'Finish speaking to send',
//               icon: null,
//               animationController: _voiceBarsAnimationController,
//               barHeights: _barHeights,
//             ),
//             const Spacer(),
//             BottomActionButtons(
//               onRecordPause: _finishTalk,
//               onCancel: _cancel,
//               pauseButtonIcon: Icons.pause_circle_outline,
//             ),
//             const SizedBox(height: 20),
//           ],
//         );
//       case ScreenState.thinking:
//         return Column(
//           children: [
//             const Spacer(),
//             Center(
//               child: AnimatedVoiceVisualizer(
//                 state: VoiceVisualizerState.speakingCircle,
//                 animationController: _speakingCircleAnimationController,
//               ),
//             ),
//             const SizedBox(height: 80),
//             StatusTextAndIcon(
//               text: 'Start speaking',
//               icon: null,
//               animationController: _thinkingDotsAnimationController,
//               barHeights: const [],
//             ),
//             const Spacer(),
//             BottomActionButtons(
//               onRecordPause: () => _finishTalk(),
//               onCancel: _cancel,
//               pauseButtonIcon: Icons.pause_circle_outline,
//             ),
//             const SizedBox(height: 20),
//           ],
//         );
//       case ScreenState.thoughtBubble:
//         return Column(
//           children: [
//             const Spacer(),
//             Center(
//               child: AnimatedVoiceVisualizer(
//                 state: VoiceVisualizerState.thoughtBubble,
//                 animationController: _visualizerAnimationController,
//               ),
//             ),
//             const SizedBox(height: 80),
//             StatusTextAndIcon(
//               text: _playingAi ? 'AI speaking...' : 'Tap to cancel',
//               icon: Icons.mic_none,
//               animationController: null,
//               barHeights: const [],
//             ),
//             const Spacer(),
//             BottomActionButtons(
//               onRecordPause: () => _navigateTo(ScreenState.listeningIdle),
//               onCancel: _cancel,
//               pauseButtonIcon: Icons.stop_circle_outlined,
//             ),
//             const SizedBox(height: 20),
//           ],
//         );
//       case ScreenState.voiceSelection:
//         return Column(
//           children: [
//             _AppBar(title: 'Choose a voice', subtitle: 'You can change this later', onClose: () => Navigator.of(context).pop()),
//             Expanded(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Center(
//                       child: AnimatedVoiceVisualizer(
//                         state: VoiceVisualizerState.idleCircles,
//                         animationController: _visualizerAnimationController,
//                       ),
//                     ),
//                   ),
//                   VoiceSelectionList(
//                     selectedVoice: _selectedVoice,
//                     onVoiceSelected: (v) => setState(() => _selectedVoice = v),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(20.0),
//                     child: ConfirmButton(onPressed: () => _navigateTo(ScreenState.connecting)),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         );
//     }
//   }
// }
// class _AppBar extends StatelessWidget {
//   final String title;
//   final String? subtitle;
//   final VoidCallback? onClose;

//   const _AppBar({
//     required this.title,
//     this.subtitle,
//     this.onClose,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           Align(
//             alignment: Alignment.centerLeft,
//             child: IconButton(
//               icon: const Icon(Icons.volume_up, color: Colors.white),
//               onPressed: () {}, // Placeholder for sound icon action
//             ),
//           ),
//           Column(
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 17,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               if (subtitle != null)
//                 Text(
//                   subtitle!,
//                   style: TextStyle(
//                     color: AppColors.textSecondary,
//                     fontSize: 13,
//                   ),
//                 ),
//             ],
//           ),
//           Align(
//             alignment: Alignment.centerRight,
//             child: IconButton(
//               icon: const Icon(Icons.close, color: Colors.white),
//               onPressed: onClose,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// part of '../page/home/home.dart';
// // --- Placeholder for AppColors ---
// // --- End Placeholder ---

// /// Represents the major screen states in the voice assistant UI flow.
// enum ScreenState {
//   connecting,
//   listeningIdle,
//   listeningSpeaking,
//   thinking,
//   thoughtBubble, // AI is speaking
//   voiceSelection,
// }

// class VoiceAssistantScreen extends StatefulWidget {
//   const VoiceAssistantScreen({super.key});

//   @override
//   State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
// }

// class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
//     with TickerProviderStateMixin {
//   // A placeholder chatId. In a real app, this would come from your chat management system.

//   late final VoiceSessionController1 _controller;
//   ScreenState _currentScreenState = ScreenState.connecting;
//   String _selectedVoice = 'Sky';

//   late AnimationController _visualizerAnimationController;
//   late AnimationController _connectingAnimationController;
//   late AnimationController _speakingCircleAnimationController;
//   late AnimationController _thinkingDotsAnimationController;
//   late AnimationController _voiceBarsAnimationController;

//   List<double> _barHeights = List.generate(7, (index) => 0.0);
//   bool _isAiSpeaking = false;

//   @override
//   void initState() {
//     super.initState();

//     // Correctly initialize the controller and pass the UI callbacks.
//     _controller = VoiceSessionController1(
//       onUserPartial: (transcript) {
//         // Optional: Display partial user transcript in the UI.
//         // For now, we just log it.
//         print("Partial Transcript: $transcript");
//       },
//       onTtsChunk: (pcmChunk) {
//         // This is the hook for visualizing the AI's voice.
//         _updateVisualizerWithPcm(pcmChunk);
//       },
//     );

//     _visualizerAnimationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );
//     _connectingAnimationController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     );
//     _speakingCircleAnimationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _thinkingDotsAnimationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     )..repeat(reverse: true);
//     _voiceBarsAnimationController =
//         AnimationController(
//           vsync: this,
//           duration: const Duration(milliseconds: 200),
//         )..addListener(() {
//           // Simulate user's voice input visualization
//           if (_currentScreenState == ScreenState.listeningSpeaking) {
//             _simulateUserSpeakingBars();
//           }
//         });

//     _navigateTo(ScreenState.connecting);
//   }

//   @override
//   void dispose() {
//     _visualizerAnimationController.dispose();
//     _connectingAnimationController.dispose();
//     _speakingCircleAnimationController.dispose();
//     _thinkingDotsAnimationController.dispose();
//     _voiceBarsAnimationController.dispose();
//     super.dispose();
//   }

//   /// Simulates fluctuating bars for when the user is speaking.
//   void _simulateUserSpeakingBars() {
//     setState(() {
//       final double wave =
//           (sin(_voiceBarsAnimationController.value * pi * 2 * 3) + 1) / 2;
//       for (int i = 0; i < _barHeights.length; i++) {
//         _barHeights[i] = wave * 0.6 + (Random().nextDouble() * 0.4);
//       }
//     });
//   }

//   /// Updates the visualizer bars based on real PCM data from the AI's TTS.
//   void _updateVisualizerWithPcm(Uint8List pcm) {
//     if (_currentScreenState != ScreenState.thoughtBubble || !mounted) return;
//     if (pcm.length < 2) return;

//     int samples = pcm.length ~/ 2;
//     double sumSq = 0;
//     // Downsample for performance
//     for (int i = 0; i < samples; i += 32) {
//       final lo = pcm[i * 2];
//       final hi = pcm[i * 2 + 1];
//       int s = (hi << 8) | lo;
//       if (s > 32767) s -= 65536; // Convesigned 16-bit
//       final v = s / 32768.0;
//       sumSq += v * v;
//     }
//     final rms = sqrt(sumSq / max(1, samples ~/ 32)).clamp(0.0, 1.0);

//     setState(() {
//       for (int i = 0; i < _barHeights.length; i++) {
//         // Create a visually pleasing, slightly varied bar height based on RMS
//         _barHeights[i] = (0.3 + rms * 0.7) * (0.6 + 0.4 * ((i + 1) % 3) / 2.0);
//       }
//     });
//   }

//   void _navigateTo(ScreenState newState) {
//     if (!mounted) return;
//     setState(() => _currentScreenState = newState);

//     _connectingAnimationController.stop();
//     _speakingCircleAnimationController.stop();
//     _voiceBarsAnimationController.stop();
//     _visualizerAnimationController.stop();

//     switch (newState) {
//       case ScreenState.connecting:
//         _connectingAnimationController.forward(from: 0.0).then((_) {
//           if (_currentScreenState == ScreenState.connecting) {
//             _navigateTo(ScreenState.listeningIdle);
//           }
//         });
//         break;
//       case ScreenState.listeningIdle:
//         _visualizerAnimationController.forward(from: 0.0);
//         break;
//       case ScreenState.listeningSpeaking:
//         _speakingCircleAnimationController.repeat(reverse: true);
//         _voiceBarsAnimationController.repeat(
//           period: const Duration(milliseconds: 900),
//         );
//         break;
//       case ScreenState.thinking:
//         _speakingCircleAnimationController.value = 1.0;
//         _thinkingDotsAnimationController.repeat(reverse: true);
//         break;
//       case ScreenState.thoughtBubble:
//         _visualizerAnimationController.forward(from: 0.0);
//         // The voice bars are now driven by real data via _updateVisualizerWithPcm
//         break;
//       case ScreenState.voiceSelection:
//         _visualizerAnimationController.forward(from: 0.0);
//         break;
//     }
//   }

//   Future<void> _startTalk() async {
//     try {
//       await _controller.startRecording();
//       _navigateTo(ScreenState.listeningSpeaking);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error: $e')));
//       }
//     }
//   }

//   Future<void> _finishTalk() async {
//     _navigateTo(ScreenState.thinking);
//     try {
//       // The controller now handles the entire voice turn.
//       await _controller.stopAndProcess(context);

//       // The UI will transition to the thought bubble state while the AI processes and speaks.
//       setState(() => _isAiSpeaking = true);
//       _navigateTo(ScreenState.thoughtBubble);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error: $e')));
//       }
//       _navigateTo(ScreenState.listeningIdle);
//     }
//   }

//   Future<void> _cancel() async {
//     await _controller.cancelRecording();
//     if (mounted) Navigator.of(context).pop();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.primaryBackground,
//       body: SafeArea(
//         child: AnimatedSwitcher(
//           duration: const Duration(milliseconds: 300),
//           child: _buildScreenContent(),
//         ),
//       ),
//     );
//   }

//   Widget _buildScreenContent() {
//     // Using a key ensures AnimatedSwitcher correctly handles transitions
//     switch (_currentScreenState) {
//       case ScreenState.connecting:
//         return _buildConnectingUI();
//       case ScreenState.listeningIdle:
//         return _buildListeningIdleUI();
//       case ScreenState.listeningSpeaking:
//         return _buildListeningSpeakingUI();
//       case ScreenState.thinking:
//         return _buildThinkingUI();
//       case ScreenState.thoughtBubble:
//         return _buildThoughtBubbleUI();
//       case ScreenState.voiceSelection:
//         return _buildVoiceSelectionUI();
//     }
//   }

//   // --- UI Builder Methods for each state ---

//   Widget _buildConnectingUI() {
//     return Stack(
//       key: const ValueKey('connecting'),
//       children: [
//         Center(
//           child: AnimatedVoiceVisualizer(
//             state: VoiceVisualizerState.connectingOval,
//             animationController: _connectingAnimationController,
//           ),
//         ),
//         Positioned(
//           bottom: 120,
//           left: 0,
//           right: 0,
//           child: StatusTextAndIcon(text: 'Connecting'),
//         ),
//         Positioned(
//           bottom: 40,
//           left: 0,
//           right: 0,
//           child: Center(
//             child: BottomActionButton(
//               icon: Icons.close_rounded,
//               backgroundColor: AppColors.accentRed,
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildListeningIdleUI() {
//     return Column(
//       key: const ValueKey('listeningIdle'),
//       children: [
//         const Spacer(),
//         Center(
//           child: AnimatedVoiceVisualizer(
//             state: VoiceVisualizerState.idleRoundedRects,
//             animationController: _visualizerAnimationController,
//           ),
//         ),
//         const SizedBox(height: 80),
//         const StatusTextAndIcon(text: 'Tap to speak', icon: Icons.mic_none),
//         const Spacer(),
//         BottomActionButtons(
//           onRecordPause: _startTalk,
//           onCancel: _cancel,
//           recordButtonIcon: Icons.mic,
//         ),
//         const SizedBox(height: 20),
//       ],
//     );
//   }

//   Widget _buildListeningSpeakingUI() {
//     return Column(
//       key: const ValueKey('listeningSpeaking'),
//       children: [
//         const Spacer(),
//         Center(
//           child: AnimatedVoiceVisualizer(
//             state: VoiceVisualizerState.speakingCircle,
//             animationController: _speakingCircleAnimationController,
//           ),
//         ),
//         const SizedBox(height: 80),
//         StatusTextAndIcon(text: 'Listening...', barHeights: _barHeights),
//         const Spacer(),
//         BottomActionButtons(
//           onRecordPause: _finishTalk,
//           onCancel: _cancel,
//           recordButtonIcon: Icons.stop_circle_outlined,
//         ),
//         const SizedBox(height: 20),
//       ],
//     );
//   }

//   Widget _buildThinkingUI() {
//     return Column(
//       key: const ValueKey('thinking'),
//       children: [
//         const Spacer(),
//         Center(
//           child: AnimatedVoiceVisualizer(
//             state: VoiceVisualizerState.speakingCircle,
//             animationController: _speakingCircleAnimationController,
//           ),
//         ),
//         const SizedBox(height: 80),
//         StatusTextAndIcon(
//           text: 'Thinking...',
//           animationController: _thinkingDotsAnimationController,
//         ),
//         const Spacer(),
//         BottomActionButtons(
//           onRecordPause: () {}, // Disable button while thinking
//           onCancel: _cancel,
//           recordButtonIcon: Icons.hourglass_empty,
//         ),
//         const SizedBox(height: 20),
//       ],
//     );
//   }

//   Widget _buildThoughtBubbleUI() {
//     return Column(
//       key: const ValueKey('thoughtBubble'),
//       children: [
//         const Spacer(),
//         Center(
//           child: AnimatedVoiceVisualizer(
//             state: VoiceVisualizerState.thoughtBubble,
//             animationController: _visualizerAnimationController,
//           ),
//         ),
//         const SizedBox(height: 80),
//         StatusTextAndIcon(
//           text: _isAiSpeaking ? 'AI is speaking...' : 'Done',
//           barHeights: _barHeights, // Driven by real data
//         ),
//         const Spacer(),
//         BottomActionButtons(
//           onRecordPause: () => _navigateTo(ScreenState.listeningIdle),
//           onCancel: _cancel,
//           recordButtonIcon: Icons.replay,
//         ),
//         const SizedBox(height: 20),
//       ],
//     );
//   }

//   Widget _buildVoiceSelectionUI() {
//     return Column(
//       key: const ValueKey('voiceSelection'),
//       children: [
//         AppBar(
//           title: const Text('Choose a voice'),
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.close),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//           ],
//         ),
//         Expanded(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Center(
//                   child: AnimatedVoiceVisualizer(
//                     state: VoiceVisualizerState.idleCircles,
//                     animationController: _visualizerAnimationController,
//                   ),
//                 ),
//               ),
//               VoiceSelectionList(
//                 selectedVoice: _selectedVoice,
//                 onVoiceSelected: (v) => setState(() => _selectedVoice = v),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: ConfirmButton(
//                   onPressed: () => _navigateTo(ScreenState.connecting),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
// // FILE: lib/features/chat/voice_chat_logic.dart

// // --- End Placeholder Imports ---


// /// Controller to manage a voice chat session from the UI.
// /// It handles recording audio and interfacing with the backend logic.
// class VoiceSessionController1 {
//   final void Function(String partialUserTranscript)? onUserPartial;
//   final void Function(Uint8List pcmChunk)? onTtsChunk;

//   final AudioRecorder _audioRecorder = AudioRecorder();
//   String? _recPath;

//   VoiceSessionController1({
//     this.onUserPartial,
//     this.onTtsChunk,
//   });

//   Future<void> startRecording() async {
//     if (!await _audioRecorder.hasPermission()) {
//       throw Exception('Microphone permission denied');
//     }
//     final dir = await Directory.systemTemp.createTemp('live_rec_');
//     _recPath = p.join(
//       dir.path,
//       'live_${DateTime.now().millisecondsSinceEpoch}.wav',
//     );
//     await _audioRecorder.start(
//       const RecordConfig(
//         encoder: AudioEncoder.wav,
//         sampleRate: 16000,
//         bitRate: 128000,
//       ),
//       path: _recPath!,
//     );
//   }

//   Future<void> stopAndProcess(
//     BuildContext context, {
//     String userHintText = '',
//   }) async {
//     try {
//       await _audioRecorder.stop();
//     } catch (_) {
//       // Ignore errors if already stopped
//     }
//     final path = _recPath;
//     _recPath = null;
//     if (path == null || !File(path).existsSync()) {
//       throw Exception('No audio captured');
//     }

//     // Delegate to the main logic handler for parallel STT and AI response.
//     await _onLiveVoiceTurnParallel1(
//       context,
//       audioPath: path,
//       userHintText: userHintText,
//       onLiveUserTranscript: onUserPartial,
//       onLiveTtsAudio: onTtsChunk,
//     );
//   }

//   Future<void> cancelRecording() async {
//     try {
//       if (await _audioRecorder.isRecording()) {
//         await _audioRecorder.stop();
//       }
//     } catch (_) {
//       // Ignore errors
//     }
//     _recPath = null;
//   }

//   void dispose() {
//     _audioRecorder.dispose();
//   }
// }

// /// Handles a live voice turn by running STT and the audio-in model in parallel.
// /// This provides a faster, more responsive voice chat experience.
// Future<void> _onLiveVoiceTurnParallel1(
//   BuildContext context,
//  {
//   required String audioPath,
//   String userHintText = '',
//   void Function(String partialUserTranscript)? onLiveUserTranscript,
//   void Function(Uint8List pcmChunk)? onLiveTtsAudio,
// }) async {
//   if (!_validChatCfg(context)) return;


//   _autoHideCtrl.autoHideEnabled = false;

//   // Add a user placeholder with the raw audio file to history immediately

//   // 1) Start STT (Speech-to-Text) in the background
//   final sttCompleter = Completer<String>();
//   StreamSubscription? sttSub;
  
//   // 2) Start audio-in model stream in parallel

//   StreamSubscription? modelSub;
//   final assistantAudioBase64Buff = StringBuffer();
//   final assistantTranscriptBuff = StringBuffer();
//   final assistantTextBuff = StringBuffer();

//   try {
//     final stream = await _callAudioInModelStream1(
//       audioPath: audioPath,
//     );
//     modelSub = stream.listen(
//       (eve) async {
//         final delta = eve.choices.firstOrNull?.delta;
//         if (delta == null) return;

//         // Handle assistant text content
//         final content = delta.content;
//         if (content != null && content.isNotEmpty) {
//           assistantTextBuff.write(content);
//           final merged = assistantTextBuff.toString();
//           final parts = splitDataUrisToChatContents(merged);
//         }

//         // Handle streaming audio data
//         final a = delta.audio;
//         if (a?.data != null && a!.data!.isNotEmpty) {
//           assistantAudioBase64Buff.write(a.data);
//           if (a.transcript != null && a.transcript!.isNotEmpty) {
//             assistantTranscriptBuff.write(a.transcript);
//           }
//           try {
//             final pcm = base64Decode(a.data!);
//             onLiveTtsAudio?.call(pcm);
//           } catch (_) {
//             // Ignore base64 decoding errors on partial data
//           }
//         }
//       },
//       onDone: () async {
//         // Save accumulated audio to a file
//         if (assistantAudioBase64Buff.isNotEmpty) {
//           try {
//             final outPath = await _saveBase64ToFile1(
//               assistantAudioBase64Buff.toString(),
//               ext: '.wav',
//             );
//           } catch (e) {
//             Loggers.app.warning('Save assistant audio failed: $e');
//           }
//         }

//         // Finalize assistant text content
//         final combinedText = assistantTranscriptBuff.toString().trim().isNotEmpty
//             ? assistantTranscriptBuff.toString()
//             : assistantTextBuff.toString();
//         if (combinedText.trim().isNotEmpty) {
//         }

//         // Cleanup
//         BakSync.instance.sync();
//       },
//       onError: (e, s) => _onErr(e, s, '','Audio-in model stream'),
//     );
//   } catch (e, s) {
//     _onErr(e, s,',' , 'Start audio-in model stream');
//   }

//   // 3) Finalize user item text once STT is complete
//   final finalUt = await sttCompleter.future;
//   final text = (finalUt.trim().isEmpty) ? userHintText.trim() : finalUt.trim();
//   if (text.isNotEmpty) {
//       final newContent = ChatContent.text(text);

//   // **FIXED:** Removed the premature cancellation of the model subscription.
//   // The subscription is now stored in `_chatStreamSubs` and will be cancelled
//   // only when the chat is stopped, an error occurs, or the user navigates away.
// }}

// // --- Other necessary audio functions from the original file (unchanged unless noted) ---

// // Future<Stream> _callAudioInModelStream1({
// //   required String audioPath,
// //   openai.ChatCompletionAudioVoice? voice,
// // }) async {
// //   String modelId = Cfg.current.trnscrbModel ?? 'gpt-4o-mini-audio-preview';

// //   if (!File(audioPath).existsSync()) {
// //     throw Exception('Audio not found: $audioPath');
// //   }
// //   final inputB64 = await _fileToBase641(audioPath);
// //   final userMsg = openai.ChatCompletionMessage.user(
// //     content: openai.ChatCompletionUserMessageContent.parts([
// //       openai.ChatCompletionMessageContentPart.audio(
// //         inputAudio: openai.ChatCompletionMessageInputAudio(
// //           data: inputB64,
// //           format: openai.ChatCompletionMessageInputAudioFormat.wav,
// //         ),
// //       ),
// //     ]),
// //   );

// //   final req = openai.CreateChatCompletionRequest(
// //     model: openai.ChatCompletionModel.modelId(modelId),
// //     modalities: [openai.ChatCompletionModality.text, openai.ChatCompletionModality.audio],
// //     messages: [ userMsg],
// //     audio: openai.ChatCompletionAudioOptions(
// //       voice: voice ?? await getCurrentVoice(),
// //       format: openai.ChatCompletionAudioFormat.pcm16,
// //     ),
// //     temperature: aiSettings.temperature,
// //   );

// //   return Cfg.client.createChatCompletionStream(request: req);
// // }

// class _SttStreamResult1 {
//   final StreamSubscription sub;
//   final Completer<String> done;
//   _SttStreamResult1({required this.sub, required this.done});
// }

// Future<_SttStreamResult1> _streamTranscribeAudio1({
//   required String audioPath,
//   void Function(String partial)? onPartial,
// }) async {
//   String modelId = Cfg.current.trnscrbModel ?? 'gpt-4o-mini-transcribe';
//   final done = Completer<String>();
//   final accum = StringBuffer();

//   if (!File(audioPath).existsSync()) {
//     throw Exception('Audio not found: $audioPath');
//   }
//   final inputB64 = await _fileToBase641(audioPath);
//   final req = openai.CreateChatCompletionRequest(
//     model: openai.ChatCompletionModel.modelId(modelId),
//     modalities: [openai.ChatCompletionModality.text, openai.ChatCompletionModality.audio],
//     messages: [
//       openai.ChatCompletionMessage.user(
//         content: openai.ChatCompletionUserMessageContent.parts([
//           openai.ChatCompletionMessageContentPart.audio(
//             inputAudio: openai.ChatCompletionMessageInputAudio(
//               data: inputB64,
//               format: openai.ChatCompletionMessageInputAudioFormat.wav,
//             ),
//           ),
//         ]),
//       ),
//     ],
//   );

//   final stream = Cfg.client.createChatCompletionStream(request: req);
//   final sub = stream.listen(
//     (eve) {
//       final c = eve.choices.firstOrNull?.delta?.content;
//       if (c != null && c.isNotEmpty) {
//         accum.write(c);
//         onPartial?.call(accum.toString());
//       }
//     },
//     onDone: () => done.complete(accum.toString()),
//     onError: (e, s) {
//       Loggers.app.warning('STT stream: $e');
//       done.completeError(e, s);
//     },
//     cancelOnError: true,
//   );

//   return _SttStreamResult1(sub: sub, done: done);
// }

// // Helper function placeholders
// Future<String> _fileToBase641(String path) async {
//   final bytes = await File(path).readAsBytes();
//   return base64Encode(bytes);
// }

// Future<String> _saveBase64ToFile1(String base64Data, {String ext = '.wav'}) async {
//   final bytes = base64Decode(base64Data);
//   final dir = await Directory.systemTemp.createTemp('oai_audio_');
//   final path = p.join(dir.path, 'out_${DateTime.now().millisecondsSinceEpoch}$ext');
//   await File(path).writeAsBytes(bytes, flush: true);
//   return path;
// }


// enum VoiceVisualizerState {
//   idleCircles,
//   idleRoundedRects,
//   connectingOval,
//   speakingCircle,
//   thoughtBubble,
// }

// // --- Reusable UI Components ---

// /// A reusable button for the bottom action bar.
// class BottomActionButton extends StatelessWidget {
//   final IconData icon;
//   final VoidCallback onPressed;
//   final Color backgroundColor;
//   final double size;
//   final double iconSize;

//   const BottomActionButton({
//     super.key,
//     required this.icon,
//     required this.onPressed,
//     required this.backgroundColor,
//     this.size = 64.0,
//     this.iconSize = 32.0,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: backgroundColor,
//       shape: const CircleBorder(),
//       child: InkWell(
//         onTap: onPressed,
//         customBorder: const CircleBorder(),
//         child: SizedBox(
//           width: size,
//           height: size,
//           child: Icon(icon, color: Colors.white, size: iconSize),
//         ),
//       ),
//     );
//   }
// }

// /// The main bottom action button layout.
// class BottomActionButtons extends StatelessWidget {
//   final VoidCallback onRecordPause;
//   final VoidCallback onCancel;
//   final IconData recordButtonIcon;

//   const BottomActionButtons({
//     super.key,
//     required this.onRecordPause,
//     required this.onCancel,
//     required this.recordButtonIcon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 40.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           const SizedBox(width: 56), // Spacer to balance the center
//           BottomActionButton(
//             icon: recordButtonIcon,
//             onPressed: onRecordPause,
//             backgroundColor: AppColors.cardBackground,
//           ),
//           BottomActionButton(
//             icon: Icons.close_rounded,
//             backgroundColor: AppColors.accentRed,
//             onPressed: onCancel,
//             size: 56.0,
//             iconSize: 28.0,
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// A large confirmation button.
// class ConfirmButton extends StatelessWidget {
//   final VoidCallback onPressed;

//   const ConfirmButton({super.key, required this.onPressed});

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton(
//         onPressed: onPressed,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.buttonPrimary,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
//         ),
//         child: Text(
//           'Confirm',
//           style: TextStyle(
//             color: AppColors.buttonText,
//             fontSize: 17,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//     );
//   }
// }
// class AppColors {
//   static const Color primaryBackground = Color(0xFF140D17);
//   static const Color cardBackground = Color(0xFF201625);
//   static const Color selectedCardBackground = Color(0xFF2E2333);
//   static const Color accentRed = Color(0xFFDA2A39);
//   static const Color buttonPrimary = Color(0xFFB1A2BB);
//   static const Color buttonText = Color(0xFF201625);
//   static const Color textLight = Color(0xFFF0F0F0);
//   static const Color textSecondary = Color(0xFFA0A0A0);
// }

// /// Displays status text and a dynamic icon (mic, bars, or thinking dots).
// class StatusTextAndIcon extends StatelessWidget {
//   final String text;
//   final IconData? icon;
//   final List<double> barHeights;
//   final AnimationController? animationController;

//   const StatusTextAndIcon({
//     super.key,
//     required this.text,
//     this.icon,
//     this.barHeights = const [],
//     this.animationController,
//   });

//   @override
//   Widget build(BuildContext context) {
//     Widget iconWidget;
//     if (icon != null) {
//       iconWidget = Icon(icon, color: AppColors.textLight, size: 24);
//     } else if (barHeights.isNotEmpty) {
//       iconWidget = _VoiceBars(barHeights: barHeights);
//     } else if (animationController != null) {
//       iconWidget = AnimatedBuilder(
//         animation: animationController!,
//         builder: (context, child) => _ThinkingDots(animationValue: animationController!.value),
//       );
//     } else {
//       iconWidget = const SizedBox(height: 24);
//     }

//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         SizedBox(height: 24, child: iconWidget),
//         const SizedBox(height: 8),
//         Text(
//           text,
//           style: TextStyle(
//             color: AppColors.textSecondary,
//             fontSize: 15,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }
// }

// /// Custom painter for animating voice level bars.
// class _VoiceBars extends StatelessWidget {
//   final List<double> barHeights;
//   const _VoiceBars({required this.barHeights});

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: const Size(80, 24),
//       painter: _VoiceBarsPainter(barHeights),
//     );
//   }
// }

// class _VoiceBarsPainter extends CustomPainter {
//   final List<double> barHeights;
//   _VoiceBarsPainter(this.barHeights);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()..color = AppColors.textLight;
//     const double barWidth = 6.0;
//     const double spacing = 4.0;
//     const int numBars = 7;
//     final double totalWidth = (barWidth * numBars) + (spacing * (numBars - 1));
//     final double startX = (size.width - totalWidth) / 2;

//     for (int i = 0; i < numBars; i++) {
//       double height = (barHeights.length > i ? barHeights[i] * size.height : 2.0).clamp(2.0, size.height);
//       final rrect = RRect.fromRectAndRadius(
//         Rect.fromLTWH(startX + i * (barWidth + spacing), size.height - height, barWidth, height),
//         const Radius.circular(3.0),
//       );
//       canvas.drawRRect(rrect, paint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _VoiceBarsPainter oldDelegate) => true;
// }

// /// Custom painter for animating thinking dots.
// class _ThinkingDots extends StatelessWidget {
//   final double animationValue;
//   const _ThinkingDots({required this.animationValue});

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: const Size(80, 24),
//       painter: _ThinkingDotsPainter(animationValue),
//     );
//   }
// }

// class _ThinkingDotsPainter extends CustomPainter {
//   final double animationValue;
//   _ThinkingDotsPainter(this.animationValue);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()..color = AppColors.textLight;
//     const double dotRadius = 4.0;
//     const double spacing = 8.0;
//     const int numDots = 5;
//     final double totalWidth = (dotRadius * 2 * numDots) + (spacing * (numDots - 1));
//     final double startX = (size.width - totalWidth) / 2 + dotRadius;
//     final double centerY = size.height / 2;

//     for (int i = 0; i < numDots; i++) {
//       final double sineOffset = sin(animationValue * 2 * pi + (i * pi / (numDots - 1)));
//       final double yOffset = -4 * (sineOffset + 1) / 2;
//       canvas.drawCircle(Offset(startX + i * (dotRadius * 2 + spacing), centerY + yOffset), dotRadius, paint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _ThinkingDotsPainter oldDelegate) => oldDelegate.animationValue != animationValue;
// }

// /// The main central animated visualizer widget.
// class AnimatedVoiceVisualizer extends AnimatedWidget {
//   final VoiceVisualizerState state;
//   final AnimationController animationController;

//   const AnimatedVoiceVisualizer({
//     super.key,
//     required this.state,
//     required this.animationController,
//   }) : super(listenable: animationController);

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 250,
//       height: 250,
//       child: CustomPaint(
//         painter: _VoiceVisualizerPainter(
//           state: state,
//           animationValue: animationController.value,
//         ),
//       ),
//     );
//   }
// }

// class _VoiceVisualizerPainter extends CustomPainter {
//   final VoiceVisualizerState state;
//   final double animationValue;

//   _VoiceVisualizerPainter({required this.state, required this.animationValue});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()..color = Colors.white;
//     switch (state) {
//       case VoiceVisualizerState.idleCircles:
//         _drawFourShapes(canvas, size, paint, isRoundedRects: false);
//         break;
//       case VoiceVisualizerState.idleRoundedRects:
//         _drawFourShapes(canvas, size, paint, isRoundedRects: true);
//         break;
//       case VoiceVisualizerState.connectingOval:
//         _drawConnectingOval(canvas, size, paint, animationValue);
//         break;
//       case VoiceVisualizerState.speakingCircle:
//         _drawSpeakingCircle(canvas, size, paint, animationValue);
//         break;
//       case VoiceVisualizerState.thoughtBubble:
//         _drawThoughtBubble(canvas, size, paint);
//         break;
//     }
//   }

//   void _drawFourShapes(Canvas canvas, Size size, Paint paint, {required bool isRoundedRects}) {
//     const int count = 4;
//     final double totalWidth = size.width * 0.8;
//     final double shapeSize = totalWidth / 4.5;
//     final double spacing = (totalWidth - (shapeSize * count)) / (count - 1);
//     final double startX = (size.width - totalWidth) / 2;
//     final double centerY = size.height / 2;

//     for (int i = 0; i < count; i++) {
//       double x = startX + i * (shapeSize + spacing);
//       if (isRoundedRects) {
//         final rrect = RRect.fromRectAndRadius(
//           Rect.fromLTWH(x, centerY - shapeSize / 2, shapeSize, shapeSize),
//           Radius.circular(shapeSize / 4),
//         );
//         canvas.drawRRect(rrect, paint);
//       } else {
//         canvas.drawCircle(Offset(x + shapeSize / 2, centerY), shapeSize / 2, paint);
//       }
//     }
//   }

//   void _drawConnectingOval(Canvas canvas, Size size, Paint paint, double animValue) {
//     final curvedValue = Curves.easeOutCubic.transform(animValue);
//     final width = size.width * 0.4 + (size.width * 0.3 * curvedValue);
//     final height = size.height * 0.6 + (size.height * 0.3 * curvedValue);
//     final rrect = RRect.fromRectAndRadius(
//       Rect.fromCenter(center: size.center(Offset.zero), width: width, height: height),
//       Radius.circular(width / 2),
//     );
//     canvas.drawRRect(rrect, paint);
//   }

//   void _drawSpeakingCircle(Canvas canvas, Size size, Paint paint, double animValue) {
//     final radius = size.width * 0.45 * (0.98 + 0.02 * animValue);
//     canvas.drawCircle(size.center(Offset.zero), radius, paint);
//   }

//   void _drawThoughtBubble(Canvas canvas, Size size, Paint paint) {
//     final path = Path();
//     final rect = Rect.fromCenter(center: size.center(Offset.zero), width: size.width * 0.8, height: size.height * 0.6);
//     path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(30.0)));
//     path.addOval(Rect.fromCircle(center: Offset(rect.left + 30, rect.bottom - 10), radius: 15));
//     path.addOval(Rect.fromCircle(center: Offset(rect.left + 15, rect.bottom + 5), radius: 8));
//     canvas.drawPath(path, paint);
//   }

//   @override
//   bool shouldRepaint(covariant _VoiceVisualizerPainter oldDelegate) =>
//       oldDelegate.state != state || oldDelegate.animationValue != animationValue;
// }

// /// A list for selecting a voice.
// class VoiceSelectionList extends StatelessWidget {
//   final String selectedVoice;
//   final ValueChanged<String> onVoiceSelected;
//   final List<String> voices = const ['Sky', 'Breeze', 'Ember', 'Cove', 'Juniper'];

//   const VoiceSelectionList({
//     super.key,
//     required this.selectedVoice,
//     required this.onVoiceSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
//       child: Column(
//         children: voices.map((voice) {
//           final isSelected = voice == selectedVoice;
//           return Padding(
//             padding: const EdgeInsets.symmetric(vertical: 4.0),
//             child: Material(
//               color: isSelected ? AppColors.selectedCardBackground : AppColors.cardBackground,
//               borderRadius: BorderRadius.circular(12.0),
//               child: InkWell(
//                 onTap: () => onVoiceSelected(voice),
//                 borderRadius: BorderRadius.circular(12.0),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
//                   child: Row(
//                     children: [
//                       Text(
//                         voice,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
//                         ),
//                       ),
//                       const Spacer(),
//                       if (isSelected) const Icon(Icons.check, color: AppColors.textLight, size: 20),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }