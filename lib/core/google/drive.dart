import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:gpt_box/core/google/core.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Function to get Drive API service
Future<drive.DriveApi?> getDriveApi() async {
  final authenticatedClient = await getAuthenticatedClient();
  if (authenticatedClient == null) {
    return null;
  }
  return drive.DriveApi(authenticatedClient);
}

Future<bool> isNeedSignDrive() async {
  final answer = await getDriveApi();

  return answer == null ? true : false;
}

// --- Upload Backup Data ---
Future<void> uploadAppDataToDrive(String fileName, List<int> data) async {
  try {
    final driveApi = await getDriveApi();
    if (driveApi == null) return;

    final driveFile = drive.File();
    driveFile.name = fileName;
    // 'appDataFolder' refers to the hidden app-specific folder
    // 'root' refers to the user's main Google Drive
    driveFile.parents = ['appDataFolder'];

    final response = await driveApi.files.create(
      driveFile,
      uploadMedia: drive.Media(Stream.fromIterable([data]), data.length),
    );
    print('Backup file uploaded: ${response.name} (ID: ${response.id})');
  } catch (e) {
    print('Error uploading app data to Drive: $e');
  }
}

// --- List Backup Data ---
Future<List<drive.File>?> listAppDataFromDrive() async {
  try {
    final driveApi = await getDriveApi();
    if (driveApi == null) return null;

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id, name, modifiedTime, size)', // Request specific fields
    );
    return fileList.files;
  } catch (e) {
    print('Error listing app data from Drive: $e');
    return null;
  }
}

// --- Download Backup Data ---
Future<File?> downloadAppDataFromDrive(String fileId, String fileName) async {
  try {
    final driveApi = await getDriveApi();
    if (driveApi == null) return null;

    drive.Media file =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    // Determine download path based on platform
    String? localPath;
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS) {
      final directory =
          await getApplicationDocumentsDirectory(); // Or getExternalStorageDirectory() for user visible
      localPath = '${directory.path}/$fileName';
      final saveFile = File(localPath);
      List<int> dataStore = [];
      await for (var data in file.stream) {
        dataStore.addAll(data);
      }
      await saveFile.writeAsBytes(dataStore);
      print("File saved at ${saveFile.path}");
      return saveFile;
    }
  } catch (e) {
    print('Error downloading app data from Drive: $e');
    return null;
  }
  return null;
}

// --- Example Usage in your Widget/StatefulWidget ---
// Call this after a successful signIn or on app start
// Check if user is signed in on app start
// Future<void> checkSignInStatus() async {
//   _currentCredentials = await _loadCredentials();
//   if (_currentCredentials != null) {
//     print('User is potentially logged in. Try refreshing token silently.');
//     await getAuthenticatedClient(); // This will try to silently refresh if needed
//   } else {
//     print('User is not logged in.');
//   }
//   // Update UI based on _currentCredentials == null or not
// }

// In a button press for upload:
void onUploadButtonPressed() async {
  // Example data (replace with your actual app data)
  final String appData = jsonEncode({
    'setting1': 'value',
    'data': [1, 2, 3],
  });
  final List<int> bytes = utf8.encode(appData);
  await uploadAppDataToDrive(
    'my_app_backup_${DateTime.now().toIso8601String()}.json',
    bytes,
  );
}

// In a button press for list:
void onListButtonPressed() async {
  final files = await listAppDataFromDrive();
  if (files != null && files.isNotEmpty) {
    print('Found backup files:');
    for (var file in files) {
      print(
        '- ${file.name} (ID: ${file.id}, Modified: ${file.modifiedTime}, Size: ${file.size} bytes)',
      );
    }
    // You can then display these in a ListView for the user to select
  } else {
    print('No backup files found.');
  }
}

// In a button press for download (e.g., after selecting from a list):
void onDownloadButtonPressed(String fileId, String fileName) async {
  final downloadedFile = await downloadAppDataFromDrive(fileId, fileName);
  if (downloadedFile != null) {
    print('Backup restored from: ${downloadedFile.path}');
    // Now you can read downloadedFile.readAsString() and parse your JSON
    // to restore app state.
  } else {
    print('Failed to download backup.');
  }
}
