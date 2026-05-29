import 'package:flutter/widgets.dart';

class SharedMapState {
  // Retains the virtual canvas zoom and pan tracking across the entire app session.
  // Both the live map and the editor will share this exact matrix.
  static final TransformationController viewerController = TransformationController();
}
