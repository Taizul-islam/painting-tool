import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/stroke_width_slider.dart';

class PresentationScreen extends StatefulWidget {
  @override
  _PresentationScreenState createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
  bool _isDrawingMode = false;
  bool _isToolbarVisible = false;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 4.0;
  DrawingTool _selectedTool = DrawingTool.pen;

  int _currentPageIndex = 0;
  List<PresentationPage> _pages = [];
  DrawingStroke? _currentStroke;

  List<List<DrawingStroke>> _undoHistory = [];
  List<List<DrawingStroke>> _redoHistory = [];

  late AnimationController _toolbarAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Darkening overlay opacity
  double _darkOverlayOpacity = 0.0;
  static const double MAX_DARK_OVERLAY = 0.3; // 30% darker

  @override
  void initState() {
    super.initState();
    _initializePages();
    _initToolbarAnimation();
  }

  void _initToolbarAnimation() {
    _toolbarAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeIn,
    ));
  }

  void _initializePages() {
    _pages = [
      PresentationPage(
        pageNumber: 1,
        title: 'Quarterly Business Review',
        subtitle: 'Financial Performance & Growth Strategy',
        icon: Icons.trending_up,
      ),
      PresentationPage(
        pageNumber: 2,
        title: 'Market Analysis',
        subtitle: 'Competitive Landscape & Market Trends',
        icon: Icons.analytics,
      ),
      PresentationPage(
        pageNumber: 3,
        title: 'Product Roadmap',
        subtitle: 'Innovation & Development Timeline',
        icon: Icons.rocket_launch,
      ),
      PresentationPage(
        pageNumber: 4,
        title: 'Customer Success',
        subtitle: 'Case Studies & Testimonials',
        icon: Icons.star,
      ),
      PresentationPage(
        pageNumber: 5,
        title: 'Strategic Initiatives',
        subtitle: 'Key Priorities for Next Quarter',
        icon: Icons.flag,
      ),
    ];
  }

  @override
  void dispose() {
    _toolbarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Presentation Pro',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Slide ${_currentPageIndex + 1} of ${_pages.length}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isDrawingMode)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: Icon(Icons.draw, size: 18),
                label: Text('Annotate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _enableDrawingMode,
              ),
            )
          else ...[
            // Dark overlay toggle button
            IconButton(
              icon: Icon(
                _darkOverlayOpacity > 0 ? Icons.brightness_high : Icons.brightness_low,
                color: _darkOverlayOpacity > 0 ? Colors.amber : Colors.grey.shade600,
                size: 20,
              ),
              onPressed: _toggleDarkOverlay,
              tooltip: _darkOverlayOpacity > 0 ? 'Remove Dark Overlay' : 'Add Dark Overlay',
            ),
            IconButton(
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _toolbarAnimationController,
                color: Colors.indigo,
              ),
              onPressed: _toggleToolbar,
              tooltip: 'Toggle Toolbar',
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: _disableDrawingMode,
              tooltip: 'Close Drawing',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Main PDF Viewer
          Column(
            children: [
              Expanded(
                child: _buildPDFViewer(),
              ),
              _buildBottomNavigation(),
            ],
          ),

          // Dark overlay for better contrast
          if (_isDrawingMode && _darkOverlayOpacity > 0)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: 300),
                      opacity: _darkOverlayOpacity,
                      child: Container(
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Drawing overlay
          if (_isDrawingMode)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DrawingCanvas(
                    strokes: _pages[_currentPageIndex].strokes,
                    currentStroke: _currentStroke,
                    selectedColor: _selectedColor,
                    strokeWidth: _strokeWidth,
                    selectedTool: _selectedTool,
                    onStrokeStart: _startStroke,
                    onStrokeUpdate: _updateStroke,
                    onStrokeEnd: _endStroke,
                  ),
                ),
              ),
            ),

          // Animated Side Toolbar (without slider)
          if (_isDrawingMode && _isToolbarVisible)
            Positioned(
              left: 0,
              top: 0,
              bottom: 120, // Leave space for bottom slider
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
                    child: DrawingToolbar(
                      selectedColor: _selectedColor,
                      strokeWidth: _strokeWidth,
                      selectedTool: _selectedTool,
                      onColorChanged: (color) => setState(() => _selectedColor = color),
                      onStrokeWidthChanged: (width) => setState(() => _strokeWidth = width),
                      onToolChanged: (tool) => setState(() => _selectedTool = tool),
                      onUndo: _undo,
                      onRedo: _redo,
                      onClear: _clearStrokes,
                      onClose: _disableDrawingMode,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Stroke Width Slider
          if (_isDrawingMode && _isToolbarVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: StrokeWidthSlider(
                  strokeWidth: _strokeWidth,
                  selectedColor: _selectedColor,
                  onStrokeWidthChanged: (width) => setState(() => _strokeWidth = width),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPDFViewer() {
    return Container(
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // PDF Page background
            Container(
              color: Colors.white,
              child: _buildPDFPage(),
            ),

            // PDF overlay effects
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.02),
                        Colors.transparent,
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Page shadow effect
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 30,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Page curl effect (right side)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 15,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.08),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading indicator (simulated)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Loaded',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPDFPage() {
    final page = _pages[_currentPageIndex];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Document header
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'COMPANY CONFIDENTIAL',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade400,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Internal Document',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Main content area
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  page.icon,
                  color: Colors.white,
                  size: 35,
                ),
              ),
              SizedBox(height: 24),

              // Title
              Text(
                page.title,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),

              // Subtitle
              Text(
                page.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24),

              // Content placeholder
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildContentLine(0.8),
                    SizedBox(height: 8),
                    _buildContentLine(0.6),
                    SizedBox(height: 8),
                    _buildContentLine(0.9),
                    SizedBox(height: 8),
                    _buildContentLine(0.5),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Bullet points
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBulletPoint('Revenue', '+25%'),
                  _buildBulletPoint('Growth', '+15%'),
                  _buildBulletPoint('Market', 'Top 3'),
                ],
              ),

              SizedBox(height: 24),

              // Footer
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page ${page.pageNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      '© 2024 Company Name',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentLine(double width) {
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: width,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: _currentPageIndex > 0 ? _previousPage : null,
            tooltip: 'Previous Slide',
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '${_currentPageIndex + 1} / ${_pages.length}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _currentPageIndex < _pages.length - 1 ? _nextPage : null,
            tooltip: 'Next Slide',
          ),
        ],
      ),
    );
  }

  void _toggleDarkOverlay() {
    setState(() {
      if (_darkOverlayOpacity > 0) {
        _darkOverlayOpacity = 0.0;
      } else {
        _darkOverlayOpacity = MAX_DARK_OVERLAY;
      }
    });
    _showSnackBar(
      _darkOverlayOpacity > 0 ? 'Dark overlay enabled' : 'Dark overlay disabled',
      _darkOverlayOpacity > 0 ? Colors.amber.shade700 : Colors.grey,
      _darkOverlayOpacity > 0 ? Icons.brightness_low : Icons.brightness_high,
    );
  }

  void _enableDrawingMode() {
    setState(() {
      _isDrawingMode = true;
      _isToolbarVisible = true;
      _darkOverlayOpacity = MAX_DARK_OVERLAY; // Auto-enable dark overlay
      _undoHistory.clear();
      _redoHistory.clear();
    });
    _toolbarAnimationController.forward();
    _showSnackBar('Drawing mode enabled', Colors.indigo, Icons.draw);
  }

  void _disableDrawingMode() {
    _toolbarAnimationController.reverse().then((_) {
      setState(() {
        _isDrawingMode = false;
        _isToolbarVisible = false;
        _darkOverlayOpacity = 0.0; // Reset dark overlay
        _currentStroke = null;
      });
    });
    _showSnackBar('Drawing mode disabled', Colors.grey, Icons.close);
  }

  void _toggleToolbar() {
    setState(() {
      _isToolbarVisible = !_isToolbarVisible;
    });
    if (_isToolbarVisible) {
      _toolbarAnimationController.forward();
    } else {
      _toolbarAnimationController.reverse();
    }
  }

  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [position],
        color: _selectedColor,
        width: _strokeWidth,
        tool: _selectedTool,
      );
    });
  }

  void _updateStroke(Offset position) {
    if (_currentStroke != null) {
      setState(() {
        _currentStroke!.points.add(position);
      });
    }
  }

  void _endStroke() {
    if (_currentStroke != null && _currentStroke!.points.length > 1) {
      setState(() {
        _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
        _redoHistory.clear();

        final updatedStrokes = List<DrawingStroke>.from(_pages[_currentPageIndex].strokes)
          ..add(_currentStroke!);
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: updatedStrokes);
        _currentStroke = null;
      });
    } else {
      setState(() {
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_undoHistory.isNotEmpty) {
      setState(() {
        _redoHistory.add(List.from(_pages[_currentPageIndex].strokes));
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(
          strokes: _undoHistory.removeLast(),
        );
      });
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      setState(() {
        _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(
          strokes: _redoHistory.removeLast(),
        );
      });
    }
  }

  void _clearStrokes() {
    setState(() {
      _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: []);
    });
    _showSnackBar('Canvas cleared', Colors.orange, Icons.delete);
  }

  void _previousPage() {
    setState(() {
      _currentPageIndex--;
      _currentStroke = null;
    });
  }

  void _nextPage() {
    setState(() {
      _currentPageIndex++;
      _currentStroke = null;
    });
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}