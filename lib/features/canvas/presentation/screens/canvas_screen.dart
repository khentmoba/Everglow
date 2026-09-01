import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/everglow/everglow_error_state.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/presence_service.dart';
import '../../../../shared/widgets/partner_doodle_indicator.dart';
import '../../domain/models/doodle_stroke.dart';
import '../../data/services/canvas_service.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/canvas_toolbar.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final CanvasService _canvasService = CanvasService();
  DoodleStroke? _activeStroke;
  List<DoodleStroke> _liveStrokes =
      []; // Strokes currently being drawn by others
  StreamSubscription? _liveSubscription;
  DateTime? _lastSyncTime;
  DateTime? _lastDoodlePresenceAt;
  PresenceService? _presenceService;
  DragStartDetails? _pendingPanStartDetails;
  String? _pendingPanUserId;

  final List<DoodleStroke> _sessionStrokes = [];
  final List<DoodleStroke> _redoStack = [];

  CanvasTool _activeTool = CanvasTool.pen;
  String _currentColor = '#FFC0CB';
  double _currentWidth = 3.0;
  final double _eraserRadius = 15.0;

  @override
  void initState() {
    super.initState();
    _liveSubscription = _canvasService.getLiveStrokesStream().listen((strokes) {
      if (mounted) {
        setState(() {
          _liveStrokes = strokes;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _presenceService ??= context.read<PresenceService>();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    final presence = _presenceService;
    final auth = mounted ? context.read<AuthService>() : null;
    final uid = auth?.uid;
    if (presence != null && uid != null) {
      presence.clearDoodling(uid);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.uid ?? 'unknown';

    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        title: Text(
          'Everglow Canvas',
          style: AppTypography.cormorantBold.copyWith(fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: EverglowIconButton.back(
          onPressed: () => Navigator.of(context).pop(),
          iconColor: AppColors.roseQuartz,
        ),
      ),
      body: Stack(
        children: [
          // 0. Atmosphere
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.auroraTeal,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.08,
                ),
              ],
            ),
          ),
          // 1. Combined Strokes
          Positioned.fill(
            child: StreamBuilder<List<DoodleStroke>>(
              stream: _canvasService.getStrokesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EverglowErrorState(
                    message: 'Could not load canvas: ${snapshot.error}',
                    onRetry: () => setState(() {}),
                    icon: Icons.brush_outlined,
                  );
                }

                final isLoading = !snapshot.hasData;
                final historyStrokes = snapshot.data ?? [];

                // Combine history with live strokes from others
                final othersLiveStrokes = _liveStrokes
                    .where((s) => s.userId != userId)
                    .toList();
                final allStrokes = [...historyStrokes, ...othersLiveStrokes];

                return Stack(
                  children: [
                    ClipRect(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: _canvasKey,
                          painter: CanvasPainter(
                            strokes: allStrokes,
                            activeStroke: _activeStroke,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.roseQuartz,
                          strokeWidth: 2,
                        ),
                      ),
                    if (!isLoading &&
                        allStrokes.isEmpty &&
                        _activeStroke == null)
                      Center(
                        child: Text(
                          'Draw something together',
                          style: AppTypography.cormorantRegular.copyWith(
                            fontSize: 26,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 2. Gesture Detector
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => _onPanStart(details, userId),
              onPanUpdate: (details) => _onPanUpdate(details, userId),
              onPanEnd: (details) => _onPanEnd(details, userId),
              child: Container(color: Colors.white.withValues(alpha: 0.001)),
            ),
          ),

          // 3. Floating Toolbar
          Align(
            alignment: Alignment.bottomCenter,
            child: CanvasToolbar(
              activeTool: _activeTool,
              activeColor: _currentColor,
              strokeWidth: _currentWidth,
              onToolChanged: (tool) => setState(() => _activeTool = tool),
              onColorChanged: (color) => setState(() => _currentColor = color),
              onStrokeWidthChanged: (w) => setState(() => _currentWidth = w),
              onClear: _showClearConfirmation,
              onUndo: _undo,
              onRedo: _redo,
              canUndo: _sessionStrokes.isNotEmpty,
              canRedo: _redoStack.isNotEmpty,
            ),
          ),

          // 4. Partner Doodle Presence Indicator
          const Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SafeArea(bottom: false, child: PartnerDoodleIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.velvet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Clear Canvas?',
          style: AppTypography.cormorantBold.copyWith(fontSize: 22),
        ),
        content: Text(
          'This will permanently delete all doodles for everyone. Are you sure?',
          style: AppTypography.outfitWhite.copyWith(
            color: AppTheme.petalWhite.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _canvasService.clearAllStrokes();
              Navigator.pop(context);
            },
            child: Text(
              'Clear',
              style: AppTypography.outfitWhite.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPanStart(DragStartDetails details, String userId) {
    if (_activeTool == CanvasTool.eraser) {
      _handleEraserAction(details.globalPosition);
    } else if (_activeTool == CanvasTool.text) {
      _handleTextToolTap(details.globalPosition, userId);
    } else {
      final RenderBox? box =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        _pendingPanStartDetails = details;
        _pendingPanUserId = userId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pending = _pendingPanStartDetails;
          final pendingUid = _pendingPanUserId;
          if (pending != null && pendingUid != null) {
            _pendingPanStartDetails = null;
            _pendingPanUserId = null;
            _onPanStart(pending, pendingUid);
          }
        });
        return;
      }

      setState(() {
        final localPosition = box.globalToLocal(details.globalPosition);

        _activeStroke = DoodleStroke(
          id: '',
          userId: userId,
          color: _currentColor,
          strokeWidth: _currentWidth,
          points: [
            {
              'x': (localPosition.dx / box.size.width).clamp(0.0, 1.0),
              'y': (localPosition.dy / box.size.height).clamp(0.0, 1.0),
            },
          ],
        );

        // Initial sync
        _canvasService.updateActiveStroke(userId, _activeStroke!);
        _lastSyncTime = DateTime.now();
      });
    }

    _bumpDoodlePresence(userId);
  }

  void _onPanUpdate(DragUpdateDetails details, String userId) {
    if (_activeTool == CanvasTool.eraser) {
      _handleEraserAction(details.globalPosition);
    } else if (_activeStroke != null) {
      setState(() {
        final RenderBox? box =
            _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;

        final localPosition = box.globalToLocal(details.globalPosition);

        final newPoint = {
          'x': (localPosition.dx / box.size.width).clamp(0.0, 1.0),
          'y': (localPosition.dy / box.size.height).clamp(0.0, 1.0),
        };

        final lastPoint = _activeStroke!.points.last;
        final dx = newPoint['x']! - lastPoint['x']!;
        final dy = newPoint['y']! - lastPoint['y']!;

        if ((dx * dx + dy * dy) > 0.000001) {
          final updatedPoints = List<Map<String, double>>.from(
            _activeStroke!.points,
          )..add(newPoint);
          _activeStroke = _activeStroke!.copyWith(points: updatedPoints);

          // Real-time Throttled Sync
          final now = DateTime.now();
          if (_lastSyncTime == null ||
              now.difference(_lastSyncTime!) >
                  const Duration(milliseconds: 100)) {
            _canvasService.updateActiveStroke(userId, _activeStroke!);
            _lastSyncTime = now;
          }
        }
      });
    }

    _bumpDoodlePresence(userId);
  }

  void _bumpDoodlePresence(String userId) {
    final presence = _presenceService;
    if (presence == null) return;
    final now = DateTime.now();
    if (_lastDoodlePresenceAt != null &&
        now.difference(_lastDoodlePresenceAt!) <
            const Duration(milliseconds: 1500)) {
      return;
    }
    _lastDoodlePresenceAt = now;
    presence.markDoodling(userId);
  }

  void _handleTextToolTap(Offset globalPosition, String userId) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(globalPosition);
    final normX = localPosition.dx / box.size.width;
    final normY = localPosition.dy / box.size.height;

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.velvet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add Text', style: AppTypography.cormorantBold),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite),
          decoration: InputDecoration(
            hintText: 'Type something...',
            hintStyle: AppTypography.outfitWhite.copyWith(
              color: AppTheme.roseQuartz.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppTheme.twilight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            _saveTextAnnotation(controller.text, normX, normY, userId);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.roseQuartz,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _saveTextAnnotation(controller.text, normX, normY, userId);
              Navigator.pop(context);
            },
            child: Text(
              'Add',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.blushGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveTextAnnotation(
    String text,
    double normX,
    double normY,
    String userId,
  ) {
    if (text.trim().isEmpty) return;
    final stroke = DoodleStroke(
      id: '',
      userId: userId,
      color: _currentColor,
      strokeWidth: _currentWidth,
      points: [
        {'x': normX, 'y': normY},
      ],
      text: text.trim(),
    );
    _canvasService.saveStroke(stroke).then((_) {
      _sessionStrokes.add(stroke);
      _redoStack.clear();
    });
  }

  void _handleEraserAction(Offset globalPosition) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(globalPosition);
    final normX = localPosition.dx / box.size.width;
    final normY = localPosition.dy / box.size.height;

    final normRadiusX = _eraserRadius / box.size.width;
    final normRadiusY = _eraserRadius / box.size.height;

    _canvasService.getStrokesStream().first.then((strokes) {
      for (var stroke in strokes) {
        for (var point in stroke.points) {
          final dx = point['x']! - normX;
          final dy = point['y']! - normY;

          if ((dx * dx) / (normRadiusX * normRadiusX) +
                  (dy * dy) / (normRadiusY * normRadiusY) <
              1.0) {
            _canvasService.deleteStroke(stroke.id);
            break;
          }
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details, String userId) async {
    if (_activeStroke == null) return;

    // Clear live sync immediately
    _canvasService.clearActiveStroke(userId);

    if (_activeStroke!.points.length >= 2) {
      final simplifiedPoints = _canvasService.simplifyPoints(
        _activeStroke!.points,
      );
      final strokeToSave = _activeStroke!.copyWith(points: simplifiedPoints);

      _canvasService.saveStroke(strokeToSave).then((_) {
        _sessionStrokes.add(strokeToSave);
        _redoStack.clear();
      });
    }

    setState(() {
      _activeStroke = null;
    });
  }

  void _undo() async {
    if (_sessionStrokes.isEmpty) return;

    final lastStroke = _sessionStrokes.removeLast();
    _redoStack.add(lastStroke);

    final strokes = await _canvasService.getStrokesStream().first;
    try {
      final actualStroke = strokes.lastWhere(
        (s) =>
            s.userId == lastStroke.userId &&
            s.points.length == lastStroke.points.length,
      );
      _canvasService.deleteStroke(actualStroke.id);
    } catch (_) {}
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    final strokeToRedo = _redoStack.removeLast();
    _sessionStrokes.add(strokeToRedo);
    _canvasService.saveStroke(strokeToRedo);
  }
}
