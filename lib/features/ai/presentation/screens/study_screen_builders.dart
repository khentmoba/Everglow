part of 'study_screen.dart';

/// Main-column + chat + composer builders for [_StudyScreenState].
extension _StudyScreenBuilders on _StudyScreenState {
  Widget _buildMainColumn(bool canSend) {
    return Column(
      children: [
        EverglowFeatureHeader(
          title: 'Study',
          subtitle: 'your PDFs, Motchi on top',
          icon: Icons.school_rounded,
          hue: AppColors.softLavender,
          onBack: () => context.pop(),
          actions: [
            _HeaderIconButton(
              icon: Icons.history_rounded,
              tooltip: 'Study history',
              onTap: () => _refresh(() => _historyOpen = !_historyOpen),
            ),
            _HeaderIconButton(
              icon: Icons.add_rounded,
              tooltip: 'New study',
              onTap: _newStudy,
            ),
          ],
        ),
        if (_restoring)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(AppColors.blushGold),
          ),
        _buildSources(),
        Divider(height: 1, color: AppColors.blushGold.withValues(alpha: 0.06)),
        Expanded(child: _buildChat()),
        if (_sources.isNotEmpty && !_sending) _buildStudyChips(),
        _buildComposer(canSend),
      ],
    );
  }

  Widget _buildSources() {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        itemCount: _sources.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == _sources.length) return _buildAddCard();
          return _buildSourceCard(i);
        },
      ),
    );
  }

  Widget _buildAddCard() {
    final full = _sources.length >= kMaxStudyDocs;
    final enabled = !full && !_picking;
    return SizedBox(
      width: 132,
      child: GestureDetector(
        onTap: enabled ? _addSource : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.inkDeep.withValues(alpha: enabled ? 0.92 : 0.70),
                AppColors.velvet.withValues(alpha: enabled ? 0.75 : 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.softLavender.withValues(
                alpha: enabled ? 0.38 : 0.15,
              ),
              width: 1.1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.softLavender.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_picking)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.softLavender,
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.softLavender.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: enabled
                        ? AppColors.softLavender
                        : AppColors.textDisabled,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                full ? 'Shelf full (3)' : 'Add PDF',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.petalWhite : AppColors.textMuted,
                ),
              ),
              Text(
                'Motchi reads it',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceCard(int index) {
    final doc = _sources[index];
    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.inkDeep.withValues(alpha: 0.92),
              AppColors.velvet.withValues(alpha: 0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.softLavender.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.blushGold, AppColors.deepRose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 14,
                    color: AppColors.petalWhite,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Text(
                    'PDF',
                    style: AppTypography.labelSmall().copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _removeSource(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                doc.fileName,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.petalWhite,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(doc.text.length / 1000).toStringAsFixed(1)}k chars'
              '${doc.truncated ? ' · start only' : ''}',
              style: AppTypography.bodySmall().copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    if (_turns.isEmpty && !_sending) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.softLavender.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softLavender.withValues(alpha: 0.25),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.12),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/motchi_avatar.png',
                    width: 76,
                    height: 76,
                    cacheWidth: kIsWeb ? null : 228,
                    cacheHeight: kIsWeb ? null : 228,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softLavender.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(
                    color: AppColors.softLavender.withValues(alpha: 0.28),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _sources.isEmpty ? '📚 SHELF AWAITS' : '✨ SOURCES READY',
                  style: AppTypography.labelSmall().copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.softLavender,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _sources.isEmpty
                    ? 'Add a class PDF above'
                    : 'Sources ready — ask away',
                style: AppTypography.titleLarge().copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _sources.isEmpty
                    ? 'Motchi will read it with you, then answer\nonly from your pages.'
                    : 'Ask anything, or tap Summarize, Quiz,\nFlashcards below to start.',
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _turns.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _turns.length) return const _StreamingBubble();
                final turn = _turns[i];
                if (turn.fromUser) return _UserBubble(text: turn.text);
                var keepFull = false;
                for (var k = i - 1; k >= 0; k--) {
                  if (_turns[k].fromUser) {
                    keepFull = userAskedForVisibleQuiz(_turns[k].text);
                    break;
                  }
                }
                return _AnswerBubble(
                  text: turn.text,
                  // Always show: hiding past quizzes/cards when the toggle
                  // is off strands them with no way to reopen.
                  showArtifacts: true,
                  keepFullText: keepFull,
                );
              },
            ),
          ),
        ),
        if (_showJumpButton)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _scrollToBottom(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panelGlass,
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudyChips() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              for (final chip in StudyPrompts.chipsFor(
                canvasOn: _canvasEnabled,
              ))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Opacity(
                    opacity: _sending ? 0.5 : 1,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _sending ? null : () => _ask(chip.$2),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.inkDeep.withValues(alpha: 0.88),
                                AppColors.velvet.withValues(alpha: 0.68),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.softLavender.withValues(
                                alpha: 0.26,
                              ),
                              width: 0.9,
                            ),
                          ),
                          child: Text(
                            chip.$1,
                            style: AppTypography.bodySmall().copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMedium,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(bool canSend) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        10,
        AppSpacing.lg,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.06)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.inkDeep.withValues(alpha: 0.92),
                  AppColors.velvet.withValues(alpha: 0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.16),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  if (!HardwareKeyboard.instance.isShiftPressed) {
                    _ask(_input.text);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: _canvasEnabled
                          ? 'Canvas: on — quizzes open as interactive cards'
                          : 'Canvas: off — plain text only',
                      child: InkWell(
                        onTap: () =>
                            _refresh(() => _canvasEnabled = !_canvasEnabled),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _canvasEnabled
                                ? AppColors.blushGold.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _canvasEnabled
                                  ? AppColors.blushGold.withValues(alpha: 0.40)
                                  : Colors.transparent,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _canvasEnabled
                                    ? Icons.dashboard_customize_rounded
                                    : Icons.dashboard_customize_outlined,
                                color: _canvasEnabled
                                    ? AppColors.blushGold
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                              if (_canvasEnabled) ...[
                                const SizedBox(width: 4),
                                Text(
                                  'Canvas',
                                  style: AppTypography.labelSmall().copyWith(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focusNode,
                      style: AppTypography.bodyMedium().copyWith(
                        height: 1.5,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textHigh,
                      ),
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: _sources.isEmpty
                            ? 'Add a PDF first…'
                            : 'Ask about your sources…',
                        hintStyle: AppTypography.bodyMedium().copyWith(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: GestureDetector(
                      onTap: canSend ? () => _ask(_input.text) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: canSend
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.deepRose,
                                    AppColors.auroraRose,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: canSend
                              ? null
                              : AppColors.velvet.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: canSend
                              ? Border.all(
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.22,
                                  ),
                                  width: 1,
                                )
                              : null,
                          boxShadow: canSend
                              ? [
                                  BoxShadow(
                                    color: AppColors.deepRose.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.blushGold,
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward_rounded,
                                  color: canSend
                                      ? AppColors.petalWhite
                                      : AppColors.textDisabled,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
