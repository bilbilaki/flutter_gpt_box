import 'package:gpt_box/core/services/file_index.dart';
import 'package:riverpod/riverpod.dart';


final fileIndexServiceProvider = Provider<FileIndexService>((ref) {
  return FileIndexService.instance;
});