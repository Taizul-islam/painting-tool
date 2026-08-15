import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StrokeWidthSlider extends StatelessWidget {
  final double strokeWidth;
  final Color selectedColor;
  final Function(double) onStrokeWidthChanged;

  const StrokeWidthSlider({
    Key? key,
    required this.strokeWidth,
    required this.selectedColor,
    required this.onStrokeWidthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Small circle indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Stroke Width',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Spacer(),
              // Width value
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${strokeWidth.toStringAsFixed(1)} px',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
              Expanded(
                child: Slider(
                  value: strokeWidth,
                  min: 1,
                  max: 15,
                  activeColor: Colors.indigo,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: onStrokeWidthChanged,
                ),
              ),
              Icon(Icons.circle, size: 24, color: Colors.grey.shade400),
            ],
          ),
        ],
      ),
    );
  }
}