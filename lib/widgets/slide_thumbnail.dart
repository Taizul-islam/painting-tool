import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/drawing_stroke.dart';

class SlideThumbnail extends StatelessWidget {
  final PresentationPage page;
  final bool isSelected;
  final VoidCallback onTap;

  const SlideThumbnail({
    Key? key,
    required this.page,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${page.pageNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.indigo : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: _buildThumbnailPreview(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    switch (page.contentType) {
      case PageContentType.image:
        return Container(
          color: Colors.grey.shade100,
          child: Image.file(
            File(page.contentPath!),
            fit: BoxFit.contain,
            cacheHeight: 300,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.red.shade300, size: 24),
                    const SizedBox(height: 4),
                    const Text(
                      'Load Error',
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      case PageContentType.pdf:
        return PdfDocumentViewBuilder.file(
          page.contentPath!,
          loadingBuilder: (context) => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          builder: (context, document) {
            if (document == null) {
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return PdfPageView(
              document: document,
              pageNumber: (page.pdfPageIndex ?? 0) + 1,
              maximumDpi: 100,
            );
          },
        );
      case PageContentType.placeholder:
      default:
        return Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Icon(
              page.icon,
              size: 24,
              color: Colors.indigo.shade200,
            ),
          ),
        );
    }
  }
}