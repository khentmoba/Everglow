import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/core/theme/app_spacing.dart';
import 'package:everglow/core/theme/app_elevation.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/shared/widgets/partner_presence_indicator.dart';
import '../../../../core/utils/logger.dart';
import '../../data/services/chat_service.dart';
import '../../domain/models/chat_message.dart';
import 'package:animate_do/animate_do.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/pulsing_heart_loader.dart';

class SanctuaryChatScreen extends StatefulWidget {
  const SanctuaryChatScreen({super.key});

  @override
  State<SanctuaryChatScreen> createState() => _SanctuaryChatScreenState();
}

class _SanctuaryChatScreenState extends State<SanctuaryChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;
  bool _showScrollButton = false;
  bool _authChecked = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkAuthAndConnect();
  }

  void _onScroll() {
    final show =
        _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels >
            400;
    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

  void _checkAuthAndConnect() async {
    final authService = context.read<AuthService>();

    if (!authService.isAuthenticated) {
      setState(() {
        _authChecked = true;
        _authError = 'not_authenticated';
      });
      return;
    }

    if (authService.isCinemaOnlyUser) {
      setState(() {
        _authChecked = true;
        _authError = 'cinema_only';
      });
      return;
    }

    if (!authService.isCoupleUser) {
      setState(() {
        _authChecked = true;
        _authError = 'not_couple_user';
      });
      return;
    }

    final uid = authService.uid;
    if (uid == null) {
      setState(() {
        _authChecked = true;
        _authError = 'not_authenticated';
      });
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(uid).set({
        'username': authService.currentUser,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e("Sanctuary: failed to ensure user doc", error: e);
    }

    setState(() {
      _authChecked = true;
      _authError = null;
    });
    _connectStream();
  }

  void _connectStream() {
    final chatService = context.read<ChatService>();
    _messagesStream = chatService.getMessagesStream();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _sendMessage() {
    final authService = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUser = authService.currentUser ?? 'unknown';

    if (_messageController.text.trim().isNotEmpty) {
      chatService.sendMessage(
        _messageController.text,
        currentUser,
        authService.uid ?? 'anonymous',
      );
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser ?? 'unknown';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GamifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.moonlight.withValues(alpha: 0.10),
                        AppColors.inkDeep.withValues(alpha: 0.45),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.roseQuartz,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sanctuary Chat',
                              style: AppTypography.titleLarge(),
                            ),
                            const SizedBox(height: 2),
                            const PartnerPresenceIndicator(),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.wifi_tethering,
                          color: AppColors.roseQuartz,
                        ),
                        onPressed: () => _showDiagnostics(context),
                        tooltip: 'Check Connection',
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (!_authChecked)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const PulsingHeartLoader(),
                            const SizedBox(height: 20),
                            Text(
                              'Verifying access...',
                              style: AppTypography.bodyLarge().copyWith(
                                color: AppColors.roseQuartz,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_authError != null)
                      _buildAuthError()
                    else
                      StreamBuilder<List<ChatMessage>>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              !snapshot.hasData) {
                            return _ErrorState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Sanctuary is taking too long to respond',
                              subtitle: 'Check your connection and try again.',
                              onRetry: () => _resetAndRetry(context),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const PulsingHeartLoader(),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Opening our sanctuary...',
                                    style: AppTypography.bodyLarge().copyWith(
                                      color: AppColors.roseQuartz,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => _resetAndRetry(context),
                                    child: Text(
                                      'Taking too long? Tap to retry',
                                      style: AppTypography.bodySmall().copyWith(
                                        color: AppColors.roseQuartz.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            final error = snapshot.error.toString();
                            String message;
                            String detail;

                            if (error.contains('permission-denied')) {
                              message = 'Access requires a linked account';
                              detail =
                                  'Please log out and log back in to refresh your session.';
                            } else if (error.contains('unavailable') ||
                                error.contains('deadline-exceeded')) {
                              message =
                                  'The sanctuary is temporarily unavailable';
                              detail =
                                  'Please check your connection and try again.';
                            } else {
                              message = 'Something went wrong';
                              detail = error.length > 120
                                  ? '${error.substring(0, 120)}...'
                                  : error;
                            }

                            return _ErrorState(
                              icon: Icons.cloud_off_rounded,
                              title: message,
                              subtitle: detail,
                              onRetry: () => _resetAndRetry(context),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: FadeInUp(
                                duration: const Duration(milliseconds: 250),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.x2),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.glowRose,
                                              blurRadius: 32,
                                              spreadRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.favorite_rounded,
                                          size: 80,
                                          color: AppColors.roseQuartz,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Our sanctuary is empty...',
                                        style: AppTypography.titleLarge()
                                            .copyWith(
                                              color: AppColors.roseQuartz,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Send the first message to start blooming',
                                        style: AppTypography.bodyMedium()
                                            .copyWith(
                                              color: AppColors.roseQuartz
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final messages = snapshot.data!;

                          // Auto-scroll logic
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToBottom(),
                          );

                          return Semantics(
                            liveRegion: true,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                100,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final isMe = message.sender == currentUser;

                                return FadeInUp(
                                  duration: const Duration(milliseconds: 250),
                                  delay: Duration(
                                    milliseconds: (index * 50).clamp(0, 200),
                                  ),
                                  child: Align(
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: ChatBubble(
                                      text: message.text,
                                      isMe: isMe,
                                      sender: message.sender,
                                      timestamp: message.timestamp,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    // Scroll-to-bottom FAB
                    if (_showScrollButton)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: FadeIn(
                          duration: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: () => _scrollToBottom(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppElevation.e2,
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
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: AppColors.moonlight.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: TextField(
                  controller: _messageController,
                  style: AppTypography.bodyMedium(),
                  maxLength: 1000,
                  buildCounter:
                      (
                        _, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) => null,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: AppTypography.bodyMedium().copyWith(
                      color: AppColors.textDisabled,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Send button
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.deepRose,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glowRose,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppColors.petalWhite,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiagnostics(BuildContext context) async {
    final chatService = context.read<ChatService>();
    final authService = context.read<AuthService>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.roseQuartz),
            const SizedBox(height: 16),
            Text(
              'Testing connection to our sanctuary...',
              style: AppTypography.bodyMedium(),
            ),
          ],
        ),
      ),
    );

    String result;
    try {
      await chatService.sendMessage(
        "DIAGNOSTIC_CHECK",
        "System",
        authService.uid ?? 'no-id',
      );
      result =
          "[OK] Connection Successful!\n\nYour device can reach the server. If you still can't see messages, please check if your partner has a stable connection too.";
    } catch (e) {
      result =
          "[FAIL] Connection Failed!\n\nError: $e\n\nThis is usually due to Firestore Security Rules. Please make sure your database allows access for authenticated users.";
    }

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.velvet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Sanctuary Status',
            style: AppTypography.titleLarge().copyWith(
              color: AppColors.roseQuartz,
            ),
          ),
          content: Text(
            result,
            style: AppTypography.bodyMedium().copyWith(
              color: AppColors.textMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: AppTypography.labelLarge().copyWith(
                  color: AppColors.roseQuartz,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAuthError() {
    String title;
    String detail;
    IconData icon;

    switch (_authError) {
      case 'not_authenticated':
        icon = Icons.lock_outline_rounded;
        title = 'You need to sign in';
        detail = 'Please go back and sign in with your passcode.';
        break;
      case 'cinema_only':
        icon = Icons.movie_filter_rounded;
        title = 'Cinema-only access';
        detail =
            'Your account doesn\'t have access to Sanctuary Chat. This feature is for Khent and Clair only.';
        break;
      case 'not_couple_user':
        icon = Icons.heart_broken_rounded;
        title = 'Access restricted';
        detail = 'Sanctuary Chat is only available to linked partners.';
        break;
      default:
        icon = Icons.cloud_off_rounded;
        title = 'Access requires a linked account';
        detail = 'Please log out and log back in to refresh your session.';
    }

    return _ErrorState(
      icon: icon,
      title: title,
      subtitle: detail,
      onRetry: () => _resetAndRetry(context),
    );
  }

  void _resetAndRetry(BuildContext context) async {
    final authService = context.read<AuthService>();

    setState(() {
      _authChecked = false;
      _authError = null;
    });

    try {
      final user = authService.user;
      if (user != null) {
        await user.getIdToken(true);
      }
    } catch (e) {
      Logger.e("Token refresh failed", error: e);
    }

    _checkAuthAndConnect();
  }
}

/// Reusable error state widget
class _ErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: AppColors.roseQuartz.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: AppTypography.bodyLarge().copyWith(
                  color: AppColors.roseQuartz,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.roseQuartz.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Reset & Retry',
                  style: AppTypography.labelLarge().copyWith(
                    color: AppColors.roseQuartz,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
