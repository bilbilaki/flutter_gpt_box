part of '../tool.dart';

final class TfUrlLuancher extends ToolFunc {
  static const instance = TfUrlLuancher._();
  const TfUrlLuancher._()
    : super(
        name: 'urlluancher',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'the url model want open that for user.',
            },
          },
          'required': ['url'],
        },
      );
  @override
  String get description => '''
call this tool and pass url to opening that for user''';

  @override
  String get l10nName => "urlluancher";

  // And update the help(...) override to use the fallback if needed:

  // ...existing code...
  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final url = args['url'] as String?;

    if (url == null || url.isEmpty) {
      final error = ToolError.invalidInput(
        'url',
        suggestion: 'Provide a valid URL (e.g., "https://example.com").',
      );
      log('URL Launcher Error: ${error.toMessage()}');
      return [ChatContent.text(error.toMessage())];
    }

    log('Opening URL: $url');

    try {
      final success = await launchUrl(Uri.parse(url));
      
      return success
          ? [ChatContent.text('Successfully opened URL for the user.')]
          : [ChatContent.text(
              ToolError.executionFailed(
                'Failed to open URL',
                suggestion: 'Verify the URL is valid and a compatible app is available.',
              ).toMessage(),
            )];
    } catch (e) {
      final error = ToolError.executionFailed(
        'URL launch failed: $e',
        suggestion: 'Ensure the URL is properly formatted and a handler app is available.',
      );
      log('URL Launcher Error: ${error.toMessage()}');
      return [ChatContent.text(error.toMessage())];
    }
  }
}
