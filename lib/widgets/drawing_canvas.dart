import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';

class DrawingCanvas extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final Color selectedColor;
  final double strokeWidth;
  final DrawingTool selectedTool;
  final Function(Offset) onStrokeStart;
  final Function(Offset) onStrokeUpdate;
  final Function() onStrokeEnd;

  const DrawingCanvas({
    Key? key,
    required this.strokes,
    required this.currentStroke,
    required this.selectedColor,
    required this.strokeWidth,
    required this.selectedTool,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  }) : super(key: key);

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        _isDrawing = true;
        widget.onStrokeStart(event.localPosition);
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_isDrawing) {
          widget.onStrokeUpdate(event.localPosition);
        }
      },
      onPointerUp: (PointerUpEvent event) {
        if (_isDrawing) {
          _isDrawing = false;
          widget.onStrokeEnd();
        }
      },
      onPointerCancel: (PointerCancelEvent event) {
        if (_isDrawing) {
          _isDrawing = false;
          widget.onStrokeEnd();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        size: Size.infinite,
        painter: DrawingPainter(
          strokes: widget.strokes,
          currentStroke: widget.currentStroke,
          color: widget.selectedColor,
          strokeWidth: widget.strokeWidth,
          tool: widget.selectedTool,
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final Color color;
  final double strokeWidth;
  final DrawingTool tool;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
    required this.tool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (var stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke
    if (currentStroke != null && currentStroke!.points.length > 1) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.tool == DrawingTool.eraser
          ? Colors.white
          : stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Highlighter effect
    if (stroke.tool == DrawingTool.highlighter) {
      paint.color = stroke.color.withOpacity(0.3);
      paint.strokeWidth = stroke.width * 3;
    }

    final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);

    // Use quadratic bezier for smooth curves
    if (stroke.points.length == 2) {
      path.lineTo(stroke.points[1].dx, stroke.points[1].dy);
    } else {
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final midPoint = Offset(
          (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
          (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          stroke.points[i].dx,
          stroke.points[i].dy,
          midPoint.dx,
          midPoint.dy,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return true;
  }
}