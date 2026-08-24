import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/recipe.dart';
import '../../data/services/cookbook_service.dart';

class AddRecipeDialog extends StatefulWidget {
  const AddRecipeDialog({super.key});

  @override
  State<AddRecipeDialog> createState() => _AddRecipeDialogState();
}

class _AddRecipeDialogState extends State<AddRecipeDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _ingredientNameController = TextEditingController();
  final _ingredientAmountController = TextEditingController();
  final _stepController = TextEditingController();
  final _tagController = TextEditingController();
  final _importUrlController = TextEditingController();

  RecipeCategory _category = RecipeCategory.dinner;
  RecipeDifficulty _difficulty = RecipeDifficulty.easy;
  int _cookMinutes = 30;
  int _servings = 2;
  List<RecipeIngredient> _ingredients = [];
  List<String> _steps = [];
  List<String> _tags = [];
  bool _saving = false;
  bool _importing = false;

  void _addIngredient() {
    final name = _ingredientNameController.text.trim();
    final amount = _ingredientAmountController.text.trim();
    if (name.isEmpty || amount.isEmpty) return;
    setState(() {
      _ingredients.add(RecipeIngredient(name: name, amount: amount));
      _ingredientNameController.clear();
      _ingredientAmountController.clear();
    });
  }

  void _addStep() {
    final s = _stepController.text.trim();
    if (s.isEmpty) return;
    setState(() {
      _steps.add(s);
      _stepController.clear();
    });
  }

  void _addTag() {
    final t = _tagController.text.trim().toLowerCase();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() {
      _tags.add(t);
      _tagController.clear();
    });
  }

  Future<void> _importFromUrl() async {
    final url = _importUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _importing = true);
    final auth = context.read<AuthService>();
    final imported = await CookbookService().importFromUrl(
      url,
      auth.currentUser ?? 'unknown',
    );
    if (imported != null) {
      setState(() {
        _titleController.text = imported.title;
        _descController.text = imported.description;
        _ingredients = List.from(imported.ingredients);
        _steps = List.from(imported.steps);
        _tags = List.from(imported.tags);
        _importUrlController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported: ${imported.title}'),
            backgroundColor: AppColors.deepRose,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import failed'),
            backgroundColor: AppColors.deepRose,
          ),
        );
      }
    }
    setState(() => _importing = false);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final recipe = Recipe(
      id: '',
      title: title,
      description: _descController.text.trim(),
      category: _category,
      difficulty: _difficulty,
      cookMinutes: _cookMinutes,
      servings: _servings,
      ingredients: _ingredients,
      steps: _steps,
      tags: _tags,
      createdBy: auth.currentUser ?? 'unknown',
      createdAt: DateTime.now(),
    );
    await CookbookService().add(recipe);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ingredientNameController.dispose();
    _ingredientAmountController.dispose();
    _stepController.dispose();
    _tagController.dispose();
    _importUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.velvet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.2)),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Add Recipe 🍝',
                    style: AppTypography.cormorantBold.copyWith(fontSize: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTheme.petalWhite.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mealie import
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inkDeep.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
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
                          Icons.link_rounded,
                          size: 14,
                          color: AppColors.blushGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Import from URL (Mealie)',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppColors.blushGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _importUrlController,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: 'https://...',
                              hintStyle: AppTypography.outfitWhite.copyWith(
                                color: AppTheme.petalWhite.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.twilight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _importing ? null : _importFromUrl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.deepRose,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _importing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Import',
                                    style: AppTypography.outfitBold.copyWith(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Recipe title',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 2,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.petalWhite,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Description',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),
              // Category
              Text(
                'Category',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RecipeCategory.values.map((c) {
                  final sel = _category == c;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.deepRose.withValues(alpha: 0.25)
                            : AppColors.twilight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.blushGold : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${c.emoji} ${c.displayName}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: sel
                              ? AppColors.blushGold
                              : AppTheme.petalWhite.withValues(alpha: 0.7),
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Difficulty + minutes/servings
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Difficulty',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppTheme.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.twilight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButton<RecipeDifficulty>(
                            value: _difficulty,
                            isExpanded: true,
                            dropdownColor: AppColors.twilight,
                            underline: const SizedBox(),
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                              fontSize: 12,
                            ),
                            items: RecipeDifficulty.values
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _difficulty = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time (min)',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppTheme.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.twilight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<int>(
                            value: _cookMinutes,
                            isExpanded: true,
                            dropdownColor: AppColors.twilight,
                            underline: const SizedBox(),
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                              fontSize: 12,
                            ),
                            items: [15, 30, 45, 60, 90, 120]
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text('$m'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _cookMinutes = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servings',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppTheme.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.twilight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<int>(
                            value: _servings,
                            isExpanded: true,
                            dropdownColor: AppColors.twilight,
                            underline: const SizedBox(),
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                              fontSize: 12,
                            ),
                            items: [1, 2, 3, 4, 6, 8]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('$s'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _servings = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Ingredients',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ingredientNameController,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Name',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ingredientAmountController,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _addIngredient,
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
              if (_ingredients.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._ingredients.asMap().entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${e.value.amount} ${e.value.name}',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _ingredients.removeAt(e.key)),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppTheme.petalWhite.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Steps',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepController,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a step',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _addStep,
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
              if (_steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._steps.asMap().entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.deepRose,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _steps.removeAt(e.key)),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppTheme.petalWhite.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Tags',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      onSubmitted: (_) => _addTag(),
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppTheme.petalWhite,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add tag + enter',
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _addTag,
                          icon: const Icon(
                            Icons.add_rounded,
                            color: AppColors.blushGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _tags
                      .map(
                        (t) => Chip(
                          label: Text(
                            '#$t',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: AppColors.softLavender.withValues(
                            alpha: 0.12,
                          ),
                          deleteIcon: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          ),
                          onDeleted: () => setState(() => _tags.remove(t)),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _saving
                            ? [AppColors.moonlight, AppColors.moonlight]
                            : [AppColors.deepRose, const Color(0xFF8E1444)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save Recipe ✨',
                              style: AppTypography.outfitBold.copyWith(
                                color: Colors.white,
                                fontSize: 14,
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
}
