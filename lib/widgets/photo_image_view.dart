import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sheet_config.dart';

class PhotoImageView extends StatelessWidget {
  const PhotoImageView({required this.photo, super.key});

  final SlotPhoto photo;

  @override
  Widget build(BuildContext context) {
    final image = photo.image;
    if (image == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(photo.offsetX * width, photo.offsetY * height),
            child: Transform.scale(
              scale: photo.scale,
              child: Transform.rotate(
                angle: photo.quarterTurns * math.pi / 2,
                child: Image.file(
                  File(image.path),
                  width: width,
                  height: height,
                  fit: photo.fit == PhotoFit.cover
                      ? BoxFit.cover
                      : BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
