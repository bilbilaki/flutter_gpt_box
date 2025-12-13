import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:gpt_box/core/providers/fileprovider.dart';
import 'package:gpt_box/core/services/file_index.dart';
import 'package:gpt_box/data/model/app/file_model.dart'; // Make sure this path is correct
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Helper class to create PDF files and index them using [FileIndexService].
class PdfCreationHelper {
  final FileIndexService _fileIndexService;

  PdfCreationHelper(this._fileIndexService);

  /// Converts a file extension string (e.g., "pdf", ".pdf") to a [MimeType].
  MimeType _getMimeTypeFromFileExtension(String extension) {
    final String cleanExt = extension.replaceFirst('.', '').toLowerCase();
    switch (cleanExt) {
      case 'pdf':
        return MimeType.pdf;
      case 'txt':
        return MimeType.text;
      case 'json':
        return MimeType
            .application; // Or a more specific MimeType for JSON if available
      case 'png':
      case 'jpg':
      case 'jpeg':
        return MimeType.image;
      default:
        return MimeType.other;
    }
  }

  /// Internal helper to save bytes to a file, add it to the index, and return the file ID.
  Future<String?> _saveAndIndexFile(
    Uint8List bytes,
    String userSubdir,
    String fileName,
    String fileExtension,
  ) async {
    try {
      final Directory dir = await _getTargetDirectory(userSubdir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final String fullPath = p.join(dir.path, fileName);
      final File file = File(fullPath);
      await file.writeAsBytes(bytes);

      // Add to FileIndexService
      final String id = await _fileIndexService.addGeneratedFile(
        name: fileName,
        bytes: bytes,
        fileExtension: fileExtension,
        mimeType: _getMimeTypeFromFileExtension(fileExtension),
      );
      return id;
    } catch (e, st) {
      print('Error saving and indexing file: $e\n$st');
      return null;
    }
  }

  /// Retrieve the target directory for saving outputs.
  /// Provided by the user request. It will create a nested app folder under the platform downloads.
  Future<Directory> _getTargetDirectory(String userSubdir) async {
    // Determine the base download directory per platform.
    late final Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/storage/emulated/0/Download');
    } else if (Platform.isLinux) {
      baseDir = Directory(p.join(Platform.environment['HOME']!, 'Downloads'));
    } else if (Platform.isWindows) {
      baseDir = Directory(
        p.join(Platform.environment['USERPROFILE']!, 'Downloads'),
      );
    } else {
      final Directory? downloadsDir = await getDownloadsDirectory();
      baseDir = downloadsDir ?? await getApplicationDocumentsDirectory();
    }

    // App-specific subfolder structure.
    const String appFolderName = 'GPTBOX';
    const String downloadsSubFolderName = 'PDF';
    String appDownloadsPath = p.join(
      baseDir.path,
      appFolderName,
      downloadsSubFolderName,
    );

    // Append user-provided subdirectory if any.
    if (userSubdir.isNotEmpty) {
      appDownloadsPath = p.join(appDownloadsPath, userSubdir);
    }

    return Directory(appDownloadsPath);
  }

  /// Utility: ensure directory exists and return full file path.
  Future<String> _prepareOutputPath(String userSubdir, String fileName) async {
    final Directory dir = await _getTargetDirectory(userSubdir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, fileName);
  }

  /// 1) Create a simple PDF containing arbitrary text.
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> createSimplePdfAndIndex({
    required String text,
    String userSubdir = '',
    String fileName = 'HelloWorld.pdf',
    PdfFontFamily fontFamily = PdfFontFamily.helvetica,
    double fontSize = 12,
    int r = 0,
    int g = 0,
    int b = 0,
    ui.Rect? bounds,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final PdfPage page = document.pages.add();
      final PdfStandardFont font = PdfStandardFont(fontFamily, fontSize);
      final PdfColor color = PdfColor(r, g, b);
      final ui.Rect drawBounds = bounds ?? ui.Rect.fromLTWH(0, 0, 300, 50);
      page.graphics.drawString(
        text,
        font,
        brush: PdfSolidBrush(color),
        bounds: drawBounds,
      );
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('createSimplePdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 2) Add text using a TrueType font file path.
  /// fontId: ID of the TTF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addTrueTypeFontPdfAndIndex({
    required String fontId,
    required String text,
    String userSubdir = '',
    String fileName = 'TrueType.pdf',
    double fontSize = 12,
    int r = 0,
    int g = 0,
    int b = 0,
    ui.Rect? bounds,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            fontId,
          ], returnAsStringIfText: false);
      final Uint8List? fontData = contentResult[fontId]?['bytes'];

      if (fontData == null) {
        print(
          'addTrueTypeFontPdf error: Font file not found or could not be read for ID: $fontId',
        );
        return null;
      }

      final PdfFont font = PdfTrueTypeFont(fontData, fontSize);
      final PdfPage page = document.pages.add();
      final ui.Rect drawBounds = bounds ?? ui.Rect.fromLTWH(0, 0, 350, 60);
      page.graphics.drawString(
        text,
        font,
        brush: PdfSolidBrush(PdfColor(r, g, b)),
        bounds: drawBounds,
      );
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('addTrueTypeFontPdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 3) Insert an image into a PDF.
  /// imageId: ID of the image file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addImageToPdfAndIndex({
    required String imageId,
    String userSubdir = '',
    String fileName = 'ImageToPDF.pdf',
    ui.Rect? bounds,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            imageId,
          ], returnAsStringIfText: false);
      final Uint8List? imageData = contentResult[imageId]?['bytes'];

      if (imageData == null) {
        print(
          'addImageToPdf error: Image file not found or could not be read for ID: $imageId',
        );
        return null;
      }

      final PdfBitmap image = PdfBitmap(imageData);
      final PdfPage page = document.pages.add();
      final ui.Rect drawBounds = bounds ?? ui.Rect.fromLTWH(0, 0, 500, 200);
      page.graphics.drawImage(image, drawBounds);
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('addImageToPdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 4) Create a PDF with flow layout text. Accepts long text input.
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> createFlowLayoutPdfAndIndex({
    required String text,
    String userSubdir = '',
    String fileName = 'TextFlow.pdf',
    PdfFontFamily fontFamily = PdfFontFamily.helvetica,
    double fontSize = 12,
    ui.Rect? bounds,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final PdfPage page = document.pages.add();
      final PdfTextElement element = PdfTextElement(
        text: text,
        font: PdfStandardFont(fontFamily, fontSize),
        brush: PdfBrushes.black,
      );
      final ui.Rect drawBounds =
          bounds ??
          ui.Rect.fromLTWH(
            0,
            0,
            page.getClientSize().width,
            page.getClientSize().height,
          );
      element.draw(
        page: page,
        bounds: drawBounds,
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      );
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('createFlowLayoutPdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 5) Add bullets and lists.
  /// items: top-level ordered list items.
  /// optionalSubLists: map of index -> List<String> for sublist items.
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addBulletsAndListsPdfAndIndex({
    required List<String> items,
    Map<int, List<String>>? optionalSubLists,
    String userSubdir = '',
    String fileName = 'BulletandList.pdf',
    PdfFontFamily fontFamily = PdfFontFamily.helvetica,
    double fontSize = 12,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final PdfPage page = document.pages.add();
      final PdfOrderedList orderedList = PdfOrderedList(
        items: PdfListItemCollection(items),
        marker: PdfOrderedMarker(
          style: PdfNumberStyle.numeric,
          font: PdfStandardFont(fontFamily, fontSize),
        ),
        markerHierarchy: true,
        format: PdfStringFormat(lineSpacing: 6),
        textIndent: 10,
      );

      if (optionalSubLists != null && optionalSubLists.isNotEmpty) {
        optionalSubLists.forEach((index, subItems) {
          if (index >= 0 && index < orderedList.items.count) {
            orderedList.items[index].subList = PdfUnorderedList(
              marker: PdfUnorderedMarker(
                font: PdfStandardFont(
                  fontFamily,
                  (fontSize - 2).clamp(6, fontSize).toDouble(),
                ),
              ),
              items: PdfListItemCollection(subItems),
              textIndent: 10,
              indent: 20,
            );
          }
        });
      }

      orderedList.draw(
        page: page,
        bounds: ui.Rect.fromLTWH(
          0,
          0,
          page.getClientSize().width,
          page.getClientSize().height,
        ),
      );
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('addBulletsAndListsPdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 6) Create a table from dynamic headers and rows.
  /// headers: list of header titles; rows: list of row lists (each row must match header count).
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addTablesPdfAndIndex({
    required List<String> headers,
    required List<List<String>> rows,
    String userSubdir = '',
    String fileName = 'PDFTable.pdf',
    double headerFontSize = 10,
    double cellFontSize = 9,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: headers.length);

      final PdfGridRow headerRow = grid.headers.add(1)[0];
      for (int i = 0; i < headers.length; i++) {
        headerRow.cells[i].value = headers[i];
      }
      headerRow.style.font = PdfStandardFont(
        PdfFontFamily.helvetica,
        headerFontSize,
        style: PdfFontStyle.bold,
      );

      for (final List<String> r in rows) {
        final PdfGridRow row = grid.rows.add();
        for (int i = 0; i < headers.length; i++) {
          row.cells[i].value = (i < r.length) ? r[i] : '';
        }
      }

      grid.style.cellPadding = PdfPaddings(left: 5, top: 5);
      grid.draw(
        page: page,
        bounds: ui.Rect.fromLTWH(
          0,
          0,
          page.getClientSize().width,
          page.getClientSize().height,
        ),
      );
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('addTablesPdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 7) Add headers and footers content and create the requested number of pages.
  /// headerContent/footerContent will be drawn in a page template.
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addHeadersAndFootersPdfAndIndex({
    required String headerContent,
    required String footerContent,
    int pages = 1,
    String userSubdir = '',
    String fileName = 'HeaderAndFooter.pdf',
    PdfFontFamily fontFamily = PdfFontFamily.helvetica,
    double fontSize = 12,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final PdfPageTemplateElement headerTemplate = PdfPageTemplateElement(
        ui.Rect.fromLTWH(0, 0, 515, 50),
      );
      headerTemplate.graphics.drawString(
        headerContent,
        PdfStandardFont(fontFamily, fontSize),
        bounds: ui.Rect.fromLTWH(0, 15, 400, 20),
      );
      document.template.top = headerTemplate;

      final PdfPageTemplateElement footerTemplate = PdfPageTemplateElement(
        ui.Rect.fromLTWH(0, 0, 515, 50),
      );
      footerTemplate.graphics.drawString(
        footerContent,
        PdfStandardFont(fontFamily, fontSize),
        bounds: ui.Rect.fromLTWH(0, 15, 400, 20),
      );
      document.template.bottom = footerTemplate;

      for (int i = 0; i < pages; i++) {
        document.pages.add();
      }

      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('addHeadersAndFootersPdf error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 8) Load an existing PDF (by ID), draw arbitrary text on a specific page (pageIndex), and save.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> loadAndModifyExistingAndIndex({
    required String inputId,
    required String text,
    int pageIndex = 0,
    ui.Rect? bounds,
    String userSubdir = '',
    String fileName = 'output_modified.pdf',
    PdfFontFamily fontFamily = PdfFontFamily.helvetica,
    double fontSize = 12,
    int r = 0,
    int g = 0,
    int b = 0,
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'loadAndModifyExisting error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        if (pageIndex < 0 || pageIndex >= document.pages.count) {
          print('loadAndModifyExisting error: pageIndex out of range');
          return null;
        }
        final PdfPage page = document.pages[pageIndex];
        final ui.Rect drawBounds = bounds ?? ui.Rect.fromLTWH(0, 0, 300, 50);
        page.graphics.drawString(
          text,
          PdfStandardFont(fontFamily, fontSize),
          brush: PdfSolidBrush(PdfColor(r, g, b)),
          bounds: drawBounds,
        );
        final bytes = await document.save();
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'pdf',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('loadAndModifyExisting error: $e\n$st');
      return null;
    }
  }

  /// 9) Remove a page at index (if present) from existing PDF (by ID) and add a new page with provided content.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addRemovePageFromExistingAndIndex({
    required String inputId,
    String newPageText = 'Hello World!',
    int removePageIndex = 0,
    String userSubdir = '',
    String fileName = 'output_add_remove_page.pdf',
    PdfFontFamily fontFamily = PdfFontFamily.helvetica,
    double fontSize = 12,
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'addRemovePageFromExisting error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        if (document.pages.count > 0 &&
            removePageIndex >= 0 &&
            removePageIndex < document.pages.count) {
          document.pages.removeAt(removePageIndex);
        }
        document.pages.add().graphics.drawString(
          newPageText,
          PdfStandardFont(fontFamily, fontSize),
          bounds: ui.Rect.fromLTWH(0, 0, 300, 50),
        );
        final bytes = await document.save();
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'pdf',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('addRemovePageFromExisting error: $e\n$st');
      return null;
    }
  }

  /// 10) Create a rectangle annotation on a given page and optionally modify its text and color afterwards.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> createAndModifyAnnotationsAndIndex({
    required String inputId,
    int pageIndex = 0,
    required ui.Rect rect,
    String initialText = 'Rectangle',
    String modifiedText = 'Changed',
    PdfColor? initialColor,
    PdfColor? modifiedColor,
    String userSubdir = '',
    String fileName = 'annotations.pdf',
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'createAndModifyAnnotations error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        if (pageIndex < 0 || pageIndex >= document.pages.count) {
          print('createAndModifyAnnotations error: pageIndex out of range');
          return null;
        }
        final PdfPage page = document.pages[pageIndex];
        final PdfRectangleAnnotation ann = PdfRectangleAnnotation(
          rect,
          initialText,
          color: initialColor ?? PdfColor(255, 0, 0),
          setAppearance: true,
        );
        page.annotations.add(ann);

        // Modify the added annotation (last one)
        if (page.annotations.count > 0) {
          final dynamic loaded = page.annotations[page.annotations.count - 1];
          if (loaded is PdfRectangleAnnotation) {
            loaded.text = modifiedText;
            loaded.color = modifiedColor ?? PdfColor(0, 0, 255);
            loaded.setAppearance = true;
          }
        }

        final bytes = await document.save();
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'pdf',
        );
      } catch (e, st) {
        print('createAndModifyAnnotations error: $e\n$st');
        return null;
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('createAndModifyAnnotations error: $e\n$st');
      return null;
    }
  }

  /// 11) Add a bookmark pointing to a specific page.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> addBookmarksAndIndex({
    required String inputId,
    required String title,
    int destinationPageIndex = 0,
    double destOffsetX = 20,
    double destOffsetY = 20,
    String userSubdir = '',
    String fileName = 'bookmark.pdf',
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'addBookmarks error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        final PdfBookmark bookmark = document.bookmarks.add(title);
        final int pageCount = document.pages.count;
        final int pageIndex =
            (destinationPageIndex >= 0 && destinationPageIndex < pageCount)
            ? destinationPageIndex
            : 0;
        bookmark.destination = PdfDestination(
          document.pages[pageIndex],
          ui.Offset(destOffsetX, destOffsetY),
        );
        bookmark.color = PdfColor(255, 0, 0);
        final bytes = await document.save();
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'pdf',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('addBookmarks error: $e\n$st');
      return null;
    }
  }

  /// 12) Extract text from a PDF (by ID). Saves an extracted text file.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created text file on success, null on failure.
  Future<String?> extractTextFromPdfAndIndex({
    required String inputId,
    String userSubdir = '',
    String fileName = 'extracted_text.txt',
    int? startPageIndex,
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'extractTextFromPdf error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String text = extractor.extractText(
          startPageIndex: startPageIndex ?? 0,
        );
        final Uint8List bytes = Uint8List.fromList(
          text.codeUnits,
        ); // Convert string to bytes
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'txt',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('extractTextFromPdf error: $e\n$st');
      return null;
    }
  }

  /// 13) Find texts in a PDF (by ID). Saves results as JSON file with entries (text, pageIndex, bounds).
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created JSON file on success, null on failure.
  Future<String?> findTextInPdfAndIndex({
    required String inputId,
    required List<String> queries,
    String userSubdir = '',
    String fileName = 'find_text_results.json',
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'findTextInPdf error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final List<MatchedItem> matches = extractor.findText(queries);
        final List<Map<String, dynamic>> results = [];
        for (final MatchedItem item in matches) {
          final ui.Rect b = item.bounds;
          results.add({
            'text': item.text,
            'pageIndex': item.pageIndex,
            'bounds': {
              'left': b.left,
              'top': b.top,
              'width': b.width,
              'height': b.height,
            },
          });
        }
        final String jsonString = const JsonEncoder.withIndent(
          ' ',
        ).convert(results);
        final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'json',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('findTextInPdf error: $e\n$st');
      return null;
    }
  }

  /// 14) Encrypt an existing PDF (by ID) and save.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> encryptPdfFileAndIndex({
    required String inputId,
    required String userPassword,
    required String ownerPassword,
    PdfEncryptionAlgorithm algorithm = PdfEncryptionAlgorithm.aesx256Bit,
    String userSubdir = '',
    String fileName = 'secured.pdf',
  }) async {
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = contentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'encryptPdfFile error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        final PdfSecurity security = document.security;
        security.userPassword = userPassword;
        security.ownerPassword = ownerPassword;
        security.algorithm = algorithm;
        final bytes = await document.save();
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'pdf',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('encryptPdfFile error: $e\n$st');
      return null;
    }
  }

  /// 15) Create a PDF conforming to PDF/A and write provided text using provided TTF (by ID).
  /// ttfId: ID of the TTF file in the [FileIndexService].
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> createPdfConformanceAndIndex({
    required String ttfId,
    required String text,
    PdfConformanceLevel conformanceLevel = PdfConformanceLevel.a1b,
    String userSubdir = '',
    String fileName = 'conformance.pdf',
    double fontSize = 12,
  }) async {
    final PdfDocument document = PdfDocument(
      conformanceLevel: conformanceLevel,
    );
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            ttfId,
          ], returnAsStringIfText: false);
      final Uint8List? fontData = contentResult[ttfId]?['bytes'];

      if (fontData == null) {
        print(
          'createPdfConformance error: TTF file not found or could not be read for ID: $ttfId',
        );
        return null;
      }

      document.pages.add().graphics.drawString(
        text,
        PdfTrueTypeFont(fontData, fontSize),
        bounds: ui.Rect.fromLTWH(20, 20, 400, 60),
        brush: PdfBrushes.black,
      );
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('createPdfConformance error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 16) Create a simple PDF form with provided text fields and checkbox fields.
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> createPdfFormAndIndex({
    Map<String, String>? textFields,
    Map<String, bool>? checkboxes,
    String userSubdir = '',
    String fileName = 'form.pdf',
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final PdfPage page = document.pages.add();
      double y = 0;
      if (textFields != null) {
        for (final entry in textFields.entries) {
          final String name = entry.key;
          final String initial = entry.value;
          document.form.fields.add(
            PdfTextBoxField(
              page,
              name,
              ui.Rect.fromLTWH(0, y, 200, 20),
              text: initial,
            ),
          );
          y += 30;
        }
      }
      if (checkboxes != null) {
        for (final entry in checkboxes.entries) {
          final String name = entry.key;
          final bool checked = entry.value;
          document.form.fields.add(
            PdfCheckBoxField(
              page,
              name,
              ui.Rect.fromLTWH(0, y, 20, 20),
              isChecked: checked,
            ),
          );
          y += 30;
        }
      }
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('createPdfForm error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  Future<String?> signPdfNewAndIndex({
    required String pfxId,
    required String pfxPassword,
    String userSubdir = '',
    String fileName = 'signed.pdf',
    ui.Rect? bounds,
  }) async {
    final PdfDocument document = PdfDocument();
    try {
      final Map<String, Map<String, dynamic>> contentResult =
          await _fileIndexService.getContentsByIds([
            pfxId,
          ], returnAsStringIfText: false);
      final Uint8List? pfxBytes = contentResult[pfxId]?['bytes'];

      if (pfxBytes == null) {
        print(
          'signPdfNew error: PFX certificate file not found or could not be read for ID: $pfxId',
        );
        return null;
      }

      final PdfPage page = document.pages.add();
      final ui.Rect sigBounds = bounds ?? ui.Rect.fromLTWH(0, 0, 200, 50);
      final PdfCertificate cert = PdfCertificate(pfxBytes, pfxPassword);
      final PdfSignatureField signatureField = PdfSignatureField(
        page,
        'Signature',
        bounds: sigBounds,
        signature: PdfSignature(certificate: cert),
      );
      document.form.fields.add(signatureField);
      final bytes = await document.save();
      return await _saveAndIndexFile(
        Uint8List.fromList(bytes),
        userSubdir,
        fileName,
        'pdf',
      );
    } catch (e, st) {
      print('signPdfNew error: $e\n$st');
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 19) Sign an existing PDF (by ID) that already contains a signature field.
  /// inputId: ID of the input PDF file in the [FileIndexService].
  /// pfxId: ID of the PFX certificate file in the [FileIndexService].
  /// Assumes the first signature field is the one to sign (or provide index).
  /// Returns the ID of the created file on success, null on failure.
  Future<String?> signExistingPdfAndIndex({
    required String inputId,
    required String pfxId,
    required String pfxPassword,
    int signatureFieldIndex = 0,
    String userSubdir = '',
    String fileName = 'output_signed.pdf',
  }) async {
    try {
      final Map<String, Map<String, dynamic>> inputPdfContentResult =
          await _fileIndexService.getContentsByIds([
            inputId,
          ], returnAsStringIfText: false);
      final Uint8List? inputBytes = inputPdfContentResult[inputId]?['bytes'];

      if (inputBytes == null) {
        print(
          'signExistingPdf error: Input PDF file not found or could not be read for ID: $inputId',
        );
        return null;
      }

      final Map<String, Map<String, dynamic>> pfxContentResult =
          await _fileIndexService.getContentsByIds([
            pfxId,
          ], returnAsStringIfText: false);
      final Uint8List? pfxBytes = pfxContentResult[pfxId]?['bytes'];

      if (pfxBytes == null) {
        print(
          'signExistingPdf error: PFX certificate file not found or could not be read for ID: $pfxId',
        );
        return null;
      }

      final PdfDocument document = PdfDocument(inputBytes: inputBytes);
      try {
        if (document.form.fields.count > signatureFieldIndex) {
          final dynamic field = document.form.fields[signatureFieldIndex];
          if (field is PdfSignatureField) {
            field.signature = PdfSignature(
              certificate: PdfCertificate(pfxBytes, pfxPassword),
            );
          } else {
            print(
              'signExistingPdf error: field at index is not a PdfSignatureField',
            );
            return null;
          }
        } else {
          print('signExistingPdf error: signature field index out of range');
          return null;
        }
        final bytes = await document.save();
        return await _saveAndIndexFile(
          Uint8List.fromList(bytes),
          userSubdir,
          fileName,
          'pdf',
        );
      } finally {
        document.dispose();
      }
    } catch (e, st) {
      print('signExistingPdf error: $e\n$st');
      return null;
    }
  }
}

/// A provider that exposes the [PdfCreationHelper].
/// This allows other parts of your application to easily access
/// the PDF creation and indexing functionalities.
final pdfCreationHelperProvider = Provider<PdfCreationHelper>((ref) {
  final fileIndexService = ref.watch(fileIndexServiceProvider);
  return PdfCreationHelper(fileIndexService);
});
