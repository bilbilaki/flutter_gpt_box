abstract final class Urls {
  static const myGithub = 'https://github.com/lollipopkit';
  static const repoBase = '$myGithub/flutter_gpt_box';
  static const serverBoxRepo = '$myGithub/flutter_server_box';
  static const repoDiscussion = '$repoBase/discussions';
  static const repoIssue = '$repoBase/issues';
  static const unilinkDoc = '$repoBase/blob/main/doc/uni_link.md';
  static const openaiRestoreDoc = '$repoBase/blob/main/doc/openai_restore.md';

  static const backendBase = 'https://cdn.lpkt.cn/gptbox/';
  static const appUpdateCfg = '${backendBase}update2.json';

  /// Github models url has no '/v1' suffix
  static const githubModels = 'https://models.inference.ai.azure.com';
}
