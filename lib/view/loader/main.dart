import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'entries.dart';
import 'repo_loader.dart';
import 'screens/pkg_search_screen.dart';
import 'utils/colors.dart';
import 'widgets/repo_browser_scaffold.dart';

void main() {  WidgetsFlutterBinding.ensureInitialized();

  // Optional: makes system UI match true-black style.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));


  runApp(const GitLoaderApp());
}

// Global selection state to keep track of files across navigation
final Set<String> selectedPaths = {};

class GitLoaderApp extends StatelessWidget {
  const GitLoaderApp({super.key});

  @override
  Widget build(BuildContext context) {    const bg = Color(0xFF000000);
    const surface = Color(0xFF0B0B0F);
    const surface2 = Color(0xFF111118);
    const border = Color(0xFF24242C);
    const accent = Color(0xFF7C4DFF); // premium violet accent
    const accent2 = Color(0xFF00E5FF); // cyan hint (used subtly)
     final base = ThemeData(
     brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        surfaceContainerHighest: surface2,
        primary: accent,
        secondary: accent2,
        outline: border,
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Colors.white,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1C1C24),
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: Color(0xFF9A9AAA)),
        labelStyle: const TextStyle(color: Color(0xFFEDEDF5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF111118),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.2),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 15, height: 1.35),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2),
      bodyLarge: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w500, height: 1.45),
      bodyMedium: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.45),
      labelLarge: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.2),
      labelMedium: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2),
    );

    final theme = base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
    );
    

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const RemoteLoaderPage(),
    );
  }
}

class RemoteLoaderPage extends StatefulWidget {
  const RemoteLoaderPage({super.key});

  @override
  State<RemoteLoaderPage> createState() => _RemoteLoaderPageState();
}

class _RemoteLoaderPageState extends State<RemoteLoaderPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;

  void _loadRepo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Downloading repository snapshot...";
    });

    try {
      String localPath = await RepoUtils.downloadAndExtract(url);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepoBrowserScaffold(path: localPath, title: "Root"),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  void _loadLocalRepo() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Selecting local repository...";
    });

    try {
      // Use file_picker to select a directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Git Repository Folder',
      );

      if (selectedDirectory == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = "No directory selected";
        });
        return;
      }

      // Check if the selected directory contains a .git folder
      final gitDir = Directory('$selectedDirectory/.git');
      if (!await gitDir.exists()) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Selected folder is not a Git repository";
        });
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepoBrowserScaffold(
              path: selectedDirectory,
              title: "Local Repository",
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_motion,
                size: 80,
                color: AppColors.accent,
              ),
              const SizedBox(height: 24),
              const Text(
                "GitLoader",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter a GitHub URL or select a local repository",
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: "Repository URL",
                  hintText: "https://github.com/username/repo",
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loadRepo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: Platform.isAndroid
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          )
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "EXPLORE REMOTE REPO",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loadLocalRepo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    shape: Platform.isAndroid
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          )
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                    side: const BorderSide(color: AppColors.accent, width: 1),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.folder_open, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              "SELECT LOCAL REPOSITORY",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
                       SizedBox(height: 20,),
                ElevatedButton(onPressed: (){
                    Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileSearchEntry(),
          ),
        );
                }, child: Text("Search files and content")),
                                       SizedBox(height: 20,),
                ElevatedButton(onPressed: (){
                    Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoPackageSearchPage(),
          ),
        );
                }, child: Text("Search packages and libraries")),
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusMessage!.startsWith("Error") ||
                            _statusMessage!.contains("not a Git repository")
                        ? Colors.redAccent
                        : AppColors.accent,
                  ),
                ),
       
              ],
            ],
          ),
        ),
      ),
    );
  }
}


