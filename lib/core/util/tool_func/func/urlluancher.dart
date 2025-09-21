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
    final cmd = args['url'] as String?;

    log(
      'Opening Url -> $args'
      '}',
    );


    // Start a process so we can stream stdout/stderr
    final proc = await launchUrl(Uri.parse(cmd!));

     proc;
return proc==true?       [ChatContent.text("successfully Url opened for user")]:       [ChatContent.text("failed to open url for user")];


  }
}
