import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StrokeWidthSlider extends StatelessWidget {
  final double strokeWidth;
  final Color selectedColor;
  final Function(double) onStrokeWidthChanged;
  final double min;
  final double max;
  final String label;

  const StrokeWidthSlider({
    Key? key,
    required this.strokeWidth,
    required this.selectedColor,
    required this.onStrokeWidthChanged,
    this.min = 1.0,
    this.max = 15.0,
    this.label = 'Stroke Width',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon and Label
          Icon(
            label.contains('Duster') ? Icons.auto_fix_high : Icons.edit,
            size: 16,
            color: label.contains('Duster') ? Colors.orange : selectedColor,
          ),
          SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 16),
          // The Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: strokeWidth,
                min: min,
                max: max,
                activeColor: label.contains('Duster') ? Colors.orange.shade700 : Colors.indigo,
                inactiveColor: Colors.grey.shade200,
                onChanged: onStrokeWidthChanged,
              ),
            ),
          ),
          SizedBox(width: 12),
          // Width value
          Container(
            width: 60,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${strokeWidth.toInt()} px',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: label.contains('Duster') ? Colors.orange.shade800 : Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
