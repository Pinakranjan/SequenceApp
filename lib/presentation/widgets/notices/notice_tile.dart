import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/services/pdf_cache_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/notice_model.dart';
import 'package:intl/intl.dart';

/// Notice list tile widget
class NoticeTile extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;
  final int index;
  final bool hasReminder;

  const NoticeTile({
    super.key,
    required this.notice,
    required this.onTap,
    this.index = 0,
    this.hasReminder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isPdf = notice.type == NoticeType.pdf && notice.newsDoc != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getTypeColor(notice.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: FaIcon(
                              _getTypeIcon(notice.type),
                              color: _getTypeColor(notice.type),
                              size: 20,
                            ),
                          ),
                          if (isPdf)
                            Positioned(
                              right: -6,
                              bottom: -6,
                              child: FutureBuilder<bool>(
                                future: PdfCacheService().isDownloaded(notice),
                                builder: (context, snapshot) {
                                  final downloaded = snapshot.data == true;
                                  if (!downloaded) {
                                    return const SizedBox.shrink();
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.download_done,
                                      size: 12,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with NEW badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notice.newsTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (notice.isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'NEW',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Date
                        Text(
                          _formatDate(notice.newsDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),

          if (hasReminder)
            Positioned(
              right: 12,
              bottom: 12,
              child: Icon(
                Icons.notifications_active,
                size: 18,
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(NoticeType type) {
    switch (type) {
      case NoticeType.pdf:
        return FontAwesomeIcons.filePdf;
      case NoticeType.link:
        return FontAwesomeIcons.upRightFromSquare;
      case NoticeType.text:
        return FontAwesomeIcons.message;
    }
  }

  Color _getTypeColor(NoticeType type) {
    switch (type) {
      case NoticeType.pdf:
        return AppColors.pdfColor;
      case NoticeType.link:
        return AppColors.linkColor;
      case NoticeType.text:
        return AppColors.textColor;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }
}
