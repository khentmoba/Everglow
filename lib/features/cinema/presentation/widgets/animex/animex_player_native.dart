import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/services/anilist_service.dart';
import '../embed_webview.dart';
import 'animex_buttons.dart';
import 'animex_tokens.dart';

/// Opens the reference-style trailer for an anime inside the app.
///
/// The web implementation shows a modal with a YouTube iframe; Android runs
/// the same embed in a WebView instead of handing the user off to YouTube.
Future<void> showAnimexTrailer(
  BuildContext context, {
  String? youtubeId,
  int? anilistId,
  int? malId,
  required String title,
}) async {
  var trailerId = youtubeId;
  if ((trailerId == null || trailerId.isEmpty) &&
      (anilistId != null || malId != null)) {
    final detail = await AniListService().fetchDetailsWithFallback(
      anilistId: anilistId,
      malId: malId,
    );
    trailerId = detail?.trailerYoutubeId;
  }
  if (trailerId == null || trailerId.isEmpty) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierColor: const Color(0xE0000000),
    builder: (_) => AnimeXTrailerModal(
      title: title,
      youtubeId: trailerId!,
    ),
  );
}

/// Trailer overlay dialog with a 16:9 YouTube player and close button.
class AnimeXTrailerModal extends StatelessWidget {
  final String title;
  final String youtubeId;

  const AnimeXTrailerModal({
    super.key,
    required this.title,
    required this.youtubeId,
  });

  @override
  Widget build(BuildContext context) {
    final url =
        'https://www.youtube.com/embed/$youtubeId?autoplay=1&rel=0&color=white';
    return Dialog(
      backgroundColor: AnimeXTokens.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl),
        side: const BorderSide(color: AnimeXTokens.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title — Official Trailer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimeXIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: EmbedWebView(
                url: url,
                aspectRatio: 16 / 9,
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Native embed surface for the AnimeX player.
///
/// Android runs the provider embed inside an in-app WebView. A main-frame
/// load failure reports [onContentError] so callers can auto-advance to the
/// next server just like the web player.
class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;
  final VoidCallback? onContentError;
  final ScrollController? scrollController;

  const AnimeXPlayerFrame({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.onContentError,
    this.scrollController,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  @override
  Widget build(BuildContext context) {
    return EmbedWebView(
      key: ValueKey(widget.url),
      url: widget.url,
      aspectRatio: widget.aspectRatio,
      borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
      onError: widget.onContentError,
    );
  }
}
