import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../domain/models/doodle_stroke.dart';
import '../../data/services/canvas_service.dart';
import '../widgets/canvas_painter.dart';
import '../widgets/canvas_toolbar.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final CanvasService _canvasService = CanvasService();
  DoodleStroke? _activeStroke;
  List<DoodleStroke> _liveStrokes = []; // Strokes currently being drawn by others
  StreamSubscription? _liveSubscription;
  DateTime? _lastSyncTime;

  final List<DoodleStroke> _sessionStrokes = []; 
  final List<DoodleStroke> _redoStack = [];
  
  CanvasTool _activeTool = CanvasTool.pen;
  String _currentColor = '#FFC0CB'; 
  double _currentWidth = 3.0;
  double _eraserRadius = 15.0; 

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
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.uid ?? 'unknown';

    return Scaffold(
      backgroundColor: Colors.pink[50], 
      appBar: AppBar(
        title: const Text('Everglow Canvas', style: TextStyle(color: Colors.pinkAccent)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.pinkAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 1. Combined Strokes
          StreamBuilder<List<DoodleStroke>>(
            stream: _canvasService.getStrokesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final historyStrokes = snapshot.data ?? [];
              
              // Combine history with live strokes from others
              final othersLiveStrokes = _liveStrokes.where((s) => s.userId != userId).toList();
              final allStrokes = [...historyStrokes, ...othersLiveStrokes];

              return RepaintBoundary(
                child: CustomPaint(
                  key: _canvasKey,
                  painter: CanvasPainter(
                    strokes: allStrokes,
                    activeStroke: _activeStroke,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),

          // 2. Gesture Detector - Fix: use a non-fully-transparent color for reliable hits
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => _onPanStart(details, userId),
              onPanUpdate: (details) => _onPanUpdate(details, userId),
              onPanEnd: (details) => _onPanEnd(details, userId),
              child: Container(color: Colors.white.withOpacity(0.001)),
            ),
          ),

          // 3. Floating Toolbar
          Align(
            alignment: Alignment.bottomCenter,
            child: CanvasToolbar(
              activeTool: _activeTool,
              activeColor: _currentColor,
              onToolChanged: (tool) => setState(() => _activeTool = tool),
              onColorChanged: (color) => setState(() => _currentColor = color),
              onClear: _showClearConfirmation,
              onUndo: _undo,
              onRedo: _redo,
              canUndo: _sessionStrokes.isNotEmpty,
              canRedo: _redoStack.isNotEmpty,
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
        title: const Text('Clear Canvas?'),
        content: const Text('This will permanently delete all doodles for everyone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _canvasService.clearAllStrokes();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _onPanStart(DragStartDetails details, String userId) {
    if (_activeTool == CanvasTool.eraser) {
      _handleEraserAction(details.globalPosition);
      return;
    }

    setState(() {
      final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      
      final localPosition = box.globalToLocal(details.globalPosition);
      
      _activeStroke = DoodleStroke(
        id: '',
        userId: userId,
        color: _currentColor,
        strokeWidth: _currentWidth,
        points: [
          {
            'x': localPosition.dx / box.size.width,
            'y': localPosition.dy / box.size.height,
          }
        ],
      );

      // Initial sync
      _canvasService.updateActiveStroke(userId, _activeStroke!);
      _lastSyncTime = DateTime.now();
    });
  }

  void _onPanUpdate(DragUpdateDetails details, String userId) {
    if (_activeTool == CanvasTool.eraser) {
      _handleEraserAction(details.globalPosition);
      return;
    }

    if (_activeStroke == null) return;

    setState(() {
      final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
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
        final updatedPoints = List<Map<String, double>>.from(_activeStroke!.points)..add(newPoint);
        _activeStroke = _activeStroke!.copyWith(points: updatedPoints);

        // Real-time Throttled Sync
        final now = DateTime.now();
        if (_lastSyncTime == null || now.difference(_lastSyncTime!) > const Duration(milliseconds: 100)) {
          _canvasService.updateActiveStroke(userId, _activeStroke!);
          _lastSyncTime = now;
        }
      }
    });
  }

  void _handleEraserAction(Offset globalPosition) {
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
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
          
          if ((dx * dx) / (normRadiusX * normRadiusX) + (dy * dy) / (normRadiusY * normRadiusY) < 1.0) {
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
      final simplifiedPoints = _canvasService.simplifyPoints(_activeStroke!.points);
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
        (s) => s.userId == lastStroke.userId && s.points.length == lastStroke.points.length
      );
      _canvasService.deleteStroke(actualStroke.id);
    } catch (_) {
    }
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    
    final strokeToRedo = _redoStack.removeLast();
    _sessionStrokes.add(strokeToRedo);
    _canvasService.saveStroke(strokeToRedo);
  }
}
