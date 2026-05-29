import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UniversalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final WidgetBuilder? placeholder;

  const UniversalImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return errorBuilder?.call(context, Exception('Empty path'), null) ?? const SizedBox.shrink();
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder != null ? (context, url) => placeholder!(context) : null,
        errorWidget: (context, url, error) => errorBuilder?.call(context, error, null) ?? const SizedBox.shrink(),
      );
    }

    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }

    return errorBuilder?.call(context, Exception('File not found'), null) ?? const SizedBox.shrink();
  }
}
