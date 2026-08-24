import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PptxConverterLibreOffice {
  static final Map<String, List<String>> _memoryCache = {};
  static final Map<String, Future<List<String>>?> _loadingFutures = {};

  static Future<List<String>> convertPptxToImages(
      String pptxPath, {
        void Function(double progress)? onProgress,
        bool forceRefresh = false,
      }) async {
    final tempDir = Directory.systemTemp;
    final outputDir = Directory('${tempDir.path}/pptx_cache');

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final fileHash = _generateHash(pptxPath);
    final slideDir = Directory('${outputDir.path}/$fileHash');

    onProgress?.call(0.1);

    // Check memory cache first
    if (!forceRefresh && _memoryCache.containsKey(fileHash)) {
      final cachedImages = _memoryCache[fileHash]!;
      if (cachedImages.length > 1) {
        print('⚡ Using memory cache: ${cachedImages.length} slides');
        onProgress?.call(1.0);
        return cachedImages;
      }
    }

    // Check if already loading
    if (_loadingFutures.containsKey(fileHash) && _loadingFutures[fileHash] != null) {
      print('⏳ Already loading, waiting...');
      return await _loadingFutures[fileHash]!;
    }

    // Check disk cache
    if (!forceRefresh && slideDir.existsSync()) {
      final images = slideDir.listSync()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.path)
          .toList()
        ..sort((a, b) => _extractNumber(a).compareTo(_extractNumber(b)));

      if (images.length > 1) {
        print('💾 Using disk cache: ${images.length} slides');
        _memoryCache[fileHash] = images;
        onProgress?.call(1.0);
        return images;
      }
    }

    // Start conversion
    final future = _performConversion(
      pptxPath,
      slideDir,
      fileHash,
      onProgress,
    );

    _loadingFutures[fileHash] = future;

    try {
      final result = await future;
      _memoryCache[fileHash] = result;
      return result;
    } finally {
      _loadingFutures[fileHash] = null;
    }
  }

  static Future<List<String>> _performConversion(
      String pptxPath,
      Directory slideDir,
      String fileHash,
      void Function(double)? onProgress,
      ) async {
    // Clean old cache
    if (slideDir.existsSync()) {
      slideDir.deleteSync(recursive: true);
    }
    slideDir.createSync(recursive: true);

    onProgress?.call(0.2);

    // Find bundled tools
    final libreOfficePath = await _findLibreOffice();
    final pdftoppmPath = await _findPdfToPpm();

    if (libreOfficePath == null) {
      throw Exception('LibreOffice not found. Please reinstall the application.');
    }

    if (pdftoppmPath == null) {
      throw Exception('Poppler not found. Please reinstall the application.');
    }

    print('🔄 Converting PPTX...');
    print('LibreOffice: $libreOfficePath');
    print('pdftoppm: $pdftoppmPath');

    // Step 1: Convert PPTX to PDF
    final pdfPath = await _convertPptxToPdf(
      pptxPath,
      slideDir,
      libreOfficePath,
      onProgress,
    );

    if (pdfPath == null) {
      throw Exception('Failed to convert PPTX to PDF');
    }

    onProgress?.call(0.5);

    // Step 2: Convert PDF to PNG using bundled pdftoppm
    final images = await _convertPdfToImagesWithPoppler(
      pdfPath,
      slideDir,
      pdftoppmPath,
      onProgress,
    );

    // Clean up PDF
    final pdfFile = File(pdfPath);
    if (pdfFile.existsSync()) {
      pdfFile.deleteSync();
    }

    onProgress?.call(1.0);

    print('✅ Total slides converted: ${images.length}');

    return images;
  }

  static String _generateHash(String path) {
    final bytes = utf8.encode(path);
    int hash = 0;
    for (int byte in bytes) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & hash;
    }
    return hash.abs().toRadixString(16);
  }

  static int _extractNumber(String path) {
    final match = RegExp(r'(\d+)\.png$', caseSensitive: false).firstMatch(path);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  static Future<String?> _convertPptxToPdf(
      String pptxPath,
      Directory outputDir,
      String libreOfficePath,
      void Function(double)? onProgress,
      ) async {
    onProgress?.call(0.3);

    print('📄 Converting PPTX to PDF...');

    final process = await Process.start(
      libreOfficePath,
      [
        '--headless',
        '--convert-to', 'pdf',
        '--outdir', outputDir.path,
        pptxPath,
      ],
    );

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception('PPTX to PDF conversion failed');
    }

    onProgress?.call(0.4);

    await Future.delayed(Duration(seconds: 2));

    final pdfFiles = outputDir.listSync()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();

    if (pdfFiles.isEmpty) {
      throw Exception('No PDF file generated');
    }

    return pdfFiles.first.path;
  }

  static Future<List<String>> _convertPdfToImagesWithPoppler(
      String pdfPath,
      Directory outputDir,
      String pdftoppmPath,
      void Function(double)? onProgress,
      ) async {
    try {
      print('🖼️ Converting PDF to PNG...');
      print('Using pdftoppm: $pdftoppmPath');

      final prefix = '${outputDir.path}/slide';

      final process = await Process.start(
        pdftoppmPath,
        [
          '-png',
          '-r', '150',
          pdfPath,
          prefix,
        ],
      );

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw Exception('pdftoppm conversion failed');
      }

      onProgress?.call(0.7);

      await Future.delayed(Duration(seconds: 1));

      final pngFiles = outputDir.listSync()
          .where((f) => f.path.endsWith('.png') && f.path.contains('slide'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      if (pngFiles.isEmpty) {
        throw Exception('No PNG files generated');
      }

      final images = <String>[];
      for (int i = 0; i < pngFiles.length; i++) {
        final newPath = '${outputDir.path}/slide_${i + 1}.png';

        if (pngFiles[i].path != newPath) {
          File(pngFiles[i].path).renameSync(newPath);
        }

        images.add(newPath);
      }

      onProgress?.call(0.9);

      return images;
    } catch (e) {
      print('PDF to image conversion failed: $e');
      throw Exception('Failed to convert PDF to images: $e');
    }
  }

  static Future<String?> _findLibreOffice() async {
    // Check bundled location first (relative to executable)
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;

    print('Executable directory: $executableDir');

    final bundledPaths = [
      // Windows: tools directory next to exe
      '${executableDir.path}/tools/libreoffice/program/soffice.exe',
      '${executableDir.path}/tools/LibreOffice/program/soffice.exe',
      // macOS development paths
      '/opt/homebrew/bin/soffice',
      '/Applications/LibreOffice.app/Contents/MacOS/soffice',
      '/usr/local/bin/soffice',
      '/usr/bin/soffice',
    ];

    for (final path in bundledPaths) {
      if (File(path).existsSync()) {
        print('✅ Found LibreOffice at: $path');
        return path;
      }
    }

    // Search recursively in tools directory for Windows
    try {
      final toolsDir = Directory('${executableDir.path}/tools');
      if (toolsDir.existsSync()) {
        final files = toolsDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.endsWith('soffice.exe')) {
            print('✅ Found LibreOffice recursively at: ${file.path}');
            return file.path;
          }
        }
      }
    } catch (e) {
      print('Error searching for LibreOffice: $e');
    }

    // Try which command
    try {
      final result = await Process.run('which', ['soffice']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        print('✅ Found soffice via which: $path');
        return path;
      }
    } catch (e) {
      // Continue
    }

    print('⚠️ LibreOffice not found');
    return null;
  }

  static Future<String?> _findPdfToPpm() async {
    // Check bundled location first
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent;

    print('Searching for pdftoppm in: ${executableDir.path}');

    // Known paths from GitHub Actions build
    final knownPaths = [
      '${executableDir.path}/tools/poppler/pdftoppm.exe',
      '${executableDir.path}/tools/poppler/bin/pdftoppm.exe',
      '${executableDir.path}/tools/poppler/Library/bin/pdftoppm.exe',
    ];

    for (final path in knownPaths) {
      if (File(path).existsSync()) {
        print('✅ Found pdftoppm at: $path');
        return path;
      }
    }

    // Search recursively in tools directory
    try {
      final toolsDir = Directory('${executableDir.path}/tools');
      if (toolsDir.existsSync()) {
        print('Searching recursively in tools directory...');
        final files = toolsDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('pdftoppm.exe')) {
            print('✅ Found pdftoppm recursively at: ${file.path}');
            return file.path;
          }
        }
      }
    } catch (e) {
      print('Error searching for pdftoppm: $e');
    }

    // Development paths (macOS/Linux)
    final devPaths = [
      '/opt/homebrew/bin/pdftoppm',
      '/usr/local/bin/pdftoppm',
      '/usr/bin/pdftoppm',
    ];

    for (final path in devPaths) {
      if (File(path).existsSync()) {
        print('✅ Found pdftoppm at: $path');
        return path;
      }
    }

    // Try system commands
    try {
      final result = await Process.run('which', ['pdftoppm']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        print('✅ Found pdftoppm via which: $path');
        return path;
      }
    } catch (e) {
      // Continue
    }

    if (Platform.isWindows) {
      try {
        final result = await Process.run('where', ['pdftoppm']);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim().split('\n').first;
          print('✅ Found pdftoppm via where: $path');
          return path;
        }
      } catch (e) {
        // Continue
      }
    }

    print('⚠️ pdftoppm not found');
    return null;
  }

  // Preload PPTX in background
  static Future<void> preloadPptx(String pptxPath) async {
    print('🔄 Preloading PPTX in background...');
    await convertPptxToImages(pptxPath);
    print('✅ PPTX preloaded');
  }

  // Clear all caches
  static void clearAllCaches() {
    _memoryCache.clear();
    _loadingFutures.clear();

    final tempDir = Directory.systemTemp;
    final cacheDir = Directory('${tempDir.path}/pptx_cache');
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }
}