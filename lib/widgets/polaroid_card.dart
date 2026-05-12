import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/memory.dart';
import '../theme.dart';
import 'package:animate_do/animate_do.dart';

class PolaroidCard extends StatefulWidget {
  final Memory memory;
  final bool isLeft;
  final VoidCallback onDelete;

  const PolaroidCard({
    super.key,
    required this.memory,
    required this.isLeft,
    required this.onDelete,
  });

  @override
  State<PolaroidCard> createState() => _PolaroidCardState();
}

class _PolaroidCardState extends State<PolaroidCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Area
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: AppTheme.cream,
                    child: widget.memory.imageUrl != null
                        ? Image.network(
                            widget.memory.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                          )
                        : const Icon(Icons.favorite, color: AppTheme.blush, size: 48),
                  ),
                ),
                const SizedBox(height: 16),
                // Caption Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.memory.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMMM d, yyyy').format(widget.memory.date),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Expandable Description
                AnimatedCrossFade(
                  firstChild: Text(
                    widget.memory.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  secondChild: Text(
                    widget.memory.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                TextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    _isExpanded ? 'See Less' : 'See More',
                    style: const TextStyle(
                      color: AppTheme.taupe,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
