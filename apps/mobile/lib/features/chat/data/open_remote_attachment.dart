import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a remote URL to a temp file and opens it with the system viewer.
Future<void> openRemoteAttachment({
  required String url,
  String? fileName,
}) async {
  final safeName = (fileName ?? 'attachment')
      .replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final dir = await getTemporaryDirectory();
  final path =
      '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}_$safeName';
  final response = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Empty download');
  }
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(file.path);
}
