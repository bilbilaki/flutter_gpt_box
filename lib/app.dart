import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_box/data/res/build_data.dart';
import 'package:gpt_box/data/res/l10n.dart';
import 'package:gpt_box/data/store/all.dart';
import 'package:gpt_box/generated/l10n/l10n.dart';
import 'package:gpt_box/view/page/home/home.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';


part 'intro.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemUIs.setTransparentNavigationBar(context);
 WidgetsFlutterBinding.ensureInitialized();

  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));

    return RNodes.app.listen(() => _buildApp(context));
  }

  Widget _buildApp(BuildContext context) {
    const bg = Color(0xFF000000);
    const surface = Color(0xFF0B0B0F);
    const surface2 = Color(0xFF111118);
    const border = Color(0xFF24242C);
    const accent = Color(0xFF7C4DFF); 
    const accent2 = Color(0xFF00E5FF); 
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

    UIs.colorSeed = Color(Stores.setting.themeColorSeed.get());
    final themeMode = switch (Stores.setting.themeMode.get()) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = Stores.setting.locale.get();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPT Box fork',
      locale: locale.toLocale,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        LibLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      themeMode: themeMode,
      theme: ThemeData(colorSchemeSeed: UIs.colorSeed).fixWindowsFont,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: UIs.colorSeed,
      ).toAmoled.fixWindowsFont,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child ?? UIs.placeholder,
        breakpoints: const [
          Breakpoint(start: 0, end: 650, name: MOBILE),
          Breakpoint(start: 651, end: 900, name: TABLET),
          Breakpoint(start: 901, end: 1920, name: DESKTOP),
        ],
      ),
      home: VirtualWindowFrame(
        child: Builder(
          builder: (context) {
            final l10n_ = AppLocalizations.of(context);
            if (l10n_ != null) l10n = l10n_;
            context.setLibL10n();
            UIs.primaryColor = Theme.of(context).colorScheme.primary;

            final intros = _IntroPage.builders;
            if (intros.isNotEmpty) {
              return _IntroPage(intros);
            }
            return const HomePage();
          },
        ),
      ),
    );
  }
}