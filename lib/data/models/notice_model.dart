import 'package:html_unescape/html_unescape.dart';

/// Notice model representing a news/announcement item
class Notice {
  final int newsId;
  final String newsTitle;
  final String? newsText;
  final String? newsUrl;
  final String? newsDoc;
  final DateTime newsDate;
  final bool isNew;

  Notice({
    required this.newsId,
    required this.newsTitle,
    this.newsText,
    this.newsUrl,
    this.newsDoc,
    required this.newsDate,
    required this.isNew,
  });

  /// Get the type of notice based on available content
  NoticeType get type {
    if (newsDoc != null && newsDoc!.isNotEmpty) return NoticeType.pdf;
    if (newsUrl != null && newsUrl!.isNotEmpty) return NoticeType.link;
    return NoticeType.text;
  }

  /// Get the PDF filename from the full URL
  String? get pdfFileName {
    if (newsDoc == null) return null;
    return newsDoc!.replaceAll('https://odishajee.com/news_document/', '');
  }

  /// Factory constructor to create Notice from JSON
  factory Notice.fromJson(Map<String, dynamic> json) {
    final rawNewsId = json['news_id'];
    final rawIsNew = json['is_new'];
    final rawNewsDate = json['news_date'];

    return Notice(
      newsId: int.tryParse(rawNewsId?.toString() ?? '') ?? 0,
      newsTitle: HtmlUnescape().convert(json['news_title'] ?? ''),
      newsText: json['news_text'],
      newsUrl: json['news_url'],
      newsDoc: json['news_doc'],
      newsDate:
          DateTime.tryParse(rawNewsDate?.toString() ?? '') ?? DateTime.now(),
      isNew: rawIsNew == true || rawIsNew == 1 || rawIsNew == '1',
    );
  }

  /// Convert Notice to JSON
  Map<String, dynamic> toJson() {
    return {
      'news_id': newsId,
      'news_title': newsTitle,
      'news_text': newsText,
      'news_url': newsUrl,
      'news_doc': newsDoc,
      'news_date': newsDate.toIso8601String(),
      'is_new': isNew ? 1 : 0,
    };
  }
}

/// Type of notice content
enum NoticeType { text, link, pdf }

/// Extension to get display properties for NoticeType
extension NoticeTypeExtension on NoticeType {
  String get label {
    switch (this) {
      case NoticeType.text:
        return 'Text';
      case NoticeType.link:
        return 'Link';
      case NoticeType.pdf:
        return 'PDF';
    }
  }

  String get iconPath {
    switch (this) {
      case NoticeType.text:
        return 'comment-alt';
      case NoticeType.link:
        return 'external-link-alt';
      case NoticeType.pdf:
        return 'file-pdf';
    }
  }
}
