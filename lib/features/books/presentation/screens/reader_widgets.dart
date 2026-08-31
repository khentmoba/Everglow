part of 'reader_screen_web.dart';

class ReaderTheme {
  final String label;
  final Color bg;
  final Color fg;

  const ReaderTheme._(this.label, this.bg, this.fg);

  static const dark = ReaderTheme._(
    'Night',
    AppColors.twilight,
    AppColors.moonlight,
  );
  static const sepia = ReaderTheme._(
    'Sepia',
    AppColors.shimmerBase,
    AppColors.blushGold,
  );
  static const light = ReaderTheme._(
    'Light',
    AppColors.petalWhite,
    AppColors.twilight,
  );

  static const values = [dark, sepia, light];
}

class _ListenSheet extends StatefulWidget {
  final String chapterTitle;
  final List<String> paragraphs;
  final WebTtsService tts;

  const _ListenSheet({
    required this.chapterTitle,
    required this.paragraphs,
    required this.tts,
  });

  @override
  State<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends State<_ListenSheet> {
  static const _speeds = [0.85, 0.90, 0.95, 1.0, 1.05, 1.10, 1.15];

  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _paraKeys = [];
  int _index = 0;
  bool _playing = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _paraKeys.addAll(
      List.generate(widget.paragraphs.length, (_) => GlobalKey()),
    );
  }

  @override
  void dispose() {
    widget.tts.stop();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_playing) {
      widget.tts.pause();
      setState(() => _playing = false);
      return;
    }
    if (widget.tts.isPaused) {
      widget.tts.resume();
      setState(() => _playing = true);
      return;
    }
    _speakFrom(_index);
  }

  void _speakFrom(int index) {
    if (index >= widget.paragraphs.length) {
      setState(() {
        _playing = false;
        _index = 0;
      });
      return;
    }
    setState(() {
      _index = index;
      _playing = true;
    });
    _scrollTo(index);
    widget.tts.speak(
      widget.paragraphs[index],
      rate: _speed,
      onComplete: () {
        if (!mounted) return;
        final next = _index + 1;
        if (next >= widget.paragraphs.length) {
          setState(() {
            _playing = false;
            _index = 0;
          });
        } else {
          _speakFrom(next);
        }
      },
    );
  }

  void _scrollTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _paraKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          alignment: 0.4,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _stop() {
    widget.tts.stop();
    setState(() {
      _playing = false;
      _index = 0;
    });
    _scrollTo(0);
  }

  void _setSpeed(double speed) {
    widget.tts.setRate(speed);
    setState(() => _speed = speed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: const BoxDecoration(
        color: AppTheme.velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  'Listen',
                  style: AppTypography.cormorantExtraBoldWhite.copyWith(
                    fontSize: 22,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Player controls
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.deepRose, AppColors.rosePressed],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepRose.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _stop,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: AppTheme.roseQuartz.withValues(alpha: 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.stop_rounded,
                      color: AppTheme.roseQuartz,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.roseQuartz.withValues(alpha: 0.15),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: _speed,
                      dropdownColor: AppTheme.velvet,
                      style: AppTypography.outfitBold.copyWith(
                        color: AppTheme.roseQuartz,
                        fontSize: 12,
                      ),
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        color: AppTheme.roseQuartz,
                        size: 16,
                      ),
                      items: [
                        for (final s in _speeds)
                          DropdownMenuItem(
                            value: s,
                            child: Text('${s.toStringAsFixed(2)}x'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) _setSpeed(v);
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_index + 1} / ${widget.paragraphs.length}',
                  style: AppTypography.outfitBold.copyWith(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.paragraphs.length; i++)
                    KeyedSubtree(
                      key: _paraKeys[i],
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: i == _index
                              ? AppTheme.deepRose.withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i == _index
                                ? AppTheme.deepRose.withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          widget.paragraphs[i],
                          style: AppTypography.outfitWhite.copyWith(
                            color: i == _index
                                ? AppTheme.petalWhite
                                : AppTheme.roseQuartz.withValues(alpha: 0.75),
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
