import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../ai/presentation/widgets/canvas_html_view.dart';
import '../../data/welcome_gift_service.dart';

class WelcomeGiftGate extends StatefulWidget {
  final String? recipientUid;
  final Widget child;
  final WelcomeGiftService? service;

  const WelcomeGiftGate({
    super.key,
    required this.recipientUid,
    required this.child,
    this.service,
  });

  @override
  State<WelcomeGiftGate> createState() => _WelcomeGiftGateState();
}

class _WelcomeGiftGateState extends State<WelcomeGiftGate> {
  late final WelcomeGiftService _service;
  String? _html;
  bool _contentFinished = false;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WelcomeGiftService();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant WelcomeGiftGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipientUid != widget.recipientUid) {
      _html = null;
      _contentFinished = false;
      _saving = false;
      _saveFailed = false;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final uid = widget.recipientUid;
    if (uid == null) return;
    final html = await _service.pendingHtml(uid);
    if (!mounted || widget.recipientUid != uid) return;
    setState(() => _html = html);
  }

  Future<void> _complete() async {
    final uid = widget.recipientUid;
    if (!_contentFinished || _saving || uid == null) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await _service.complete(uid);
      if (!mounted || widget.recipientUid != uid) return;
      setState(() {
        _html = null;
        _saving = false;
      });
    } catch (error, stack) {
      Logger.e(
        'Could not save welcome gift receipt',
        error: error,
        stackTrace: stack,
      );
      if (!mounted || widget.recipientUid != uid) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    if (html == null) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(child: ExcludeSemantics(child: widget.child)),
        Scaffold(
          backgroundColor: AppColors.petalWhite,
          body: SafeArea(
            bottom: !_contentFinished,
            child: CanvasHtmlView(
              html: html,
              onContentFinishedChanged: (finished) {
                if (mounted) setState(() => _contentFinished = finished);
              },
            ),
          ),
          bottomNavigationBar: !_contentFinished
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_saveFailed)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              "Couldn't save right now. Check your connection and try again.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.roseDepths),
                            ),
                          ),
                        EverglowButton(
                          label: _saving ? 'Saving...' : 'Continue to Everglow',
                          enabled: !_saving,
                          onPressed: _complete,
                          backgroundColor: AppColors.roseDepths,
                          foregroundColor: AppColors.petalWhite,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
