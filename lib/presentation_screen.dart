import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:microsoft_viewer/microsoft_viewer.dart';
import 'package:microsoft_viewer/domain/presentation_processor.dart';
import 'package:microsoft_viewer/models/presentation.dart' as ms;
import 'package:microsoft_viewer/models/relationship.dart' as ms_rel;
import 'package:microsoft_viewer/models/web_images.dart' as ms_web;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'package:path_provider/path_provider.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/stroke_width_slider.dart';
import '../widgets/slide_thumbnail.dart';

class PresentationScreen extends StatefulWidget {
  const PresentationScreen({Key? key}) : super(key: key);

  @override
  _PresentationScreenState createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
  bool _isDrawingMode = false;
  bool _isToolbarVisible = false;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 4.0;
  double _eraserWidth = 30.0;
  DrawingTool _selectedTool = DrawingTool.pen;
  Offset? _hoverPosition;

  int _currentPageIndex = 0;
  List<PresentationPage> _pages = [];
  DrawingStroke? _currentStroke;

  final List<List<DrawingStroke>> _undoHistory = [];
  final List<List<DrawingStroke>> _redoHistory = [];

  late AnimationController _toolbarAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  PdfDocument? _currentPdfDocument;
  bool _isLoadingDocument = false;
  double _pptxAspectRatio = 1.5;

  final ScrollController _sidebarScrollController = ScrollController();
  late PageController _pageController;

  // Darkening overlay opacity
  double _darkOverlayOpacity = 0.0;
  static const double MAX_DARK_OVERLAY = 0.2; // 20% darker

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _initializePages();
    _initToolbarAnimation();
  }

  void _initToolbarAnimation() {
    _toolbarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
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
    _currentPdfDocument?.dispose();
    _sidebarScrollController.dispose();
    _pageController.dispose();
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
              'Presentation Pro v1.0.1',
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
          if (!_isDrawingMode) ...[
            IconButton(
              icon: const Icon(Icons.file_open, color: Colors.indigo),
              onPressed: _pickDocument,
              tooltip: 'Load Document',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.draw, size: 18),
                label: const Text('Annotate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _enableDrawingMode,
              ),
            ),
          ] else ...[
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
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _disableDrawingMode,
              tooltip: 'Close Drawing',
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar (Thumbnails)
          _buildSidebar(),

          // Main Content Area
          Expanded(
            child: Stack(
              children: [
                // Main Document Viewer
                Column(
                  children: [
                    Expanded(
                      child: _buildContentPage(),
                    ),
                    _buildBottomNavigation(),
                  ],
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
                          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: StrokeWidthSlider(
                        strokeWidth: _selectedTool == DrawingTool.eraser ? _eraserWidth : _strokeWidth,
                        selectedColor: _selectedColor,
                        onStrokeWidthChanged: (width) => setState(() {
                          if (_selectedTool == DrawingTool.eraser) {
                            _eraserWidth = width;
                          } else {
                            _strokeWidth = width;
                          }
                        }),
                        min: _selectedTool == DrawingTool.eraser ? 10.0 : 1.0,
                        max: _selectedTool == DrawingTool.eraser ? 100.0 : 15.0,
                        label: _selectedTool == DrawingTool.eraser ? 'Duster Size' : 'Stroke Width',
                      ),
                    ),
                  ),

                // Global Document Loading Overlay
                if (_isLoadingDocument)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 3),
                              const SizedBox(height: 20),
                              Text(
                                'Processing Document...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This may take a moment',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPage() {
    if (_pages.isEmpty) return Container();

    return Container(
      color: Colors.grey.shade200,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        physics: _isDrawingMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
            _currentStroke = null;
          });
          _scrollToCurrentThumbnail();
        },
        itemBuilder: (context, index) {
          return _buildSlideItem(index);
        },
      ),
    );
  }

  Widget _buildSlideItem(int index) {
    final page = _pages[index];
    
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: !_isDrawingMode,
      scaleEnabled: !_isDrawingMode,
      child: Stack(
        children: [
          // 1. Content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildPageContent(page),
            ),
          ),
  
          // 2. Darkening overlay for better contrast
          if (_isDrawingMode && _darkOverlayOpacity > 0 && _currentPageIndex == index)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _darkOverlayOpacity,
                      child: Container(
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
  
          // 3. Drawing overlay (Always show strokes, but only current page is interactive)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: IgnorePointer(
                  ignoring: !_isDrawingMode || _currentPageIndex != index,
                  child: DrawingCanvas(
                    strokes: page.strokes,
                    currentStroke: _currentPageIndex == index ? _currentStroke : null,
                    selectedColor: _selectedColor,
                    strokeWidth: _strokeWidth,
                    eraserWidth: _eraserWidth,
                    selectedTool: _selectedTool,
                    hoverPosition: _currentPageIndex == index ? _hoverPosition : null,
                    onStrokeStart: _startStroke,
                    onStrokeUpdate: _updateStroke,
                    onStrokeEnd: _endStroke,
                    onHoverUpdate: (pos) => setState(() => _hoverPosition = pos),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(PresentationPage page) {
    switch (page.contentType) {
      case PageContentType.pdf:
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PdfPageView(
              document: _currentPdfDocument,
              pageNumber: (page.pdfPageIndex ?? 0) + 1,
              backgroundColor: Colors.white,
            ),
          ),
        );
      case PageContentType.pptx:
        if (page.extraData != null) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: _pptxAspectRatio,
                child: PptxSlideRenderer(
                  params: page.extraData as GetSlideParam,
                ),
              ),
            ),
          );
        }
        return Container();
      case PageContentType.image:
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.file(
              File(page.contentPath!),
              fit: BoxFit.contain,
            ),
          ),
        );
      case PageContentType.placeholder:
      default:
        return Container(
           decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _buildPlaceholderPage(page),
        );
    }
  }

  Widget _buildPlaceholderPage(PresentationPage page) {

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Document header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    const SizedBox(height: 4),
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

              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

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
              const SizedBox(height: 8),

              // Subtitle
              Text(
                page.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Content placeholder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildContentLine(0.8),
                    const SizedBox(height: 8),
                    _buildContentLine(0.6),
                    const SizedBox(height: 8),
                    _buildContentLine(0.9),
                    const SizedBox(height: 8),
                    _buildContentLine(0.5),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bullet points
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBulletPoint('Revenue', '+25%'),
                  _buildBulletPoint('Growth', '+15%'),
                  _buildBulletPoint('Market', 'Top 3'),
                ],
              ),

              const SizedBox(height: 24),

              // Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
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
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPageIndex > 0 ? _previousPage : null,
            tooltip: 'Previous Slide',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            icon: const Icon(Icons.chevron_right),
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
        width: _selectedTool == DrawingTool.eraser ? _eraserWidth : _strokeWidth,
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

  Widget _buildSidebar() {
    return Container(
      width: 180,
      color: Colors.grey.shade200,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'SLIDES',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _sidebarScrollController,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return SlideThumbnail(
                  page: _pages[index],
                  isSelected: _currentPageIndex == index,
                  onTap: () => _goToPage(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage(int index) {
    setState(() {
      _currentPageIndex = index;
      _currentStroke = null;
    });
    _scrollToCurrentThumbnail();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToCurrentThumbnail() {
    // 120 is approx height of each thumbnail item
    final targetOffset = _currentPageIndex * 120.0;
    if (_sidebarScrollController.hasClients) {
      _sidebarScrollController.animateTo(
        targetOffset.clamp(0, _sidebarScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPageIndex > 0) {
      _goToPage(_currentPageIndex - 1);
    }
  }

  void _nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      _goToPage(_currentPageIndex + 1);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'pptx'],
      allowMultiple: true,
    );

    if (result != null && result.isNotEmpty) {
      final List<String> paths = result.map((f) => f.path!).toList();
      
      // Check for PDF or PPTX first (prioritize documents over multiple images)
      final String? pdfPath = paths.any((p) => p.toLowerCase().endsWith('.pdf')) 
          ? paths.firstWhere((p) => p.toLowerCase().endsWith('.pdf')) : null;
      final String? pptxPath = paths.any((p) => p.toLowerCase().endsWith('.pptx'))
          ? paths.firstWhere((p) => p.toLowerCase().endsWith('.pptx')) : null;

      setState(() {
        _isLoadingDocument = true;
      });

      try {
        if (pdfPath != null) {
          await _loadPdf(pdfPath);
        } else if (pptxPath != null) {
          await _loadPptx(pptxPath);
        } else {
          // If no documents, load all selected items as images
          await _loadImages(paths);
        }
      } catch (e) {
        _showSnackBar('Error loading document: $e', Colors.red, Icons.error);
      } finally {
        setState(() {
          _isLoadingDocument = false;
        });
      }
    }
  }

  Future<void> _loadPdf(String path) async {
    final document = await PdfDocument.openFile(path);
    _currentPdfDocument?.dispose();
    _currentPdfDocument = document;
    
    final List<PresentationPage> newPages = [];
    for (int i = 0; i < document.pages.length; i++) {
      newPages.add(PresentationPage(
        pageNumber: i + 1,
        title: 'PDF Page ${i + 1}',
        subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
        icon: Icons.picture_as_pdf,
        contentType: PageContentType.pdf,
        contentPath: path,
        pdfPageIndex: i,
      ));
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = 0;
      _undoHistory.clear();
      _redoHistory.clear();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    _showSnackBar('PDF loaded: ${document.pages.length} pages', Colors.green, Icons.check_circle);
  }

  Future<void> _loadImages(List<String> paths) async {
    final List<PresentationPage> newPages = [];
    
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      newPages.add(PresentationPage(
        pageNumber: i + 1,
        title: 'Image ${i + 1}',
        subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
        icon: Icons.image,
        contentType: PageContentType.image,
        contentPath: path,
      ));
    }

    setState(() {
      _pages = newPages;
      _pptxAspectRatio = 1.5; // Standard aspect ratio for image list layout
      _currentPageIndex = 0;
      _undoHistory.clear();
      _redoHistory.clear();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    _showSnackBar('Images loaded: ${paths.length}', Colors.green, Icons.image);
  }

  Future<void> _loadPptx(String path) async {
    setState(() {
      _isLoadingDocument = true;
    });

    try {
      final bytes = File(path).readAsBytesSync();

      final appDir = await getApplicationSupportDirectory();
      final presentationDirPath = "${appDir.path}/presentation/";
      
      // Perform heavy zip decoding and theme parsing in background isolate
      final result = await compute(_parsePptxInBackground, {
        'bytes': bytes,
        'presentationDir': presentationDirPath,
      });

      final msPresentation = result['presentation'] as ms.Presentation;
      final webImages = result['webImages'] as List<ms_web.WebImages>;
      
      final List<PresentationPage> newPages = [];
      
      final double logicalWidth = (msPresentation.width ?? 9144000) / 12700;
      final double logicalHeight = (msPresentation.height ?? 6858000) / 12700;
      final double aspectRatio = logicalWidth / logicalHeight;

      for (int i = 0; i < msPresentation.slides.length; i++) {
        final slideParams = GetSlideParam(
          msPresentation.slides[i], 
          msPresentation.width, 
          msPresentation.height, 
          webImages,
        );

        newPages.add(PresentationPage(
          pageNumber: i + 1,
          title: 'Slide ${i + 1}',
          subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
          icon: Icons.slideshow,
          contentType: PageContentType.pptx,
          contentPath: path,
          extraData: slideParams,
        ));
      }

      setState(() {
        _pptxAspectRatio = aspectRatio;
        _pages = newPages;
        _currentPageIndex = 0;
        _undoHistory.clear();
        _redoHistory.clear();
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      _showSnackBar('PPTX loaded: ${newPages.length} slides', Colors.orange, Icons.slideshow);
    } catch (e) {
      _showSnackBar('Error loading PPTX: $e', Colors.red, Icons.error);
    } finally {
      setState(() {
        _isLoadingDocument = false;
      });
    }
  }
}

/// Top-level function for background isolate PPTX processing
Future<Map<String, dynamic>> _parsePptxInBackground(Map<String, dynamic> params) async {
  final Uint8List bytes = params['bytes'];
  final String presentationDir = params['presentationDir'];
  
  final archive = ZipDecoder().decodeBytes(bytes);
  
  // Setup directory for media extraction
  final dir = Directory(presentationDir);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  dir.createSync(recursive: true);

  // 1. Relationships
  final relFile = archive.singleWhere((f) => f.name.endsWith("presentation.xml.rels"));
  final List<ms_rel.Relationship> relationships = [];
  final relContent = utf8.decode(relFile.content);
  final relDoc = xml.XmlDocument.parse(relContent);
  for (var rel in relDoc.findAllElements("Relationship")) {
    if (rel.getAttribute("Id") != null) {
      relationships.add(ms_rel.Relationship(rel.getAttribute("Id")!, rel.getAttribute("Target")!));
    }
  }

  // 2. Extract media
  final List<ms_web.WebImages> webImages = [];
  final mediaFiles = archive.where((f) => f.name.startsWith('ppt/media/'));
  for (var medFile in mediaFiles) {
    final outFile = File("${presentationDir}${medFile.name.split("/").last}");
    outFile.writeAsBytesSync(medFile.content as List<int>);
    webImages.add(ms_web.WebImages(medFile.name.split("/").last, medFile.content));
  }

  // 3. One-time Presentation/Theme processing
  final presentationFile = archive.singleWhere((f) => f.name.endsWith("ppt/presentation.xml"));
  final ms.Presentation msPresentation = ms.Presentation("document");
  final processor = PresentationProcessor();
  processor.getPresentationDetails(presentationFile, msPresentation);
  
  // Perform parsing in the background isolate
  await processor.readAllSlides(msPresentation, relationships, archive, presentationDir);

  return {
    'presentation': msPresentation,
    'webImages': webImages,
  };
}

/// A specialized widget to render PPTX slides on demand.
/// This prevents the performance lag caused by building all slides upfront.
class PptxSlideRenderer extends StatefulWidget {
  final GetSlideParam params;
  final double? logicalWidth;

  const PptxSlideRenderer({
    super.key,
    required this.params,
    this.logicalWidth,
  });

  @override
  State<PptxSlideRenderer> createState() => _PptxSlideRendererState();
}

class _PptxSlideRendererState extends State<PptxSlideRenderer> {
  List<Widget>? _cachedWidgets;

  @override
  Widget build(BuildContext context) {
    // If already rendered, use cache to prevent stutter during scrolling
    if (_cachedWidgets != null) {
      return _buildContent(_cachedWidgets!);
    }

    // We fetch slide details only when this widget is actually built (rendered on screen)
    // Using FutureBuilder to show loading state if it takes time
    return FutureBuilder<List<Widget>>(
      future: Future.value(PresentationProcessor.getSlideDetails(widget.params)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (snapshot.hasData) {
          _cachedWidgets = snapshot.data;
          return _buildContent(_cachedWidgets!);
        }
        return const Center(child: Text("Error rendering slide"));
      },
    );
  }

  Widget _buildContent(List<Widget> slideDetailWidgets) {
    final Widget rawContent = slideDetailWidgets.isNotEmpty
        ? slideDetailWidgets.first
        : Container(
            color: Colors.white,
            child: const Center(child: Text("Empty Slide")),
          );

    return FittedBox(
      fit: BoxFit.contain,
      child: UnconstrainedBox(
        child: SizedBox(
          width: widget.logicalWidth ?? (widget.params.width ?? 9144000) / 12700,
          child: rawContent,
        ),
      ),
    );
  }
}
