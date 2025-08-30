import 'dart:convert'; // Required for base64Decode
import 'dart:typed_data'; // Required for Uint8List

import 'package:before_after/before_after.dart';
import 'package:flutter/material.dart';

/// A Flutter widget that displays an image from a Base64 string.
/// Tapping the image will open a full-screen view with zoom and pan capabilities.
class Base64ImageDisplay extends StatelessWidget {
  /// The Base64 string representing the image data.
  final String base64String;
  String? bas;
  double? value = 0.5;
  void Function()? postCallback;

  /// How the image should be inscribed in the space allocated for it.
  /// Defaults to [BoxFit.contain].
  final BoxFit fit;

  /// The width to constrain the image to.
  /// If null, the image will be sized based on its natural dimensions or parent constraints.
  final double? width;

  /// The height to constrain the image to.
  /// If null, the image will be sized based on its natural dimensions or parent constraints.
  final double? height;

  /// A widget to display if the Base64 string is invalid or decoding fails.
  /// Defaults to a grey container with an error icon.
  final Widget? errorWidget;

  /// A widget to display if the decoded image data is empty or null.
  /// Defaults to a grey container with a "No Image" text.
  final Widget? noImageWidget;

  Base64ImageDisplay({
    Key? key,
    required this.base64String,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.bas,
    this.errorWidget,
    this.noImageWidget,
    this.postCallback,
    this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;

    try {
      // Decode the Base64 string into a Uint8List (bytes)
      imageBytes = base64Decode(base64String);
    } catch (e) {
      // Handle cases where the base64String is not a valid Base64 format
      print("Error decoding Base64 string: $e");
      return errorWidget ??
          _buildDefaultErrorWidget(
            width,
            height,
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
          );
    }

    if (imageBytes == null || imageBytes.isEmpty) {
      // Handle cases where the decoded bytes are empty (e.g., empty base64 string)
      return noImageWidget ??
          _buildDefaultErrorWidget(
            width,
            height,
            const Text("No Image", style: TextStyle(color: Colors.black54)),
          );
    }

    // If decoding is successful and bytes are not empty, display the image
    return GestureDetector(
      onTap: () {
        // Navigate to the full-screen viewer when the image is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => bas != null
                ? BeforeAfter(
                    value: value!,
                    before: Image.memory(base64Decode(bas!)),
                    after: Image.memory(imageBytes!),
                    onValueChanged: (value) {
                      value = value;
                      postCallback;
                    },
                  )
                : FullScreenImageViewer(
                    imageBytes:
                        imageBytes!, // `imageBytes` is guaranteed non-null here
                  ),
          ),
        );
      },
      child: Image.memory(
        imageBytes!, // `imageBytes` is guaranteed non-null here
        fit: fit,
        width: width,
        height: height,
        // errorBuilder catches issues AFTER decoding, like malformed image data within valid bytes
        errorBuilder: (context, error, stackTrace) {
          print("Error loading image from bytes: $error");
          return errorWidget ??
              _buildDefaultErrorWidget(
                width,
                height,
                const Icon(Icons.broken_image, color: Colors.red, size: 40),
              );
        },
      ),
    );
  }

  // Helper to build a default error/placeholder widget
  Widget _buildDefaultErrorWidget(double? width, double? height, Widget child) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// A full-screen viewer for an image represented by [Uint8List] bytes.
/// Provides zoom and pan capabilities via [InteractiveViewer].
class FullScreenImageViewer extends StatelessWidget {
  /// The image data as a [Uint8List].
  final Uint8List imageBytes;

  /// Optional background color for the full-screen view.
  /// Defaults to [Colors.black].
  final Color backgroundColor;

  /// Optional title for the AppBar in full-screen mode.
  final String? title;

  const FullScreenImageViewer({
    Key? key,
    required this.imageBytes,
    this.backgroundColor = Colors.black,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: title != null
            ? Text(title!, style: const TextStyle(color: Colors.white))
            : null,
        backgroundColor: Colors.transparent, // Transparent AppBar over image
        iconTheme: const IconThemeData(color: Colors.white), // White back arrow
        elevation: 0, // No shadow for the AppBar
      ),
      body: Center(
        // InteractiveViewer allows users to zoom and pan the image
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(
            20.0,
          ), // Margin around the content
          minScale: 0.1, // Minimum zoom level
          maxScale: 4.0, // Maximum zoom level
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain, // Ensure the entire image is visible initially
            errorBuilder: (context, error, stackTrace) {
              print("Error loading full-screen image from bytes: $error");
              return const Center(
                child: Text(
                  "Failed to load full-screen image",
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- Example Usage (Optional, for demonstration purposes) ---
// You can uncomment and run this main function to see the widget in action.
/*
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // A very small, simple Base64 encoded PNG (a tiny blue square)
  final String _exampleBase64Image =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";

  // An example of an invalid Base64 string
  final String _invalidBase64String = "this-is-not-base64!";

  // An example of a valid Base64 but not image data
  final String _nonImageData = base64Encode(utf8.encode("Hello, this is not an image."));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Base64 Image Display',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Base64 Image Widget'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valid Base64 Image:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Display a valid Base64 image
              Base64ImageDisplay(
                base64String: _exampleBase64Image,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 30),
              const Text(
                'Invalid Base64 String (Error Handling):',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Display an invalid Base64 string
              Base64ImageDisplay(
                base64String: _invalidBase64String,
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 30),
              const Text(
                'Empty Base64 String (No Image Data):',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Display an empty Base64 string
              Base64ImageDisplay(
                base64String: "",
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 30),
              const Text(
                'Valid Base64 but Not Image Data (Image Error):',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Display Base64 that decodes but isn't a valid image format
              Base64ImageDisplay(
                base64String: _nonImageData,
                width: 150,
                height: 150,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
