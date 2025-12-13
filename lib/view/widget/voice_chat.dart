import 'package:flutter/material.dart';
import 'dart:math';

// --- Constants and Enums ---

/// Defines the color palette for the application, based on the provided UI images.
class AppColors {
  static const Color primaryBackground = Color(
    0xFF140D17,
  ); // Dark purple background
  static const Color cardBackground = Color(
    0xFF201625,
  ); // Darker card background for unselected
  static const Color selectedCardBackground = Color(
    0xFF2E2333,
  ); // Lighter card background for selected
  static const Color accentRed = Color(0xFFDA2A39); // Red for the close button
  static const Color buttonPrimary = Color(
    0xFFB1A2BB,
  ); // Light gray/purple for the confirm button
  static const Color buttonText = Color(
    0xFF201625,
  ); // Dark purple text for buttons
  static const Color textLight = Color(0xFFF0F0F0); // General white/light text
  static const Color textSecondary = Color(
    0xFFA0A0A0,
  ); // Gray text for subtitles/hints
}

/// Represents the major screen states in the application flow.
enum ScreenState {
  voiceSelection, // Initial screen to choose a voice
  connecting, // Screen showing connection in progress
  listeningIdle, // Waiting for user to speak (Tap to interrupt)
  listeningSpeaking, // User is speaking (Finish speaking to send)
  thinking, // AI is processing/thinking (Start speaking)
  thoughtBubble, // AI is speaking (Thought bubble)
}

/// Represents the visual state of the main animated visualizer.
enum VoiceVisualizerState {
  idleCircles, // Four white circles (on voice selection screen)
  idleRoundedRects, // Four rounded white rectangles (on listening idle screen)
  connectingOval, // Large white oval during connection
  speakingCircle, // Large white circle when user/AI is speaking/thinking
  thoughtBubble, // White thought bubble shape
}

// --- Main Application Entry Point ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Assistant UI Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primaryBackground,
        // Using 'SF Pro Display' for a more authentic iOS look.
        // For this to work, ensure the font is included in your pubspec.yaml and assets.
        // If not, Flutter will fallback to a default system font.
        fontFamily: 'SF Pro Display',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBackground,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const VoiceAssistantScreen(),
    );
  }
}

// --- Voice Assistant Screen (Main Stateful Widget) ---

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with TickerProviderStateMixin {
  ScreenState _currentScreenState = ScreenState.voiceSelection;
  String _selectedVoice = 'Sky';

  // Animation controllers for various UI elements
  late AnimationController
  _visualizerAnimationController; // For circles/rects morph and thought bubble
  late AnimationController
  _connectingAnimationController; // For connecting oval animation
  late AnimationController
  _speakingCircleAnimationController; // For main speaking circle pulse
  late AnimationController
  _thinkingDotsAnimationController; // For thinking dots animation
  late AnimationController
  _voiceBarsAnimationController; // For simulating voice level bars

  // State variables to simulate voice input for the bars
  List<double> _barHeights = List.generate(7, (index) => 0.0);

  @override
  void initState() {
    super.initState();
    // Controller for general visualizer animations (e.g., circles <-> rounded rects)
    _visualizerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Quick morph
    );

    // Controller for the connecting oval animation
    _connectingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Longer duration for connecting
    );

    // Controller for the main speaking circle's subtle pulse
    _speakingCircleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Controller for the thinking dots animation
    _thinkingDotsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true); // Repeats back and forth for pulsing effect

    // Controller for the voice input bars simulation
    _voiceBarsAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200), // Fast updates for bars
        )..addListener(() {
          // Only simulate voice input when on the speaking screen
          if (_currentScreenState == ScreenState.listeningSpeaking) {
            _simulateVoiceInput();
          }
        });
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

  /// Simulates fluctuating voice input levels for the visualizer bars.
  void _simulateVoiceInput() {
    setState(() {
      final double wave =
          (sin(_voiceBarsAnimationController.value * pi * 2 * 3) + 1) /
          2; // Sine wave for base level
      for (int i = 0; i < _barHeights.length; i++) {
        _barHeights[i] =
            wave * 0.8 + (Random().nextDouble() * 0.2); // Add randomness
      }
    });
  }

  /// Navigates to a new screen state and manages associated animations.
  void _navigateTo(ScreenState newState) {
    setState(() {
      _currentScreenState = newState;
    });

    // Reset and start animations based on the new state
    _connectingAnimationController.stop();
    _speakingCircleAnimationController.stop();
    _thinkingDotsAnimationController.stop();
    _voiceBarsAnimationController.stop();
    _visualizerAnimationController.stop();

    switch (newState) {
      case ScreenState.connecting:
        _connectingAnimationController.forward(from: 0.0).then((_) {
          // After connecting, automatically move to listening idle, if still on connecting screen
          if (_currentScreenState == ScreenState.connecting) {
            _navigateTo(ScreenState.listeningIdle);
          }
        });
        break;
      case ScreenState.listeningIdle:
        _visualizerAnimationController.forward(
          from: 0.0,
        ); // Animate to rounded rects
        break;
      case ScreenState.listeningSpeaking:
        _speakingCircleAnimationController.repeat(
          reverse: true,
        ); // Subtle pulse for speaking circle
        _voiceBarsAnimationController.repeat(
          period: const Duration(milliseconds: 1000),
        ); // Start bars animation
        break;
      case ScreenState.thinking:
        _speakingCircleAnimationController.value =
            1.0; // Keep circle fully expanded
        _thinkingDotsAnimationController.repeat(
          reverse: true,
        ); // Start dots animation
        break;
      case ScreenState.thoughtBubble:
        _visualizerAnimationController.forward(
          from: 0.0,
        ); // Animate to thought bubble
        break;
      case ScreenState.voiceSelection:
        _visualizerAnimationController.forward(
          from: 0.0,
        ); // Animate back to circles
        break;
    }
  }

  /// Builds the content for the current screen state.
  Widget _buildScreenContent() {
    switch (_currentScreenState) {
      case ScreenState.voiceSelection:
        return Column(
          children: [
            _AppBar(
              title: 'Choose a voice',
              subtitle: 'You can change this later',
              onClose: () =>
                  Navigator.of(context).pop(), // Placeholder: go back/close
            ),
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
                    onVoiceSelected: (voice) {
                      setState(() {
                        _selectedVoice = voice;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ConfirmButton(
                      onPressed: () => _navigateTo(ScreenState.connecting),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
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
              child: StatusTextAndIcon(
                text: 'Connecting',
                icon: null, // No icon shown in image for connecting
                animationController: null,
                barHeights: [],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: BottomActionButton(
                  icon: Icons.close_rounded,
                  backgroundColor: AppColors.accentRed,
                  onPressed: () => _navigateTo(
                    ScreenState.voiceSelection,
                  ), // Cancel connection
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
            StatusTextAndIcon(
              text: 'Tap to interrupt',
              icon: Icons.mic_none, // Microphone icon
              animationController: null,
              barHeights: [],
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: () => _navigateTo(ScreenState.listeningSpeaking),
              onCancel: () => _navigateTo(ScreenState.voiceSelection),
              pauseButtonIcon: Icons.stop_circle_outlined, // Stop/Record icon
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
              icon: null, // Voice bars act as icon
              animationController: _voiceBarsAnimationController,
              barHeights: _barHeights,
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: () => _navigateTo(
                ScreenState.thinking,
              ), // Simulate finishing speaking
              onCancel: () => _navigateTo(ScreenState.voiceSelection),
              pauseButtonIcon: Icons.pause_circle_outline, // Pause icon
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
                state: VoiceVisualizerState
                    .speakingCircle, // Circle remains during thinking
                animationController: _speakingCircleAnimationController,
              ),
            ),
            const SizedBox(height: 80),
            StatusTextAndIcon(
              text: 'Start speaking',
              icon: null, // Thinking dots act as icon
              animationController: _thinkingDotsAnimationController,
              barHeights: [],
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: () => _navigateTo(
                ScreenState.thoughtBubble,
              ), // Simulate AI response
              onCancel: () => _navigateTo(ScreenState.voiceSelection),
              pauseButtonIcon: Icons.pause_circle_outline, // Pause icon
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
                animationController:
                    _visualizerAnimationController, // Re-use general visualizer controller
              ),
            ),
            const SizedBox(height: 80),
            StatusTextAndIcon(
              text: 'Tap to cancel',
              icon: Icons.mic_none, // Microphone icon
              animationController: null,
              barHeights: [],
            ),
            const Spacer(),
            BottomActionButtons(
              onRecordPause: () => _navigateTo(
                ScreenState.listeningIdle,
              ), // Placeholder: back to idle
              onCancel: () => _navigateTo(ScreenState.voiceSelection),
              pauseButtonIcon: Icons.stop_circle_outlined, // Stop icon
            ),
            const SizedBox(height: 20),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // AnimatedSwitcher allows smooth transitions between different screen contents.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildScreenContent(),
        ),
      ),
    );
  }
}

// --- Custom App Bar Widget ---

class _AppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const _AppBar({required this.title, this.subtitle, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 16.0,
        bottom: 8.0,
        left: 16.0,
        right: 16.0,
      ),
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

// --- Voice Selection List Widget ---

class VoiceSelectionList extends StatelessWidget {
  final String selectedVoice;
  final ValueChanged<String> onVoiceSelected;
  final List<String> voices = ['Sky', 'Breeze', 'Ember', 'Cove', 'Juniper'];

  VoiceSelectionList({
    super.key,
    required this.selectedVoice,
    required this.onVoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        children: voices.map((voice) {
          final isSelected = voice == selectedVoice;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Material(
              color: isSelected
                  ? AppColors.selectedCardBackground
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12.0),
              child: InkWell(
                onTap: () => onVoiceSelected(voice),
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        voice,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- Confirm Button Widget ---

class ConfirmButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ConfirmButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          padding: EdgeInsets.zero, // Remove default padding
        ),
        child: Text(
          'Confirm',
          style: TextStyle(
            color: AppColors.buttonText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// --- Bottom Action Buttons Widget ---

class BottomActionButtons extends StatelessWidget {
  final VoidCallback onRecordPause;
  final VoidCallback onCancel;
  final IconData
  pauseButtonIcon; // Icon for the left button (pause/stop/record)

  const BottomActionButtons({
    super.key,
    required this.onRecordPause,
    required this.onCancel,
    required this.pauseButtonIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BottomActionButton(
            icon: pauseButtonIcon,
            onPressed: onRecordPause,
            backgroundColor: AppColors.cardBackground,
          ),
          BottomActionButton(
            icon: Icons.close_rounded,
            backgroundColor: AppColors.accentRed,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// A reusable button component for the bottom action bar.
class BottomActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final double size;
  final double iconSize;

  const BottomActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    this.size = 56.0,
    this.iconSize = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}

// --- Status Text and Dynamic Icons (Microphone/Bars/Dots) ---

class StatusTextAndIcon extends AnimatedWidget {
  final String text;
  final IconData? icon; // Standard icon (e.g., microphone)
  final List<double> barHeights; // Data for voice bars (if applicable)
  final AnimationController?
  animationController; // Controller for dynamic icons (bars or dots)

  const StatusTextAndIcon({
    super.key,
    required this.text,
    this.icon,
    this.barHeights = const [],
    this.animationController,
    // Listen to the animationController if provided, otherwise a stopped animation
  }) : super(
         listenable: animationController ?? const AlwaysStoppedAnimation(0),
       );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) // If a standard icon is provided
          Icon(icon, color: AppColors.textLight, size: 24)
        else if (barHeights.isNotEmpty &&
            animationController != null) // If voice bars are needed
          _VoiceBars(animation: animationController!, barHeights: barHeights)
        else if (animationController != null &&
            text == 'Start speaking') // If thinking dots are needed
          _ThinkingDots(animation: animationController!),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for animating voice level bars.
class _VoiceBars extends StatelessWidget {
  final Animation<double> animation;
  final List<double> barHeights; // Values from 0.0 to 1.0

  const _VoiceBars({required this.animation, required this.barHeights});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 24), // Fixed size for the bars area
      painter: _VoiceBarsPainter(barHeights),
    );
  }
}

class _VoiceBarsPainter extends CustomPainter {
  final List<double> barHeights;

  _VoiceBarsPainter(this.barHeights);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textLight
      ..style = PaintingStyle.fill;

    final double barWidth = 6.0;
    final double spacing = 4.0;
    final int numberOfBars = 7;
    final double totalWidth =
        (barWidth * numberOfBars) + (spacing * (numberOfBars - 1));
    final double startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < numberOfBars; i++) {
      double height = barHeights.length > i ? barHeights[i] * size.height : 0.0;
      if (height < 2) height = 2; // Ensure a minimum height for visibility

      final double x = startX + (i * (barWidth + spacing));
      final double top = size.height - height;
      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, height),
        const Radius.circular(3.0), // Rounded corners for bars
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceBarsPainter oldDelegate) {
    // Repaint only if bar heights change significantly
    if (oldDelegate.barHeights.length != barHeights.length) return true;
    for (int i = 0; i < barHeights.length; i++) {
      if ((barHeights[i] - oldDelegate.barHeights[i]).abs() > 0.01) {
        return true;
      }
    }
    return false;
  }
}

/// Custom painter for animating thinking dots.
class _ThinkingDots extends StatelessWidget {
  final Animation<double> animation;

  const _ThinkingDots({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 24,
      child: CustomPaint(painter: _ThinkingDotsPainter(animation.value)),
    );
  }
}

class _ThinkingDotsPainter extends CustomPainter {
  final double animationValue;

  _ThinkingDotsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.textLight;
    final double dotRadius = 4.0;
    final double spacing = 8.0;
    final int numberOfDots = 5;
    final double totalWidth =
        (dotRadius * 2 * numberOfDots) + (spacing * (numberOfDots - 1));
    final double startX = (size.width - totalWidth) / 2 + dotRadius;
    final double centerY = size.height / 2;

    for (int i = 0; i < numberOfDots; i++) {
      double scale = 1.0;
      double offset = 0.0;

      // Simple pulsing effect where dots animate out of sync
      double currentAnimationValue = (i % 2 == 0)
          ? animationValue
          : (1.0 - animationValue);
      scale = 0.8 + (0.2 * currentAnimationValue); // Scale from 0.8 to 1.0
      offset = -4 * currentAnimationValue; // Move up by up to 4 pixels

      canvas.drawCircle(
        Offset(startX + (i * (dotRadius * 2 + spacing)), centerY + offset),
        dotRadius * scale,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThinkingDotsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// --- Animated Voice Visualizer (Main Central Animation) ---

class AnimatedVoiceVisualizer extends AnimatedWidget {
  final VoiceVisualizerState state;
  final AnimationController animationController;

  const AnimatedVoiceVisualizer({
    super.key,
    required this.state,
    required this.animationController,
  }) : super(listenable: animationController);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250, // Fixed max width for the visualizer area
      height: 250, // Fixed max height for the visualizer area
      child: CustomPaint(
        painter: _VoiceVisualizerPainter(
          state: state,
          animationValue: animationController.value,
        ),
      ),
    );
  }
}

class _VoiceVisualizerPainter extends CustomPainter {
  final VoiceVisualizerState state;
  final double animationValue;

  _VoiceVisualizerPainter({required this.state, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (state) {
      case VoiceVisualizerState.idleCircles:
        _drawFourShapes(canvas, size, paint, isRoundedRects: false);
        break;
      case VoiceVisualizerState.idleRoundedRects:
        _drawFourShapes(canvas, size, paint, isRoundedRects: true);
        break;
      case VoiceVisualizerState.connectingOval:
        _drawConnectingOval(canvas, size, paint, animationValue);
        break;
      case VoiceVisualizerState.speakingCircle:
        _drawSpeakingCircle(canvas, size, paint, animationValue);
        break;
      case VoiceVisualizerState.thoughtBubble:
        _drawThoughtBubble(canvas, size, paint);
        break;
    }
  }

  /// Draws four shapes (circles or rounded rectangles).
  void _drawFourShapes(
    Canvas canvas,
    Size size,
    Paint paint, {
    required bool isRoundedRects,
  }) {
    final double totalWidth = size.width * 0.8;
    final double shapeSize = totalWidth / 4.5; // Calculated size for each shape
    final double spacing = (totalWidth - (shapeSize * 4)) / 3;
    final double startX = (size.width - totalWidth) / 2;
    final double centerY = size.height / 2;

    for (int i = 0; i < 4; i++) {
      double x = startX + i * (shapeSize + spacing);

      if (isRoundedRects) {
        // Rounded rectangles with a subtle vertical pulse
        double currentHeight = shapeSize;
        // This simple pulse ensures some animation for idle state in rounded rects
        double pulseFactor =
            0.5 + 0.5 * sin(animationValue * pi * 2 + i * pi / 4);
        currentHeight =
            shapeSize * (0.8 + 0.2 * pulseFactor); // Fluctuate height
        final RRect rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - currentHeight / 2,
            shapeSize,
            currentHeight,
          ),
          Radius.circular(
            shapeSize / 4,
          ), // Fixed corner radius for rounded rects
        );
        canvas.drawRRect(rrect, paint);
      } else {
        // Circles
        canvas.drawCircle(
          Offset(x + shapeSize / 2, centerY),
          shapeSize / 2,
          paint,
        );
      }
    }
  }

  /// Draws an animating oval for the "Connecting" state.
  void _drawConnectingOval(
    Canvas canvas,
    Size size,
    Paint paint,
    double animationValue,
  ) {
    // Animate from a smaller oval to a larger one and hold or slightly shrink
    final double minWidth = size.width * 0.4;
    final double maxWidth = size.width * 0.7;
    final double minHeight = size.height * 0.6;
    final double maxHeight = size.height * 0.9;

    // Use a curve to make the animation more natural (e.g., ease-out)
    final double curvedValue = Curves.easeOutCubic.transform(animationValue);

    final double currentWidth = minWidth + (maxWidth - minWidth) * curvedValue;
    final double currentHeight =
        minHeight + (maxHeight - minHeight) * curvedValue;

    final double left = (size.width - currentWidth) / 2;
    final double top = (size.height - currentHeight) / 2;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, currentWidth, currentHeight),
      Radius.circular(
        currentWidth.clamp(0.0, currentHeight) / 2,
      ), // Make it a perfect oval
    );
    canvas.drawRRect(rrect, paint);
  }

  /// Draws a large circle for the "Speaking" and "Thinking" states.
  void _drawSpeakingCircle(
    Canvas canvas,
    Size size,
    Paint paint,
    double animationValue,
  ) {
    // The circle can have a subtle pulse when animated, otherwise static
    final double baseRadius = size.width * 0.45;
    // Apply a subtle scale animation for a "breathing" effect
    final double currentRadius =
        baseRadius * (0.98 + 0.02 * animationValue); // Scale from 98% to 100%
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      currentRadius,
      paint,
    );
  }

  /// Draws a simplified thought bubble shape.
  void _drawThoughtBubble(Canvas canvas, Size size, Paint paint) {
    final double bodyWidth = size.width * 0.8;
    final double bodyHeight = size.height * 0.6;
    final double bodyLeft = (size.width - bodyWidth) / 2;
    final double bodyTop = (size.height - bodyHeight) / 2;
    final double bodyRadius = 30.0; // Corner radius for the main bubble body

    // Main rounded rectangle body of the thought bubble
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyLeft, bodyTop, bodyWidth, bodyHeight),
      Radius.circular(bodyRadius),
    );
    canvas.drawRRect(body, paint);

    // Add smaller "thought" bubbles (tails)
    final double smallBubbleRadius = 15.0;
    final double tinyBubbleRadius = 8.0;

    // Position of the first small bubble (main tail)
    canvas.drawCircle(
      Offset(
        bodyLeft + smallBubbleRadius * 1.5,
        bodyTop + bodyHeight - smallBubbleRadius * 0.8,
      ),
      smallBubbleRadius,
      paint,
    );

    // Position of the second, smaller bubble
    canvas.drawCircle(
      Offset(
        bodyLeft + tinyBubbleRadius * 1.5,
        bodyTop + bodyHeight - tinyBubbleRadius * 0.5,
      ),
      tinyBubbleRadius,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceVisualizerPainter oldDelegate) {
    // Repaint only if state or animation value changes
    return oldDelegate.state != state ||
        oldDelegate.animationValue != animationValue;
  }
}
