part of 'core.dart';

Future<void> sendGmail() async {
  final client = await getClient();

  final gmailApi = gmail.GmailApi(client);

  final message = gmail.Message()
    ..raw = base64Url.encode(
      utf8.encode(
        "From: me\n"
        "To: someone@example.com\n"
        "Subject: Hello from Flutter\n\n"
        "This is a test email!",
      ),
    );

  await gmailApi.users.messages.send(message, 'me');
}

// class _AuthenticatedClient extends http.BaseClient {
//   final Map<String, String> _headers;
//   final http.Client _client;

//   _AuthenticatedClient(this._client, this._headers);

//   @override
//   Future<http.StreamedResponse> send(http.BaseRequest request) {
//     return _client.send(request..headers.addAll(_headers));
//   }
// }
