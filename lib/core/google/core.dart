import 'dart:convert';
import 'package:googleapis/calendar/v3.dart' as calendar;

import 'package:google_sign_in/google_sign_in.dart' as go;

import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:gpt_box/env.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
part 'gmail.dart';
part 'calendar.dart';

GoogleSignIn _googleSignIn = GoogleSignIn(
  params: GoogleSignInParams(
    clientId: clientid,
    clientSecret: clientsecret,
    scopes: const ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email', 'https://www.googleapis.com/auth/firebase.messaging', 'https://www.googleapis.com/auth/firebase', 'https://www.googleapis.com/auth/firebase.readonly', 'https://www.googleapis.com/auth/firebase.hosting', 'https://www.googleapis.com/auth/youtube.download', 'https://www.googleapis.com/auth/calendar.app.created', 'https://www.googleapis.com/auth/calendar.calendarlist.readonly', 'https://www.googleapis.com/auth/calendar.events.freebusy', 'https://www.googleapis.com/auth/calendar.freebusy', 'https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive.appdata', 'https://www.googleapis.com/auth/generative-language.peruserquota', 'https://www.googleapis.com/auth/gmail.addons.current.action.compose', 'https://www.googleapis.com/auth/gmail.addons.current.message.action'],
    redirectPort: 8000,
  ),
);

Future<void> performSignIn() async {
  final credentials = await _googleSignIn.signIn();
  if (credentials != null) {
    print('Signed in successfully: ${credentials.accessToken}');
  } else {
    print('Sign in failed');
  }
}

Future<void> performSignOut() async {
  await _googleSignIn.signOut();
  print('Signed out successfully');
}

Future<_AuthenticatedClient> getClient()async {

    final credentials = await _googleSignIn.signIn();

  final goSighnIn = go.GoogleSignIn(
    signInOption: go.SignInOption.standard,
    scopes: credentials!.scopes,
    hostedDomain: 'localhost',
    clientId: credentials.idToken,
  );
await  goSighnIn.signIn();
  final auth = await goSighnIn.currentUser!.authHeaders;
  final client = _AuthenticatedClient(
    http.Client(),
    auth,
  );

  return client;
}