import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to check if URL is an image
bool isImageUrl(String url) {
  final lowerUrl = url.toLowerCase();
  return lowerUrl.contains('.jpg') ||
      lowerUrl.contains('.jpeg') ||
      lowerUrl.contains('.png') ||
      lowerUrl.contains('.gif') ||
      lowerUrl.contains('.webp') ||
      lowerUrl.contains('.bmp');
}

// Widget to display a thumbnail with tap to view full screen
class AttachmentThumbnail extends StatelessWidget {
  final String url;
  final int index;

  const AttachmentThumbnail({
    super.key,
    required this.url,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = isImageUrl(url);
    final fileName = url.split('/').last.split('?').first;

    return GestureDetector(
      onTap: isImage
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FullScreenImageViewer(imageUrl: url, tag: 'image_$index'),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!, width: 1),
        ),
        child: isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Hero(
                      tag: 'image_$index',
                      child: Image.network(
                        url,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.blue[50],
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.blue[50],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to view',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
