import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });
}

class PresentationPage {
  final int pageNumber;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<DrawingStroke> strokes;

  PresentationPage({
    required this.pageNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.strokes = const [],
  });

  PresentationPage copyWith({
    List<DrawingStroke>? strokes,
  }) {
    return PresentationPage(
      pageNumber: pageNumber,
      title: title,
      subtitle: subtitle,
      icon: icon,
      strokes: strokes ?? this.strokes,
    );
  }
}