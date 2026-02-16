import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/notice_model.dart';
import '../utils/api_error_handler.dart';

class PdfCacheService {
  static const String _pdfCacheFolderName = 'ojee2026_pdfs';

  Future<Directory> getCacheDir() async {
    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      // Fallback: should still allow offline read within session.
      base = Directory.systemTemp;
    }

    final dir = Directory('${base.path}/$_pdfCacheFolderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String sanitizeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\/\\:\\s]+'), '_');
    if (sanitized.isEmpty) return 'document.pdf';
    return sanitized;
  }

  Future<String> localPathForNotice(Notice notice) async {
    final dir = await getCacheDir();
    final fileName = notice.pdfFileName ?? 'document.pdf';
    final safe = sanitizeFileName(fileName);
    return '${dir.path}/${notice.newsId}_$safe';
  }

  Future<bool> isDownloaded(Notice notice) async {
    if (notice.type != NoticeType.pdf || notice.newsDoc == null) return false;
    final path = await localPathForNotice(notice);
    return File(path).exists();
  }

  Future<String?> getLocalPathIfExists(Notice notice) async {
    final path = await localPathForNotice(notice);
    final file = File(path);
    if (await file.exists()) return path;
    return null;
  }

  /// Downloads the notice PDF into persistent app documents storage.
  /// Returns the local file path.
  Future<String> download(Notice notice) async {
    final url = notice.newsDoc;
    if (url == null || url.isEmpty) {
      throw Exception('Missing PDF URL');
    }

    final path = await localPathForNotice(notice);

    final file = File(path);
    if (await file.exists()) return path;

    try {
      final dio = Dio();
      await dio.download(url, path);
      return path;
    } on DioException catch (e) {
      throw Exception(ApiErrorHandler.handleDioError(e));
    }
  }
}
