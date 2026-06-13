import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/data/models/content.dart';

/// Reusable overlay dialog with pagination support, configurable controls,
/// and two visual modes (content with white background, or video-only
/// with transparent background).
class BetelDialog extends StatefulWidget {
  /// Content widgets for each page. A single item disables pagination.
  final List<Widget> pages;

  /// Show a back button (‹) on the top-left corner. Default: false.
  final bool showBackButton;

  /// Show a close button (✕) on the top-right corner. Default: true.
  final bool showCloseButton;

  /// Show pagination dots. Null = auto (visible when pages.length > 1).
  final bool? showPagination;

  /// When true, renders with a transparent background (no white container).
  /// Use for video-only content. Default: false.
  final bool isVideoOnly;

  /// Whether tapping outside the dialog dismisses it. Default: true.
  /// Only used by [BetelDialog.show].
  final bool barrierDismissible;

  const BetelDialog({
    super.key,
    required this.pages,
    this.showBackButton = false,
    this.showCloseButton = true,
    this.showPagination,
    this.isVideoOnly = false,
    this.barrierDismissible = true,
  });

  /// Convenience method to display a [BetelDialog] as an overlay.
  static Future<void> show(
    BuildContext context, {
    required List<Widget> pages,
    bool showBackButton = false,
    bool showCloseButton = true,
    bool? showPagination,
    bool isVideoOnly = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: BetelDialog(
          pages: pages,
          showBackButton: showBackButton,
          showCloseButton: showCloseButton,
          showPagination: showPagination,
          isVideoOnly: isVideoOnly,
          barrierDismissible: barrierDismissible,
        ),
      ),
    );
  }

  /// Convenience method to show a dialog for a [Content] object.
  /// Automatically picks the right rendering widget based on content type.
  /// VIDEO: embedded YouTube player.
  /// TEXT multi-page: one _TextContentPage per page element, with swipe + dots.
  /// TEXT single-page: single _TextContentPage from html field.
  /// Does nothing if the content has no renderable data.
  static Future<void> showContent(BuildContext context, Content content) {
    if (content.type == 'VIDEO' && content.youtubeUrl != null) {
      return show(
        context,
        pages: [_VideoContentPage(youtubeUrl: content.youtubeUrl!)],
        isVideoOnly: true,
      );
    }

    if (content.type == 'TEXT') {
      // Multi-page: each element becomes a swipeable page
      if (content.pagesHtml != null && content.pagesHtml!.isNotEmpty) {
        return show(
          context,
          pages: content.pagesHtml!
              .map((html) => _TextContentPage(html: html))
              .toList(),
        );
      }
      // Single-page (legacy)
      if (content.html != null) {
        return show(
          context,
          pages: [_TextContentPage(html: content.html!)],
        );
      }
    }

    return Future.value();
  }

  @override
  State<BetelDialog> createState() => _BetelDialogState();
}

class _BetelDialogState extends State<BetelDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  bool get _resolvedShowPagination =>
      widget.showPagination ?? (widget.pages.length > 1);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_currentPage == 0) {
      Navigator.of(context).pop();
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleClose() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Top bar: back + close buttons
        _TopBar(
          showBackButton: widget.showBackButton,
          showCloseButton: widget.showCloseButton,
          isVideoOnly: widget.isVideoOnly,
          onBack: _handleBack,
          onClose: _handleClose,
        ),

        // Page content
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: widget.pages,
          ),
        ),

        // Pagination dots or bottom padding
        if (_resolvedShowPagination)
          _PaginationDots(
            key: const Key('betel-dialog-pagination'),
            pageCount: widget.pages.length,
            currentPage: _currentPage,
          )
        else
          SizedBox(
            key: const Key('betel-dialog-bottom-padding'),
            height: 36,
          ),
      ],
    );

    return Container(
      key: const Key('betel-dialog-container'),
      clipBehavior: widget.isVideoOnly ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.isVideoOnly ? Colors.transparent : Colors.white,
        borderRadius:
            widget.isVideoOnly ? null : BorderRadius.circular(20),
      ),
      child: content,
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool showBackButton;
  final bool showCloseButton;
  final bool isVideoOnly;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _TopBar({
    required this.showBackButton,
    required this.showCloseButton,
    required this.isVideoOnly,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = isVideoOnly
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.06);
    final iconColor = isVideoOnly ? Colors.white : AppTheme.textColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showBackButton)
            _CircleIconButton(
              key: const Key('betel-dialog-back-btn'),
              icon: Icons.arrow_back_ios_new_rounded,
              color: buttonColor,
              iconColor: iconColor,
              onTap: onBack,
            )
          else
            const SizedBox(width: 32),
          if (showCloseButton)
            _CircleIconButton(
              key: const Key('betel-dialog-close-btn'),
              icon: Icons.close,
              color: buttonColor,
              iconColor: iconColor,
              onTap: onClose,
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

class _PaginationDots extends StatelessWidget {
  final int pageCount;
  final int currentPage;

  const _PaginationDots({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          pageCount,
          (i) => _DotIndicator(
            key: Key('betel-dialog-dot-$i'),
            isActive: i == currentPage,
          ),
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final bool isActive;

  const _DotIndicator({
    super.key,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 20.0 : 8.0,
      height: 8.0,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor
            : Colors.grey.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Renders a YouTube video player inside BetelDialog using the iframe API.
/// Uses youtube_player_iframe directly so native YouTube controls (including
/// the YouTube logo button) remain fully interactive — no custom overlay.
class _VideoContentPage extends StatefulWidget {
  final String youtubeUrl;
  const _VideoContentPage({required this.youtubeUrl});

  @override
  State<_VideoContentPage> createState() => _VideoContentPageState();
}

class _VideoContentPageState extends State<_VideoContentPage> {
  late final YoutubePlayerController _controller;
  late final bool _isVertical;

  @override
  void initState() {
    super.initState();
    final parsed = _parseVideoUrl(widget.youtubeUrl);
    _isVertical = parsed.isVertical;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: parsed.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  /// Parses a YouTube URL into a video ID and orientation hint.
  /// URLs containing /shorts/ are treated as vertical (9:16).
  static ({String videoId, bool isVertical}) _parseVideoUrl(String url) {
    bool isVertical = false;
    try {
      final uri = Uri.parse(url);
      if (uri.host == 'youtu.be') {
        return (videoId: uri.pathSegments.first, isVertical: false);
      }
      final watchParam = uri.queryParameters['v'];
      if (watchParam != null) return (videoId: watchParam, isVertical: false);
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        if (segments[0] == 'shorts') {
          return (videoId: segments[1], isVertical: true);
        }
        if (segments[0] == 'embed') {
          return (videoId: segments[1], isVertical: false);
        }
      }
    } catch (_) {}
    return (videoId: url, isVertical: isVertical);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // EagerGestureRecognizer forces the WebView to win the gesture arena
        // against the parent PageView — without this, horizontal drags on the
        // YouTube progress bar are stolen by the PageView's swipe gesture.
        YoutubePlayer(
          controller: _controller,
          aspectRatio: _isVertical ? 9 / 16 : 16 / 9,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        const SizedBox(height: 12),
        // The iframe WebView can't launch external apps — this button
        // opens the video in the native YouTube app via url_launcher.
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse(widget.youtubeUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                'Abrir no YouTube',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders HTML content (from Tiptap editor) as native Flutter widgets.
/// Uses flutter_widget_from_html_core for lightweight rendering.
/// Wrapped in SingleChildScrollView for content that exceeds dialog height.
class _TextContentPage extends StatelessWidget {
  final String html;
  const _TextContentPage({required this.html});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: HtmlWidget(
        html,
        textStyle: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: AppTheme.textColor,
        ),
      ),
    );
  }
}
