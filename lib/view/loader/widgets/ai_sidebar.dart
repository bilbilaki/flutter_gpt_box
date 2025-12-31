import 'package:flutter/material.dart';
import '../ai/chat_service.dart';
import '../ai/config.dart';
import '../ai/models.dart';

class AiSidebar extends StatefulWidget {
  final ChatService chatService;
  const AiSidebar({super.key, required this.chatService});

  @override
  State<AiSidebar> createState() => _AiSidebarState();
}

class _AiSidebarState extends State<AiSidebar> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen for updates to scroll to bottom
    widget.chatService.addListener(_scrollToBottom);
  }
  
  @override
  void dispose() {
    widget.chatService.removeListener(_scrollToBottom);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      // Small delay to let build finish
      Future.delayed(const Duration(milliseconds: 100), () {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
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
    return Container(
      width: 350, // Sidebar width
      color: const Color(0xFF1E2227),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF282C34),
            child: Row(children: [
               const Icon(Icons.psychology, color: Colors.blueAccent),
               const SizedBox(width: 8),
               const Text("AI Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               const Spacer(),
                IconButton(
                 icon: const Icon(Icons.settings, color: Colors.grey),
                 onPressed: () {  Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConfigEditor(),
          ),
        ); }, 
               ),
               IconButton(
                 icon: const Icon(Icons.delete_sweep, color: Colors.grey),
                 onPressed: () { /* clear logic */ }, 
               )
            ]),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.chatService,
              builder: (ctx, _) {
                final msgs = widget.chatService.messages;
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length + (widget.chatService.currentStreamingContent.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show streaming partial content at the end
                    if (index == msgs.length) {
                       return _buildMsgBubble(Message(role: "assistant", content: widget.chatService.currentStreamingContent));
                    }
                    return _buildMsgBubble(msgs[index]);
                  },
                );
              },
            ),
          ),
          if (widget.chatService.isThinking)
            const LinearProgressIndicator(minHeight: 2, color: Colors.blueAccent, backgroundColor: Colors.transparent),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Ask to edit files...",
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Color(0xFF2C313C),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _submit,
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMsgBubble(Message msg) {
    bool isUser = msg.role == "user";
    bool isTool = msg.role == "tool";
    
    if (isTool) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white10)
        ),
        child: SelectableText("🔧 Tool Output: ${msg.content.length > 100 ? '${msg.content.substring(0,100)}...' : msg.content}", 
          style: const TextStyle(color: Colors.orange, fontFamily: "monospace", fontSize: 12)),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[900] : const Color(0xFF353B45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty)
              ...msg.toolCalls!.map((tc) => SelectableText("🛠 Calling: ${tc.function.name}", 
                 style: const TextStyle(color: Colors.yellow, fontSize: 11, fontStyle: FontStyle.italic))),
            SelectableText(msg.content, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}