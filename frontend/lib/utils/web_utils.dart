/// Утилиты для веб-платформы
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Открытие URL в новой вкладке (только для веб)
void openUrlInNewTab(String url) {
  if (kIsWeb) {
    html.window.open(url, '_blank');
  }
}

/// Скачивание файла через blob (только для веб)
void downloadFileFromBytes(List<int> bytes, String filename) {
  if (kIsWeb) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

