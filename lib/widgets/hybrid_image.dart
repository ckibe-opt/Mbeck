import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class HybridImage extends StatefulWidget {
  final String? imagePath;
  final Widget? fallback;
  final BoxFit fit;

  /// A unified widget that transparently handles both local device files 
  /// and Supabase remote cached URLs.
  const HybridImage({
    super.key,
    required this.imagePath,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  State<HybridImage> createState() => _HybridImageState();
}

class _HybridImageState extends State<HybridImage> {
  File? _localFile;
  bool _isLoadingLocal = true;

  @override
  void initState() {
    super.initState();
    _resolveLocalFile();
  }

  @override
  void didUpdateWidget(HybridImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolveLocalFile();
    }
  }

  Future<void> _resolveLocalFile() async {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      if (mounted) setState(() => _isLoadingLocal = false);
      return;
    }

    if (widget.imagePath!.startsWith('http')) {
      // It's a Cloud URL, we don't need to resolve local disk
      if (mounted) setState(() => _isLoadingLocal = false);
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Use just the basename to prevent path breaking across devices via LAN
      final fullPath = p.join(appDir.path, p.basename(widget.imagePath!));
      final file = File(fullPath);
      
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _localFile = file;
            _isLoadingLocal = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingLocal = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      return widget.fallback ?? _defaultFallback();
    }

    if (widget.imagePath!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.imagePath!,
        fit: widget.fit,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => widget.fallback ?? _defaultFallback(),
      );
    }

    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => widget.fallback ?? _defaultFallback(),
      );
    }

    return widget.fallback ?? _defaultFallback();
  }

  Widget _defaultFallback() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}
