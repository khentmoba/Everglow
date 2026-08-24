import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/rag_service.dart';

class RagScreen extends StatefulWidget {
  const RagScreen({super.key});

  @override
  State<RagScreen> createState() => _RagScreenState();
}

class _RagScreenState extends State<RagScreen> {
  final _queryCtrl = TextEditingController();
  final _rag = RagService();
  final _ai = AIService();
  List<RagResult> _results = [];
  String _answer = '';
  bool _searching = false;
  bool _asking = false;

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final res = await _rag.search(q, limit: 8);
    setState(() {
      _results = res;
      _searching = false;
    });
  }

  Future<void> _askMochi() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _asking = true);
    final ctx = await _rag.buildRagContext(q);
    try {
      final ans = await _ai.quickAsk(
        message: q,
        context: ctx,
        systemPrompt:
            'You are Mochi, helpful second brain. Use the retrieved context to answer concisely. Cite sources if useful.',
      );
      setState(() => _answer = ans);
    } catch (e) {
      setState(() => _answer = 'Error: $e');
    } finally {
      setState(() => _asking = false);
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.6, -0.8),
                  size: 0.85,
                  opacity: 0.12,
                ),
              ],
              showPetals: true,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Ask Everglow',
                  subtitle: 'Khoj second brain • RAG',
                  icon: Icons.search_rounded,
                  hue: AppColors.auroraLilac,
                  onBack: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryCtrl,
                          onSubmitted: (_) => _search(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppTheme.petalWhite,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Ask: What was our favorite ramen? Where did we go last Feb?',
                            hintStyle: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: AppColors.twilight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _searching ? null : _search,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.deepRose,
                            shape: BoxShape.circle,
                          ),
                          child: _searching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _search,
                          icon: const Icon(
                            Icons.manage_search_rounded,
                            size: 16,
                            color: AppColors.auroraTeal,
                          ),
                          label: Text(
                            'Search',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppColors.auroraTeal,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.auroraTeal.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _asking ? null : _askMochi,
                          icon: _asking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            'Ask Mochi',
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_answer.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.moonlight.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: AppColors.blushGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Mochi says',
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 11,
                                color: AppColors.blushGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _answer,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 13,
                            height: 1.5,
                            color: AppTheme.petalWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_answer.isNotEmpty) const SizedBox(height: 12),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 36,
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _searching
                                      ? 'Searching...'
                                      : 'No results — try different keywords',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 12,
                                    color: AppTheme.petalWhite.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _results.length,
                          itemBuilder: (context, idx) {
                            final r = _results[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.moonlight.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.auroraTeal
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          r.source,
                                          style: AppTypography.outfitWhite
                                              .copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.auroraTeal,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          r.title,
                                          style: AppTypography.outfitBold
                                              .copyWith(
                                                fontSize: 12,
                                                color: AppTheme.petalWhite,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (r.date != null)
                                        Text(
                                          '${r.date!.month}/${r.date!.day}',
                                          style: AppTypography.outfitWhite
                                              .copyWith(
                                                fontSize: 10,
                                                color: AppTheme.petalWhite
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.snippet,
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 11,
                                      color: AppTheme.petalWhite.withValues(
                                        alpha: 0.7,
                                      ),
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
