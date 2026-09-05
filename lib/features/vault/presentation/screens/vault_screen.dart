import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/pick_image_bytes.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_fade_row.dart';
import '../../../../shared/widgets/everglow/everglow_chip.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/vault_entry.dart';
import '../../data/services/vault_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String _folderFilter = 'all';
  final _folders = [
    'all',
    'general',
    'photos',
    'documents',
    'tickets',
    'memories',
  ];

  Future<void> _upload() async {
    final picked = await pickImageBytes();
    if (picked == null || !mounted) return;
    final auth = context.read<AuthService>();
    final bytes = picked.bytes;
    final fileName =
        picked.fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final mime = _guessMime(fileName);
    final service = VaultService();
    final entry = await service.uploadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mime,
      uploadedBy: auth.currentUser ?? 'unknown',
      userId: auth.uid ?? '',
      folder: _folderFilter == 'all' ? 'general' : _folderFilter,
    );
    if (entry == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed'),
          backgroundColor: AppColors.deepRose,
        ),
      );
    }
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    final service = VaultService();
    final stream = _folderFilter == 'all'
        ? service.watchAll()
        : service.watchByFolder(_folderFilter);
    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: [
        const RadialGlow(
          color: AppColors.auroraTeal,
          alignment: Alignment(-0.7, -0.8),
          size: 0.9,
          opacity: 0.12,
        ),
      ],
      body: Column(
        children: [
          EverglowFeatureHeader(
            title: 'Vault',
            subtitle: 'our private drive • FileBrowser',
            icon: Icons.folder_special_rounded,
            hue: AppColors.auroraTeal,
            actions: [
              EverglowIconButton(
                icon: Icons.upload_rounded,
                onPressed: _upload,
                semanticLabel: '''Upload file''',
                tooltip: '''Upload''',
                iconColor: AppColors.blushGold,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pageH(context),
            ),
            child: EverglowFadeRow(
              child: Row(
                children: _folders
                    .map(
                      (f) => EverglowChip(
                        label: f,
                        selected: _folderFilter == f,
                        onTap: () => setState(() => _folderFilter = f),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<Map<String, int>>(
            future: service.getStorageStats(),
            builder: (context, snap) {
              final count = snap.data?['count'] ?? 0;
              final bytes = snap.data?['bytes'] ?? 0;
              final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panelGlass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storage_rounded,
                        size: 14,
                        color: AppColors.auroraTeal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count files • $mb MB',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppTheme.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Firebase Storage',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          color: AppColors.auroraTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: EverglowStreamView<List<VaultEntry>>(
              stream: stream,
              streamLabel: 'vault-entries',
              errorMessage: 'Could not load vault',
              errorIcon: Icons.folder_open_rounded,
              onRetry: () => setState(() {}),
              isEmpty: (entries) => entries.isEmpty,
              emptyView: EverglowEmptyState(
                icon: Icons.folder_open_rounded,
                title: 'Vault is empty',
                subtitle: _folderFilter == 'all'
                    ? 'Upload your first file — receipts, tickets, IDs, photos'
                    : 'No files in "$_folderFilter"',
                ctaLabel: 'Upload',
                onCta: _upload,
              ),
              builder: (context, entries) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: entries.length,
                itemBuilder: (context, idx) => _VaultCard(
                  entry: entries[idx],
                  onDelete: () => VaultService().deleteEntry(entries[idx]),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _upload,
        backgroundColor: AppColors.auroraTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.upload_rounded),
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onDelete;
  const _VaultCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: entry.isImage
                  ? AppNetworkImage(
                      imageUrl: entry.fileUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      errorWidget: Container(
                        color: AppColors.twilight,
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppColors.petalWhite.withValues(alpha: 0.3),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      color: AppColors.twilight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            entry.isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.description_rounded,
                            size: 36,
                            color: AppColors.blushGold.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.mimeType.split('/').last.toUpperCase(),
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              color: AppTheme.petalWhite.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fileName,
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 12,
                    color: AppTheme.petalWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.sizeLabel} • ${entry.folder}',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    color: AppTheme.petalWhite.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(entry.fileUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.auroraTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Open',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.auroraTeal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: AppTheme.velvet,
                            title: Text(
                              'Delete ${entry.fileName}?',
                              style: AppTypography.outfitBold.copyWith(
                                color: AppTheme.petalWhite,
                              ),
                            ),
                            content: Text(
                              'Also removes from Storage.',
                              style: AppTypography.outfitWhite.copyWith(
                                color: AppTheme.petalWhite.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) onDelete();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
