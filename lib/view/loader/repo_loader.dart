import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class RepoUtils {
  /// Transforms a GitHub URL into a ZIP download URL
  /// e.g. https://github.com/user/repo -> https://github.com/user/repo/archive/refs/heads/main.zip
  static String? getZipUrl(String originalUrl, {String branch = "main"}) {
    if (!originalUrl.contains("github.com")) return null; // Basic validation
    
    // Clean the URL (remove .git if present)
    String cleanUrl = originalUrl.endsWith(".git") 
        ? originalUrl.substring(0, originalUrl.length - 4) 
        : originalUrl;
    
    // GitHub standard archive format
    return "$cleanUrl/archive/refs/heads/$branch.zip";
  }

  static Future<String> downloadAndExtract(String repoUrl) async {
    final zipUrl = getZipUrl(repoUrl);
    if (zipUrl == null) throw Exception("Invalid GitHub URL");

    // 1. Download
    final response = await http.get(Uri.parse(zipUrl));
    if (response.statusCode != 200) {
      // Fallback: Try 'master' branch if 'main' fails
      if (zipUrl.endsWith("main.zip")) {
        return downloadAndExtract(repoUrl.replaceAll("main", "master")); // Simple recursive retry
      }
      throw Exception("Failed to download repo. Status: ${response.statusCode}");
    }

    // 2. Decode Zip
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);

    // 3. Save to App Documents
    final dir = await getApplicationDocumentsDirectory();
    // Create a unique folder for this download
    final repoName = repoUrl.split("/").last.replaceAll(".git", "");
    final destination = Directory("${dir.path}/$repoName");
    
    if (await destination.exists()) await destination.delete(recursive: true);
    await destination.create();

    // 4. Extract
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File('${destination.path}/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory('${destination.path}/$filename').createSync(recursive: true);
      }
    }

    // GitHub zips usually put everything inside a root folder (e.g. repo-main/).
    // We want to return that root folder path.
    final entities = destination.listSync();
    if (entities.length == 1 && entities.first is Directory) {
      return entities.first.path;
    }

    return destination.path;
  }
}