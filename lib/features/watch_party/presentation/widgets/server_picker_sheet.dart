import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/watch_party_server.dart';
import '../../data/services/watch_party_server_service.dart';

const _cRose = Color(0xFFF4C2C2);
const _cCard = Color(0xFF1C1228);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cGreen = Color(0xFF4ADE80);
const _cTeal = Color(0xFF7EE8D2);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

/// Bottom sheet that lets the host (or partner) choose which playback
/// server the room uses, plus connect a new self-hosted server.
///
/// The layout mirrors AniChan's player "Sources" bar: servers have a
/// label, a host identity, and a type badge (HLS vs embed). Selecting
/// one updates the shared Firestore room, so the other client follows.
class ServerPickerSheet extends StatefulWidget {
  final List<WatchPartyServer> servers;

  /// Currently active server, or null when using the default embed
  /// provider list.
  final WatchPartyServer? selected;

  /// Called with the picked server, or null to go back to default
  /// providers.
  final ValueChanged<WatchPartyServer?> onSelect;

  const ServerPickerSheet({
    super.key,
    required this.servers,
    this.selected,
    required this.onSelect,
  });

  @override
  State<ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends State<ServerPickerSheet> {
  final WatchPartyServerService _service = WatchPartyServerService();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _host = TextEditingController();
  final TextEditingController _streamUrl = TextEditingController();
  final TextEditingController _subtitleUrl = TextEditingController();
  String _type = 'hls';
  bool _proxy = true;
  bool _showForm = false;
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _streamUrl.dispose();
    _subtitleUrl.dispose();
    super.dispose();
  }

  void _pick(WatchPartyServer? server) {
    HapticFeedback.selectionClick();
    widget.onSelect(server);
    Navigator.of(context).pop();
  }

  Future<void> _addServer() async {
    final name = _name.text.trim();
    final host = _host.text.trim();
    final url = _streamUrl.text.trim();
    if (name.isEmpty || host.isEmpty || url.isEmpty) {
      setState(() => _formError = 'Name, host and stream URL are required.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() => _formError = 'Enter a valid http(s) stream URL.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final server = await _service.addCustomServer(
        name: name,
        shortName: name,
        host: host,
        type: _type,
        streamUrl: url,
        subtitleUrl: _subtitleUrl.text.trim().isEmpty
            ? null
            : _subtitleUrl.text.trim(),
        proxyEnabled: _proxy,
      );
      _pick(server);
    } catch (e) {
      setState(() => _formError = 'Could not save server.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.dns_rounded, color: _cGold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Playback server',
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 22,
                    color: _cWhite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Both of you follow the server picked here. HLS servers sync real play/pause/seek; embeds sync best-effort.',
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 18),
            _buildServerRow(
              id: 'default',
              label: 'Auto',
              subtitle: 'Default embed providers',
              host: 'everglow',
              badge: 'EMBED',
              badgeColor: _cAmber,
              selected: widget.selected == null,
              onTap: () => _pick(null),
            ),
            const SizedBox(height: 8),
            for (final server in widget.servers) ...[
              _buildServerRow(
                id: server.id,
                label: server.isRecommended ? '★ ${server.name}' : server.name,
                subtitle: '${server.host} · ${server.streamUrl}',
                host: server.host,
                badge: server.isHls ? 'HLS' : 'EMBED',
                badgeColor: server.isHls ? _cGreen : _cAmber,
                proxy: server.proxyEnabled,
                custom: server.isCustom,
                selected: widget.selected?.id == server.id,
                onTap: () => _pick(server),
                onDelete: server.isCustom
                    ? () async {
                        await _service.removeCustomServer(server.id);
                        if (mounted) setState(() {});
                      }
                    : null,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.go('/party-downloads');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _cTeal.withValues(alpha: 0.55)),
                  borderRadius: BorderRadius.circular(14),
                  color: _cTeal.withValues(alpha: 0.12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: _cTeal, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Find a movie to host',
                      style: AppTypography.outfitHeading.copyWith(
                        color: _cWhite,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _showForm = !_showForm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _cDeepRose.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(14),
                  color: _cDeepRose.withValues(alpha: 0.12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showForm
                          ? Icons.expand_less_rounded
                          : Icons.add_link_rounded,
                      color: _cRose,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showForm
                          ? 'Close server form'
                          : 'Connect self-hosted server',
                      style: AppTypography.outfitHeading.copyWith(
                        color: _cWhite,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showForm) ...[const SizedBox(height: 14), _buildForm()],
          ],
        ),
      ),
    );
  }

  Widget _buildServerRow({
    required String id,
    required String label,
    required String subtitle,
    required String host,
    required String badge,
    required Color badgeColor,
    required bool selected,
    required VoidCallback onTap,
    bool proxy = false,
    bool custom = false,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _cDeepRose.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _cDeepRose : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.storage_rounded,
              color: selected ? _cDeepRose : _cMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitBold.copyWith(
                            color: _cWhite,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (proxy) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _cGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _cGreen.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'PROXY',
                            style: AppTypography.outfitHeading.copyWith(
                              color: _cGreen,
                              fontSize: 8,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      color: _cMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                badge,
                style: AppTypography.outfitHeading.copyWith(
                  color: badgeColor,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (custom && onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: _cMuted,
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final inputStyle = AppTypography.outfitWhite.copyWith(
      color: _cWhite,
      fontSize: 13,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Name'),
        _input(_name, hint: 'Jellyfin at home', style: inputStyle),
        const SizedBox(height: 10),
        _label('Host'),
        _input(_host, hint: 'jellyfin', style: inputStyle),
        const SizedBox(height: 10),
        _label('Type'),
        Row(
          children: [
            _typeChip('hls', 'HLS stream', Icons.play_arrow_rounded, _cGreen),
            const SizedBox(width: 8),
            _typeChip('embed', 'Embed page', Icons.web_rounded, _cAmber),
          ],
        ),
        const SizedBox(height: 10),
        _label('Stream URL'),
        _input(
          _streamUrl,
          hint: 'https://media.example.com/stream/master.m3u8',
          style: inputStyle,
        ),
        const SizedBox(height: 10),
        _label('Subtitle URL (optional)'),
        _input(
          _subtitleUrl,
          hint: 'https://media.example.com/subtitles/en.vtt',
          style: inputStyle,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _proxy = !_proxy),
          child: Row(
            children: [
              Icon(
                _proxy
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: _proxy ? _cGreen : _cMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Route through Everglow proxy (needed for servers without CORS headers)',
                  style: AppTypography.outfitWhite.copyWith(
                    color: _cWhite.withValues(alpha: 0.75),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 10),
          Text(
            _formError!,
            style: AppTypography.outfitWhite.copyWith(
              color: _cDeepRose,
              fontSize: 11.5,
            ),
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _saving ? null : _addServer,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_cDeepRose, Color(0xFF8E1444)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Connect & use this server',
                      style: AppTypography.outfitHeading.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.outfitHeading.copyWith(
          color: _cMuted,
          fontSize: 10.5,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller, {
    required String hint,
    required TextStyle style,
  }) {
    return TextField(
      controller: controller,
      style: style,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: _cMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cDeepRose),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label, IconData icon, Color color) {
    final active = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? color : _cMuted, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.outfitHeading.copyWith(
                  color: active ? color : _cMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
