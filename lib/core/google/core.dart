import 'dart:convert';
import 'package:googleapis/calendar/v3.dart' as calendar;

import 'package:google_sign_in/google_sign_in.dart' as go;

import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:gpt_box/env.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive; // Alias for Drive API

// ... (your existing imports and _googleSignIn
import 'package:http/io_client.dart';
part 'gmail.dart';
part 'calendar.dart';

GoogleSignIn _googleSignIn = GoogleSignIn(
  params: GoogleSignInParams(
    clientId: '',
    clientSecret: '',
    scopes: const [
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.messaging',
      'https://www.googleapis.com/auth/firebase',
      'https://www.googleapis.com/auth/firebase.readonly',
      'https://www.googleapis.com/auth/firebase.hosting',
      'https://www.googleapis.com/auth/youtube.download',
      'https://www.googleapis.com/auth/calendar.app.created',
      'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
      'https://www.googleapis.com/auth/calendar.events.freebusy',
      'https://www.googleapis.com/auth/calendar.freebusy',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/generative-language.peruserquota',
      'https://www.googleapis.com/auth/gmail.addons.current.action.compose',
      'https://www.googleapis.com/auth/gmail.addons.current.message.action',
    ],
    redirectPort: 8000,
  ),
);

// Future<void> performSignIn() async {
//   final credentials = await _googleSignIn.signIn();
//   if (credentials != null) {
//     print('Signed in successfully: ${credentials.accessToken}');
//   } else {
//     print('Sign in failed');
//   }
// }

// Future<void> performSignOut() async {
//   await _googleSignIn.signOut();
//   print('Signed out successfully');
// }

Future<_AuthenticatedClient> getClient() async {
  final credentials = await _googleSignIn.signIn();

  final goSighnIn = go.GoogleSignIn(
    signInOption: go.SignInOption.standard,
    scopes: credentials!.scopes,
    hostedDomain: 'localhost',
    clientId: credentials.idToken,
  );
  await goSighnIn.signIn();
  final auth = await goSighnIn.currentUser!.authHeaders;
  final client = _AuthenticatedClient(http.Client(), auth);

  return client;
}

// main.dart (or a separate file if you prefer)
class _AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  _AuthenticatedClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

// Secure Storage for persistence
final _storage = FlutterSecureStorage();

// Global variable to hold current credentials
GoogleSignInCredentials? _currentCredentials;

// --- Persistence Functions ---
Future<void> _saveCredentials(GoogleSignInCredentials credentials) async {
  await _storage.write(key: 'accessToken', value: credentials.accessToken);
  await _storage.write(key: 'refreshToken', value: credentials.refreshToken);
  await _storage.write(key: 'idToken', value: credentials.idToken);
  // Optionally save expiry time, scope, etc.
  _currentCredentials = credentials;
  print('Credentials saved securely.');
}

Future<GoogleSignInCredentials?> _loadCredentials() async {
  final accessToken = await _storage.read(key: 'accessToken');
  final refreshToken = await _storage.read(key: 'refreshToken');
  final idToken = await _storage.read(key: 'idToken');

  if (accessToken != null && refreshToken != null && idToken != null) {
    // You might want to check if the accessToken is expired here,
    // and if so, try to refresh it using the refreshToken.
    // google_sign_in_all_platforms *should* handle this internally with signInSilently
    // when using a stored refresh token.
    _currentCredentials = GoogleSignInCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      scopes: const [
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/firebase.messaging',
        'https://www.googleapis.com/auth/firebase',
        'https://www.googleapis.com/auth/firebase.readonly',
        'https://www.googleapis.com/auth/firebase.hosting',
        'https://www.googleapis.com/auth/youtube.download',
        'https://www.googleapis.com/auth/calendar.app.created',
        'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
        'https://www.googleapis.com/auth/calendar.events.freebusy',
        'https://www.googleapis.com/auth/calendar.freebusy',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.appdata',
        'https://www.googleapis.com/auth/generative-language.peruserquota',
        'https://www.googleapis.com/auth/gmail.addons.current.action.compose',
        'https://www.googleapis.com/auth/gmail.addons.current.message.action',
      ], // Re-use the configured scopes
      // Other fields might be needed depending on the exact GoogleSignInCredentials class
      // In this specific package, it seems to be just these tokens.
    );
    print('Credentials loaded from storage.');
    return _currentCredentials;
  }
  print('No credentials found in storage.');
  return null;
}

Future<GoogleSignInCredentials?> _loadCredentialsForCloudSignIn() async {
  final accessToken = await _storage.read(key: 'accessToken');
  final refreshToken = await _storage.read(key: 'refreshToken');
  final idToken = await _storage.read(key: 'idToken');

  if (accessToken != null && refreshToken != null && idToken != null) {
    // You might want to check if the accessToken is expired here,
    // and if so, try to refresh it using the refreshToken.
    // google_sign_in_all_platforms *should* handle this internally with signInSilently
    // when using a stored refresh token.
    _currentCredentials = GoogleSignInCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      scopes: const [
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.appdata',
        'https://www.googleapis.com/auth/generative-language.peruserquota',
        'https://www.googleapis.com/auth/gmail.addons.current.action.compose',
        'https://www.googleapis.com/auth/gmail.addons.current.message.action',

        // ADD THIS NEW SCOPE FOR LISTING PROJECTS
        //  'https://www.googleapis.com/auth/cloud-platform.read-only',
      ], // Re-use the configured scopes
      // Other fields might be needed depending on the exact GoogleSignInCredentials class
      // In this specific package, it seems to be just these tokens.
    );
    print('Credentials loaded from storage.');
    return _currentCredentials;
  }
  print('No credentials found in storage.');
  return null;
}

Future<void> performSignIn() async {
  try {
    final credentials = await _googleSignIn.signIn();
    if (credentials != null) {
      _currentCredentials = credentials;
      await _saveCredentials(
        credentials,
      ); // Save credentials after successful sign-in
      print('Signed in successfully: ${credentials.accessToken}');
    } else {
      print('Sign in failed');
    }
  } catch (e) {
    print('Sign in error: $e');
  }
}

Future<void> performSignOut() async {
  await _googleSignIn.signOut();
  await _storage.deleteAll(); // Clear stored credentials
  _currentCredentials = null;
  print('Signed out successfully');
}

// Modified getClient to manage persistence and token refreshing
Future<_AuthenticatedClient?> getAuthenticatedClient({
  bool useforgemini = false,
}) async {
  useforgemini
      ? _currentCredentials = await _loadCredentialsForCloudSignIn()
      : _currentCredentials ??= await _loadCredentials();

  if (_currentCredentials == null) {
    // If not in storage, try silent sign-in (might refresh token)
    _currentCredentials = await _googleSignIn.signIn();
    if (_currentCredentials != null) {
      await _saveCredentials(
        _currentCredentials!,
      ); // Save refreshed credentials
    }
  }

  if (_currentCredentials == null) {
    // If still not authenticated, user needs to sign in interactively
    print('User not signed in. Please call performSignIn() first.');
    return null;
  }

  // Construct auth headers
  final authHeaders = {
    'Authorization': 'Bearer ${_currentCredentials!.accessToken}',
    'X-Goog-AuthUser':
        '0', // Or other values if specific multi-user handling is needed
  };

  return _AuthenticatedClient(http.Client(), authHeaders);
}

class GoogleCloudProject {
  final String projectId; // e.g., "my-cool-project-12345"
  final String name; // e.g., "My Cool Project"

  GoogleCloudProject({required this.projectId, required this.name});

  factory GoogleCloudProject.fromJson(Map<String, dynamic> json) {
    return GoogleCloudProject(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
    );
  }
}

Future<List<GoogleCloudProject>> fetchUserGoogleCloudProjects() async {
  final client = await getAuthenticatedClient(useforgemini: true);
  if (client == null) {
    print("Cannot fetch projects, user not signed in.");
    return []; // Return empty list if not signed in
  }

  final url = Uri.parse(
    'https://cloudresourcemanager.googleapis.com/v1/projects',
  );

  try {
    final response = await client.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['projects'] != null) {
        final List<dynamic> projectListJson = data['projects'];
        return projectListJson
            .map((json) => GoogleCloudProject.fromJson(json))
            .toList();
      }
      return []; // No projects found
    } else {
      print(
        'Failed to fetch projects: ${response.statusCode} ${response.body}',
      );
      return [];
    }
  } catch (e) {
    print('Error fetching Google Cloud projects: $e');
    return [];
  }
}
