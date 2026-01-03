import 'package:flutter/material.dart';
import 'ai_sidebar.dart';
import '../ai/chat_service.dart';
import '../ai/config.dart';
import 'repo_browser.dart';
class RepoBrowserScaffold extends StatefulWidget {
  final String path; // The Root Path downloaded
  final String title;

  const RepoBrowserScaffold({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<RepoBrowserScaffold> createState() => _RepoBrowserScaffoldState();
}

class _RepoBrowserScaffoldState extends State<RepoBrowserScaffold> {
  ChatService? _chatService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initAI();
  }

  void _initAI() async {
    final cfg = await Config.load();
    setState(() {
      _chatService = ChatService(cfg, widget.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Button to toggle AI Sidebar
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      body: RepoBrowser(path: widget.path , aisidebar: _chatService == null
          ? const Drawer(child: Center(child: CircularProgressIndicator()))
          : AiSidebar(chatService: _chatService!),
    ),
      // The Sidebar
      endDrawer: _chatService == null
          ? const Drawer(child: Center(child: CircularProgressIndicator()))
          : AiSidebar(chatService: _chatService!),
    );
  }
}
