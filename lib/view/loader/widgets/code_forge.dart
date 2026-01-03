import 'dart:io';
import 'package:code_forge/code_forge.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

class AdvancedCodeEditor extends StatefulWidget {
  final File file;
  final Widget aisidebar;
  const AdvancedCodeEditor({
    required this.file,
    required this.aisidebar,
    super.key,
  });

  @override
  State<AdvancedCodeEditor> createState() => _AdvancedCodeEditorState();
}

class _AdvancedCodeEditorState extends State<AdvancedCodeEditor> {
  late final UndoRedoController _undoController;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _undoController = UndoRedoController();
  }

  @override
  Widget build(BuildContext context) {
    String absFilePath = widget.file.path;

    // Shared text style for the editor
    final baseTextStyle = GoogleFonts.jetBrainsMono(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
    );

    return Scaffold(
      appBar: AppBar(title: Text(p.basename(absFilePath))),

      backgroundColor: const Color(0xFF282c34),
      body: SafeArea(
        child: FutureBuilder<LspConfig>(
          future: null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return CodeForge(
              controller: CodeForgeController(lspConfig: snapshot.data),
              undoController: _undoController,
              focusNode: _focusNode,
              verticalScrollController: _vScroll,
              filePath: absFilePath,
              language: langDart,
              editorTheme: atomOneDarkTheme,
              textStyle: baseTextStyle,

              // Functionality toggles
              enableFolding: true,
              enableGuideLines: true,
              enableSuggestions: true,
              readOnly: false,
              lineWrap: false,
              innerPadding: const EdgeInsets.only(top: 10),

              // 1. ADVANCED SELECTION STYLE
              selectionStyle: CodeSelectionStyle(
                cursorColor: Colors.amberAccent,
                selectionColor: const Color(0xFF3e4451),
                cursorBubbleColor: Colors.amberAccent,
              ),

              // 2. ADVANCED GUTTER STYLE
              gutterStyle: GutterStyle(
                backgroundColor: const Color(0xFF21252b),
                gutterWidth: 55,
                lineNumberStyle: baseTextStyle.copyWith(fontSize: 12),
                activeLineNumberColor: Colors.white,
                inactiveLineNumberColor: const Color(0xFF4b5263),
                errorLineNumberColor: const Color(0xFFE53935),
                warningLineNumberColor: const Color(0xFFFFA726),
                foldedIcon: Icons.arrow_right_rounded,
                unfoldedIcon: Icons.arrow_drop_down_rounded,
                foldingIconSize: 20,
                foldedIconColor: Colors.blueAccent,
                unfoldedIconColor: Colors.white54,
                foldedLineHighlightColor: Colors.blue.withOpacity(0.1),
              ),

              // 3. ADVANCED SUGGESTION STYLE (IntelliSense Popup)
              suggestionStyle: SuggestionStyle(
                elevation: 12,
                backgroundColor: const Color(0xFF21252b),
                focusColor: const Color(0xFF2c313a),
                hoverColor: const Color(0xFF3e4451),
                splashColor: Colors.blue.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF181a1f), width: 1),
                ),
                textStyle: baseTextStyle.copyWith(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),

              // 4. ADVANCED HOVER DETAILS STYLE (Documentation tooltips)
              hoverDetailsStyle: HoverDetailsStyle(
                elevation: 10,
                backgroundColor: const Color(0xFF21252b),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Colors.blueAccent, width: 0.5),
                ),
                textStyle: baseTextStyle.copyWith(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
      endDrawer: widget.aisidebar,
    );
  }
}
