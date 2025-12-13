import 'package:flutter/material.dart';
import '../../../data/res/openai.dart';
import '../tasks/agent_orchestrator.dart';

/// A chat interface for interacting with the browser automation agent.
/// Users can send natural language commands and see the agent's responses.
class BrowserChatScreen extends StatefulWidget {
  const BrowserChatScreen({Key? key}) : super(key: key);

  @override
  State<BrowserChatScreen> createState() => _BrowserChatScreenState();
}

class _BrowserChatScreenState extends State<BrowserChatScreen> {
  late AgentOrchestrator _orchestrator;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeOrchestrator();
  }

  void _initializeOrchestrator() {
    try {
      _orchestrator = AgentOrchestrator(client: Cfg.client);
      setState(() {
        _isInitialized = true;
      });
      _addSystemMessage(
        'Browser automation agent ready. You can start giving commands.',
      );
    } catch (e) {
      _addSystemMessage('Error initializing agent: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _orchestrator.closeBrowserSession();
    super.dispose();
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: false,
          isSystem: true,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _addAgentMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isProcessing || !_isInitialized) return;

    _addUserMessage(message);
    _messageController.clear();

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await _orchestrator.runWorkflow(message);
      _addAgentMessage(response);
    } catch (e) {
      _addAgentMessage('Error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF00FF), width: 2),
        ),
        title: const Text(
          'Clear History',
          style: TextStyle(color: Color(0xFFFF00FF)),
        ),
        content: const Text(
          'Are you sure you want to clear the conversation history?',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF00FFFF)),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _orchestrator.clearHistory();
              _addSystemMessage('History cleared. Starting fresh.');
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFFF00FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionStatus() {
    final status = _orchestrator.getSessionStatus();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00FFFF), width: 2),
        ),
        title: const Text(
          'Session Status',
          style: TextStyle(
            color: Color(0xFF00FFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusRow(
                'Browser Session',
                status['browserSession']['isActive'] ? 'Active' : 'Inactive',
                status['browserSession']['isActive']
                    ? const Color(0xFF00FF41)
                    : const Color(0xFFFF0000),
              ),
              const SizedBox(height: 8),
              _buildStatusRow(
                'Session ID',
                status['browserSession']['sessionId'] ?? 'None',
                const Color(0xFFFFFFFF),
              ),
              const SizedBox(height: 8),
              _buildStatusRow(
                'Current URL',
                status['browserSession']['currentUrl'] ?? 'None',
                const Color(0xFFFF00FF),
              ),
              const SizedBox(height: 8),
              _buildStatusRow(
                'Conversation Length',
                '${status['conversationLength']} messages',
                const Color(0xFF00FFFF),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF00FF41))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00FF41).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionChip(
              label: 'Open Google',
              onTap: () => _messageController.text =
                  'Initialize browser and go to https://google.com',
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              label: 'Take Screenshot',
              onTap: () => _messageController.text =
                  'Take a screenshot of the current page',
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              label: 'Read Page',
              onTap: () => _messageController.text =
                  'Read all the text content on the page',
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              label: 'Get Links',
              onTap: () =>
                  _messageController.text = 'Get all the links on the page',
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              label: 'Close Browser',
              onTap: () =>
                  _messageController.text = 'Close the browser session',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Browser Agent Chat',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF41)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showSessionStatus,
            tooltip: 'Session Status',
            color: const Color(0xFF00FFFF),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
            tooltip: 'Clear History',
            color: const Color(0xFFFF00FF),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Actions
          _buildQuickActions(),

          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: const Color(0xFF00FF41).withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a conversation with the browser agent',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF00FF41),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try: "Open Google and search for Flutter"',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF00FFFF).withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: const Color(0xFF000000),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
                  ),
          ),

          // Processing Indicator
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00FF41).withOpacity(0.3),
                    width: 1,
                  ),
                  bottom: BorderSide(
                    color: const Color(0xFF00FF41).withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00FF41),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Agent is processing...',
                    style: TextStyle(color: Color(0xFF00FFFF)),
                  ),
                ],
              ),
            ),

          // Input Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF00FF41).withOpacity(0.3),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF41).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                    decoration: InputDecoration(
                      hintText: 'Enter your command...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF00FF41).withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF00FF41),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: const Color(0xFF00FF41).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF00FF41),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      enabled: !_isProcessing && _isInitialized,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: (_isProcessing || !_isInitialized)
                      ? null
                      : _sendMessage,
                  backgroundColor: const Color(0xFF00FF41),
                  foregroundColor: const Color(0xFF000000),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isSystem = false,
    required this.timestamp,
  });
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00FFFF).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: SelectableText(
            message.text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF00FFFF),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: message.isUser
              ? const LinearGradient(
                  colors: [Color(0xFF00FF41), Color(0xFF00CC33)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: message.isUser
                ? const Color(0xFF00FF41).withOpacity(0.5)
                : const Color(0xFFFF00FF).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: message.isUser
                  ? const Color(0xFF00FF41).withOpacity(0.3)
                  : const Color(0xFFFF00FF).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: message.isUser
                    ? const Color(0xFF000000)
                    : const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: message.isUser
                    ? const Color(0xFF000000).withOpacity(0.7)
                    : const Color(0xFF00FFFF).withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF00FF41),
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onTap,
      backgroundColor: const Color(0xFF1A1A1A),
      side: const BorderSide(color: Color(0xFF00FF41), width: 1.5),
      shadowColor: const Color(0xFF00FF41).withOpacity(0.5),
      elevation: 4,
    );
  }
}
