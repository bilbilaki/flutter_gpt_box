import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'fileexplorerpanel.dart';
class EditorWithExplorerShell extends StatefulWidget {
  final Directory projectRoot;
  final Widget Function(File file,Widget sidebar) editorBuilder; // your AdvancedCodeEditor
  final Widget aisidebar;

  const EditorWithExplorerShell({
    super.key,
    required this.projectRoot,
    required this.editorBuilder, required this.aisidebar,
  });

  @override
  State<EditorWithExplorerShell> createState() => _EditorWithExplorerShellState();
}

class _EditorWithExplorerShellState extends State<EditorWithExplorerShell> {
  File? _activeFile;

  // sidebar width state
  double _sidebarWidth = 280;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isSmall = c.maxWidth < 900;

        final editor = _activeFile == null ? const Center(child: Text("Select a file")) : widget.editorBuilder(_activeFile!,widget.aisidebar);

        final explorer = FileExplorerPanel(
          root: widget.projectRoot,
          sidebarWidth: isSmall ? 280 : _sidebarWidth,
          onOpenFile: (file) {
            setState(() => _activeFile = file);
            if (isSmall) Navigator.of(context).maybePop(); // close drawer
          },
        );

        if (isSmall) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_activeFile == null ? 'Editor' : p.basename(_activeFile!.path)),
            ),
            drawer: Drawer(
              child: SafeArea(child: explorer),
            ),
            body: editor,
          );
        }

        // Desktop/tablet: persistent resizable sidebar
        final minW = 220.0;
        final maxW = (c.maxWidth * 0.55).clamp(260.0, 520.0);

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: _sidebarWidth.clamp(minW, maxW),
                  child: explorer,
                ),

                // drag handle
                _ResizeHandle(
                  onDrag: (dx) {
                    setState(() {
                      _sidebarWidth = (_sidebarWidth + dx).clamp(minW, maxW);
                    });
                  },
                ),

                const VerticalDivider(width: 1, thickness: 1),

                Expanded(child: editor),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final void Function(double dx) onDrag;
  const _ResizeHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: SizedBox(
          width: 10,
          child: Center(
            child: Container(
              width: 2,
              height: 28,
              color: Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
