// ignore: library_prefixes
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import '../ai/chat_service.dart';
import '../ai/config.dart';
import '../ai/models.dart';
import 'dart:async'; // Required for the timer logic

class AiSidebar extends StatefulWidget {
  final ChatService chatService;
  const AiSidebar({super.key, required this.chatService});

  @override
  State<AiSidebar> createState() => _AiSidebarState();
}

class _AiSidebarState extends State<AiSidebar> with TickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Magic: Animation controllers for that smooth feel
  bool _isHoveringSend = false;

  @override
  void initState() {
    super.initState();
    widget.chatService.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.chatService.removeListener(_scrollToBottom);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      // Wait a tiny bit for the UI to render the new message
      Future.delayed(const Duration(milliseconds: 100), () {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart, // Smoother slide
        );
      });
    }
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    widget.chatService.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we need to show the "Thinking..." bubble
    // We show it if the AI is thinking BUT hasn't started streaming text yet.
    final bool showThinkingIndicator =
        widget.chatService.isThinking &&
        widget.chatService.currentStreamingContent.isEmpty;

    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2227), // Deep dark background
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF21252B),
              border: Border(bottom: BorderSide(color: Colors.black45)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "AI Assistant",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _buildHeaderBtn(Icons.settings_outlined, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ConfigEditor()),
                  );
                }),
                _buildHeaderBtn(Icons.delete_outline, () {
                  /* clear logic */
                }),
              ],
            ),
          ),

          // --- CHAT AREA ---
          Expanded(
            child: ListenableBuilder(
              listenable: widget.chatService,
              builder: (ctx, _) {
                final msgs = widget.chatService.messages;
                final bool isStreaming =
                    widget.chatService.currentStreamingContent.isNotEmpty;

                // Calculate total items: saved messages + (optional) streaming bubble + (optional) thinking bubble
                int itemCount = msgs.length;
                if (isStreaming) itemCount++;
                if (showThinkingIndicator) itemCount++;

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    // 1. Show existing messages
                    if (index < msgs.length) {
                      return _buildMsgBubble(msgs[index]);
                    }

                    // 2. Show Streaming Message (Active typing)
                    if (isStreaming && index == msgs.length) {
                      return _buildMsgBubble(
                        Message(
                          role: "assistant",
                          content: widget.chatService.currentStreamingContent,
                        ),
                        isStreaming: true,
                      );
                    }

                    // 3. Show Thinking Indicator (The jumping dots)
                    return _buildThinkingIndicator();
                  },
                );
              },
            ),
          ),

          // --- INPUT AREA ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF21252B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C313C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: "Ask me anything...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button with Hover effect
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoveringSend = true),
                  onExit: (_) => setState(() => _isHoveringSend = false),
                  child: GestureDetector(
                    onTap: _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isHoveringSend
                            ? Colors.blueAccent
                            : Colors.blueAccent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          if (_isHoveringSend)
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Header Buttons
  Widget _buildHeaderBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.grey, size: 20),
      splashRadius: 20,
      onPressed: onTap,
    );
  }

  // --- THE THINKING BUBBLE (MAGIC) ---
  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF353B45),
            child: Icon(Icons.psychology, size: 16, color: Colors.blueAccent),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C313C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const _JumpingDots(), // Defined at the bottom
          ),
        ],
      ),
    );
  }

  Widget _buildMsgBubble(Message msg, {bool isStreaming = false}) {
    bool isUser = msg.role == "user";
    bool isTool = msg.role == "tool";

    // 1. Tool Output (Technical Card Look)
    if (isTool) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF181A1F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: Colors.orange,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "TOOL OUTPUT",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                msg.content,
                style: const TextStyle(
                  color: Colors.grey,
                  fontFamily: "monospace",
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Normal Chat Message
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar (Left)
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF353B45),
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blueAccent : const Color(0xFF2C313C),
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF2979FF), Color(0xFF448AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tool Call Indicator (e.g. "Calling: read_file")
                  if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty)
                    ...msg.toolCalls!.map(
                      (tc) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.code,
                              size: 12,
                              color: Colors.yellowAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Function: ${tc.function.name}",
                              style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 11,
                                fontFamily: "monospace",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Main Content
                  SelectableText(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User Avatar (Right)
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF353B45),
              child: Icon(Icons.person, size: 16, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

// --- ANIMATION WIDGET: JUMPING DOTS ---
class _JumpingDots extends StatefulWidget {
  const _JumpingDots();
  @override
  State<_JumpingDots> createState() => _JumpingDotsState();
}

class _JumpingDotsState extends State<_JumpingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return ScaleTransition(
          scale: DelayTween(begin: 0.0, end: 1.0, delay: index * 0.2).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

// Helper for the dots animation
class DelayTween extends Tween<double> {
  final double delay;
  DelayTween({super.begin, super.end, required this.delay});

  @override
  double lerp(double t) {
    return super.lerp((Math.sin((t - delay) * 2 * Math.pi) + 1) / 2);
  }
}
