import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/stroke_width_slider.dart';
import '../widgets/slide_thumbnail.dart';
import '../services/pptx_converter_libreoffice.dart';
import '../services/export_service.dart';

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
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Processing Document...';

  final ScrollController _sidebarScrollController = ScrollController();
  late PageController _pageController;

  double _darkOverlayOpacity = 0.0;
  static const double MAX_DARK_OVERLAY = 0.2;

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
        title: 'Blank Slide 1',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ),
      PresentationPage(
        pageNumber: 2,
        title: 'Blank Slide 2',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ),
      PresentationPage(
        pageNumber: 3,
        title: 'Blank Slide 3',
        subtitle: 'Start writing or annotate',
        icon: Icons.note_add,
        contentType: PageContentType.image,
        contentPath: null,
        backgroundColor: Colors.white,
      ),
    ];
  }

  void _createNewPresentation() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('New Presentation'),
          content: Text('This will clear all current slides and create 3 new blank slides. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  _isDrawingMode = false;
                  _isToolbarVisible = false;
                  _darkOverlayOpacity = 0.0;
                  _currentStroke = null;
                  _currentPageIndex = 0;
                  _undoHistory.clear();
                  _redoHistory.clear();
                  _currentPdfDocument?.dispose();
                  _currentPdfDocument = null;
                  _initializePages();

                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                });
                _showSnackBar('New presentation created', Colors.teal, Icons.check_circle);
              },
              child: Text('Create New'),
            ),
          ],
        );
      },
    );
  }

  void _showNewPresentationDialog() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Export Successful'),
              content: Text('Do you want to create a new presentation?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('No, Continue'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _isDrawingMode = false;
                      _isToolbarVisible = false;
                      _darkOverlayOpacity = 0.0;
                      _currentStroke = null;
                      _currentPageIndex = 0;
                      _undoHistory.clear();
                      _redoHistory.clear();
                      _currentPdfDocument?.dispose();
                      _currentPdfDocument = null;
                      _initializePages();

                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(0);
                      }
                    });
                    _showSnackBar('New presentation created', Colors.teal, Icons.check_circle);
                  },
                  child: Text('Yes, New Presentation'),
                ),
              ],
            );
          },
        );
      }
    });
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
              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
              onPressed: _createNewPresentation,
              tooltip: 'New Presentation',
            ),
            IconButton(
              icon: const Icon(Icons.file_open, color: Colors.indigo),
              onPressed: _pickDocument,
              tooltip: 'Load Document',
            ),
            IconButton(
              icon: const Icon(Icons.palette, color: Colors.purple),
              onPressed: _showBackgroundColorPicker,
              tooltip: 'Background Color',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
              onPressed: _exportAsPdf,
              tooltip: 'Export as PDF',
            ),
            IconButton(
              icon: const Icon(Icons.slideshow, color: Colors.orange),
              onPressed: _exportAsPptx,
              tooltip: 'Export as PPTX',
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
          _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: _buildContentPage(),
                    ),
                    _buildBottomNavigation(),
                  ],
                ),
                if (_isDrawingMode && _isToolbarVisible)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 120,
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
                              CircularProgressIndicator(
                                strokeWidth: 3,
                                value: _loadingProgress > 0 ? _loadingProgress : null,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _loadingMessage,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _loadingProgress > 0
                                    ? '${(_loadingProgress * 100).toStringAsFixed(0)}%'
                                    : 'This may take a moment',
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
    final isBlankSlide = page.contentPath == null || page.contentPath!.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          panEnabled: !_isDrawingMode,
          scaleEnabled: !_isDrawingMode,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildPageContent(page),
                ),
              ),
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
      },
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
      case PageContentType.image:
        if (page.contentPath == null || page.contentPath!.isEmpty) {
          final bgColor = page.backgroundColor ?? Colors.white;

          if (page.strokes.isNotEmpty || _isDrawingMode) {
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gesture,
                      size: 64,
                      color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade300 : Colors.white.withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Blank Slide',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Click "Annotate" to start drawing',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Center(
          child: Container(
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
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text('Failed to load image'),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      case PageContentType.placeholder:
      default:
        final bgColor = page.backgroundColor ?? Colors.white;

        if (page.strokes.isNotEmpty || _isDrawingMode) {
          return Center(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
          );
        }
        return Center(
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gesture,
                    size: 64,
                    color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade300 : Colors.white.withOpacity(0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Blank Slide',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click "Annotate" to start drawing',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: bgColor.computeLuminance() > 0.5 ? Colors.grey.shade400 : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
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
      _darkOverlayOpacity = 0.0;
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
        _darkOverlayOpacity = 0.0;
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

        _pages = List.from(_pages);
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
        _pages = List.from(_pages);
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
        _pages = List.from(_pages);
      });
    }
  }

  void _clearStrokes() {
    setState(() {
      _undoHistory.add(List.from(_pages[_currentPageIndex].strokes));
      _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(strokes: []);
      _pages = List.from(_pages);
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
                Spacer(),
                GestureDetector(
                  onTap: _addNewSlide,
                  child: Icon(
                    Icons.add_circle,
                    size: 18,
                    color: Colors.indigo,
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

  void _addNewSlide() {
    setState(() {
      _pages.add(
        PresentationPage(
          pageNumber: _pages.length + 1,
          title: 'Blank Slide ${_pages.length + 1}',
          subtitle: 'Start writing or annotate',
          icon: Icons.note_add,
          contentType: PageContentType.image,
          contentPath: null,
          backgroundColor: Colors.white,
        ),
      );
    });
    _showSnackBar('New slide added', Colors.indigo, Icons.add_circle);
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
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showBackgroundColorPicker() {
    final currentPage = _pages[_currentPageIndex];
    final isBlankSlide = currentPage.contentPath == null || currentPage.contentPath!.isEmpty;

    if (!isBlankSlide) {
      _showSnackBar('Background color only for blank slides', Colors.grey, Icons.info);
      return;
    }

    Color selectedColor = currentPage.backgroundColor ?? Colors.white;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Choose Background Color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: selectedColor,
                  onColorChanged: (color) {
                    selectedColor = color;
                  },
                  showLabel: true,
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: [
                    ColorLabelType.rgb,
                    ColorLabelType.hex,
                    ColorLabelType.hsv,
                  ],
                  pickerAreaBorderRadius: BorderRadius.circular(8),
                ),
                SizedBox(height: 20),
                Text(
                  'Quick Colors',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildQuickColor(Colors.white, 'White', dialogContext),
                    _buildQuickColor(Colors.black, 'Black', dialogContext),
                    _buildQuickColor(Color(0xFFFEEBEB), 'Light Red', dialogContext),
                    _buildQuickColor(Color(0xFFE8F5E9), 'Light Green', dialogContext),
                    _buildQuickColor(Color(0xFFE3F2FD), 'Light Blue', dialogContext),
                    _buildQuickColor(Color(0xFFFFFDE7), 'Light Yellow', dialogContext),
                    _buildQuickColor(Color(0xFFFFF3E0), 'Light Orange', dialogContext),
                    _buildQuickColor(Color(0xFFF3E5F5), 'Light Purple', dialogContext),
                    _buildQuickColor(Color(0xFFF5F5F5), 'Light Grey', dialogContext),
                    _buildQuickColor(Color(0xFFE0F2F1), 'Light Teal', dialogContext),
                    _buildQuickColor(Color(0xFFFCE4EC), 'Light Pink', dialogContext),
                    _buildQuickColor(Color(0xFFE8EAF6), 'Light Indigo', dialogContext),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final updatedPage = _pages[_currentPageIndex].copyWith(
                    backgroundColor: selectedColor,
                  );
                  _pages[_currentPageIndex] = updatedPage;
                  _pages = List.from(_pages);
                });
                Navigator.pop(dialogContext);
                _showSnackBar('Background color changed', Colors.green, Icons.check_circle);
              },
              child: Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickColor(Color color, String label, BuildContext dialogContext) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(dialogContext);
        setState(() {
          final updatedPage = _pages[_currentPageIndex].copyWith(
            backgroundColor: color,
          );
          _pages[_currentPageIndex] = updatedPage;
          _pages = List.from(_pages);
        });
        _showSnackBar('Background color changed', Colors.green, Icons.check_circle);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Exporting as PDF...';
    });

    try {
      final filePath = await ExportService.exportAsPdf(
        _pages,
        'Presentation_Export',
      );

      if (filePath != null) {
        _showSnackBar(
          'PDF exported',
          Colors.green,
          Icons.check_circle,
        );
        _showNewPresentationDialog();
      } else {
        _showSnackBar(
          'Failed to export PDF',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      print('Error exporting PDF: $e');
      _showSnackBar(
        'Error: $e',
        Colors.red,
        Icons.error,
      );
    } finally {
      setState(() {
        _isLoadingDocument = false;
        _loadingProgress = 0.0;
      });
    }
  }

  Future<void> _exportAsPptx() async {
    setState(() {
      _isLoadingDocument = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Exporting as PPTX...';
    });

    try {
      final filePath = await ExportService.exportAsPptx(
        _pages,
        'Presentation_Export',
      );

      if (filePath != null) {
        _showSnackBar(
          'PPTX exported',
          Colors.green,
          Icons.check_circle,
        );
        _showNewPresentationDialog();
      } else {
        _showSnackBar(
          'Failed to export PPTX',
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      print('Error exporting PPTX: $e');
      _showSnackBar(
        'Error: $e',
        Colors.red,
        Icons.error,
      );
    } finally {
      setState(() {
        _isLoadingDocument = false;
        _loadingProgress = 0.0;
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'pptx'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final List<String> paths = result.files.map((f) => f.path!).toList();

      final String? pdfPath = paths.any((p) => p.toLowerCase().endsWith('.pdf'))
          ? paths.firstWhere((p) => p.toLowerCase().endsWith('.pdf')) : null;
      final String? pptxPath = paths.any((p) => p.toLowerCase().endsWith('.pptx'))
          ? paths.firstWhere((p) => p.toLowerCase().endsWith('.pptx')) : null;

      setState(() {
        _isLoadingDocument = true;
        _loadingProgress = 0.0;
        _loadingMessage = 'Processing Document...';
      });

      try {
        if (pdfPath != null) {
          await _loadPdf(pdfPath);
        } else if (pptxPath != null) {
          await _loadPptx(pptxPath);
        } else {
          await _loadImages(paths);
        }
      } catch (e) {
        _showSnackBar('Error loading document: $e', Colors.red, Icons.error);
      } finally {
        setState(() {
          _isLoadingDocument = false;
          _loadingProgress = 0.0;
        });
      }
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _loadingMessage = 'Loading PDF...';
      _loadingProgress = 0.1;
    });

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
      _loadingProgress = 1.0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    _showSnackBar('PDF loaded: ${document.pages.length} pages', Colors.green, Icons.check_circle);
  }

  Future<void> _loadImages(List<String> paths) async {
    setState(() {
      _loadingMessage = 'Loading Images...';
      _loadingProgress = 0.5;
    });

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
      _pptxAspectRatio = 1.5;
      _currentPageIndex = 0;
      _undoHistory.clear();
      _redoHistory.clear();
      _loadingProgress = 1.0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    _showSnackBar('Images loaded: ${paths.length}', Colors.green, Icons.image);
  }

  Future<void> _loadPptx(String path) async {
    setState(() {
      _loadingMessage = 'Loading PPTX...';
      _loadingProgress = 0.1;
    });

    try {
      final imagePaths = await PptxConverterLibreOffice.convertPptxToImages(
        path,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress;
              if (progress < 0.3) {
                _loadingMessage = 'Converting PPTX to PDF...';
              } else if (progress < 0.7) {
                _loadingMessage = 'Converting to images...';
              } else {
                _loadingMessage = 'Finalizing...';
              }
            });
          }
        },
      );

      final List<PresentationPage> newPages = [];

      for (int i = 0; i < imagePaths.length; i++) {
        newPages.add(PresentationPage(
          pageNumber: i + 1,
          title: 'Slide ${i + 1}',
          subtitle: 'From: ${path.split(Platform.pathSeparator).last}',
          icon: Icons.slideshow,
          contentType: PageContentType.image,
          contentPath: imagePaths[i],
        ));
      }

      setState(() {
        _pages = newPages;
        _currentPageIndex = 0;
        _undoHistory.clear();
        _redoHistory.clear();
        _loadingProgress = 1.0;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      _showSnackBar(
        'PPTX loaded: ${newPages.length} slides',
        Colors.orange,
        Icons.slideshow,
      );
    } catch (e) {
      print('Error loading PPTX: $e');
      setState(() {
        _loadingProgress = 1.0;
      });
      _showSnackBar(
        'Error: $e',
        Colors.red,
        Icons.error,
      );
    }
  }
}