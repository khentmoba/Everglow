import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
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
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    final chatService = context.read<ChatService>();
    _messagesStream = chatService.getMessagesStream();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Sanctuary Chat',
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.roseQuartz,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            Text(
              'v2.0.0-STABLE',
              style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withOpacity(0.5), fontSize: 10),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.roseQuartz),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering, color: AppTheme.roseQuartz),
            onPressed: () => _showDiagnostics(context),
            tooltip: 'Check Connection',
          ),
        ],
      ),
      body: GamifiedBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const PulsingHeartLoader(),
                          const SizedBox(height: 20),
                          Text(
                            'Opening our sanctuary...',
                            style: GoogleFonts.outfit(color: AppTheme.roseQuartz, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => _resetFirestore(context),
                            child: Text(
                              'Taking too long? Tap to reset',
                              style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withOpacity(0.6), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (snapshot.hasData) {
                    _isInitialLoad = false;
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: GoogleFonts.outfit(color: Colors.redAccent),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: FadeIn(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_rounded, size: 80, color: AppTheme.roseQuartz.withOpacity(0.2)),
                            const SizedBox(height: 20),
                            Text(
                              'Our sanctuary is empty...',
                              style: GoogleFonts.cormorantGaramond(
                                color: AppTheme.roseQuartz,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send the first message to start blooming',
                              style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withOpacity(0.6), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final messages = snapshot.data!;
                  
                  // Auto-scroll logic
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.sender == currentUser;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ChatBubble(
                          text: message.text,
                          isMe: isMe,
                          sender: message.sender,
                          timestamp: message.timestamp,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.velvet.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: AppTheme.moonlight.withOpacity(0.12),
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
                  color: AppTheme.moonlight.withOpacity(AppTheme.glassOpacity),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.moonlight.withOpacity(0.18),
                    width: 1.0,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.deepRose,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: AppTheme.petalWhite, size: 24),
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
        backgroundColor: AppTheme.velvet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.roseQuartz),
            const SizedBox(height: 16),
            Text(
              'Testing connection to our sanctuary...',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            ),
          ],
        ),
      ),
    );

    String result;
    try {
      // Try to send a hidden diagnostic message
      await chatService.sendMessage(
        "DIAGNOSTIC_CHECK", 
        "System", 
        authService.uid ?? 'no-id'
      );
      result = "✅ Connection Successful!\n\nYour device can reach the server. If you still can't see messages, please check if your partner has a stable connection too.";
    } catch (e) {
      result = "❌ Connection Failed!\n\nError: $e\n\nThis is usually due to Firestore Security Rules. Please make sure your database allows access for authenticated users.";
    }

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.velvet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Sanctuary Status',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.roseQuartz,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: Text(
            result,
            style: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _resetFirestore(context);
              },
              child: Text(
                'Reset & Clear Cache',
                style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.outfit(color: AppTheme.roseQuartz),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resetFirestore(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.velvet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.roseQuartz),
            const SizedBox(height: 16),
            Text(
              'Clearing local cache and restarting...',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            ),
          ],
        ),
      ),
    );

    try {
      final db = FirebaseFirestore.instance;
      await db.terminate();
      await db.clearPersistence();
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleared! Refresh the page now.', style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.deepRose,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e', style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
