import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_theme.dart';

/// Full-screen gate that detects adblockers before showing [child].
///
/// Uses the bait-element technique (creates a hidden div with
/// ad-related class names; adblockers hide/kill it). If an adblocker
/// is found the check passes instantly; otherwise a prompt asks the
/// user to install uBlock Origin before proceeding.
class AdblockerGate extends StatefulWidget {
  final Widget child;
  const AdblockerGate({super.key, required this.child});

  @override
  State<AdblockerGate> createState() => _AdblockerGateState();
}

class _AdblockerGateState extends State<AdblockerGate> {
  bool _checking = true;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    final ok = await _detectAdblocker();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _detected = ok;
    });
  }

  void _openUrl(String url) {
    web.window.open(url, '_blank');
  }

  Future<bool> _detectAdblocker() async {
    try {
      final bait = web.HTMLDivElement();
      bait.className =
          'pub_300x250 pub_300x250m pub_728x90 text-ad textAd text_ad text_ads text-ads text-ad-links';
      bait.style
        ..position = 'absolute'
        ..left = '-9999px'
        ..width = '1px'
        ..height = '1px';
      web.document.body!.appendChild(bait);
      await Future.delayed(const Duration(milliseconds: 150));
      final blocked = bait.offsetHeight == 0 || bait.offsetParent == null;
      bait.remove();
      return blocked;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checking && _detected) return widget.child;

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _checking ? _buildChecking() : _buildPrompt(),
          ),
        ),
      ),
    );
  }

  Widget _buildChecking() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppTheme.deepRose,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Checking your browser…',
          style: GoogleFonts.outfit(
            color: AppTheme.roseQuartz,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildPrompt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.deepRose.withValues(alpha: 0.2),
                AppTheme.softLavender.withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: AppTheme.deepRose.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppTheme.roseQuartz,
            size: 38,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Adblocker Recommended',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.roseQuartz,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Streaming sources may show intrusive ads. '
          'Installing an adblocker gives you a cleaner, faster experience.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildUblockCard(),
        const SizedBox(height: 16),
        _buildMobileCard(),
        const SizedBox(height: 32),
        _buildActionButtons(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUblockCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1228),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.softLavender.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B33),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: AppTheme.blushGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'uBlock Origin',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Free, open-source, low memory',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Works on Chrome, Firefox, Edge, Brave, and Opera. '
            'Blocks ads, trackers, and malicious domains — no configuration needed.',
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _openUrl('https://ublockorigin.com'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.blushGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new_rounded, color: AppTheme.blushGold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Install uBlock Origin',
                      style: GoogleFonts.outfit(
                        color: AppTheme.blushGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1228),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.softLavender.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B33),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.blushGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile Options',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to install',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _mobileOption(
            icon: Icons.public,
            label: 'Firefox for Android',
            detail: 'uBlock Origin',
            url: 'https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/',
          ),
          const SizedBox(height: 10),
          _mobileOption(
            icon: Icons.travel_explore,
            label: 'Samsung Internet',
            detail: 'Adblock Plus',
            url: 'https://adblockplus.org',
          ),
          const SizedBox(height: 10),
          _mobileOption(
            icon: Icons.public,
            label: 'Safari on iOS',
            detail: 'Adblock Plus',
            url: 'https://adblockplus.org',
          ),
          const SizedBox(height: 10),
          _mobileOption(
            icon: Icons.public,
            label: 'Kiwi Browser (Android)',
            detail: 'uBlock Origin',
            url: 'https://chrome.google.com/webstore/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm',
          ),
          const SizedBox(height: 10),
          _mobileOption(
            icon: Icons.shield_rounded,
            label: 'AdGuard',
            detail: 'System-wide, any Android browser',
            url: 'https://adguard.com',
          ),
        ],
      ),
    );
  }

  Widget _mobileOption({
    required IconData icon,
    required String label,
    required String detail,
    required String url,
  }) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B33),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.roseQuartz, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detail,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: AppTheme.roseQuartz,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _checking = true;
                _detected = false;
              });
              _runCheck();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.deepRose, Color(0xFF8E1444)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'I Have One Installed',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _detected = true),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
          child: Text(
            'Continue without adblocker',
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.5),
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
