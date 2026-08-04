import 'dart:ui';
import 'gravitational_object.dart';

enum FruitType {
  melon,
  banana,
  durian;

  String get uncutImagePath {
    switch (this) {
      case FruitType.melon:
        return 'assets/melon_uncut.png';
      case FruitType.banana:
        return 'assets/banana_uncut.png';
      case FruitType.durian:
        return 'assets/durian_uncut.png';
    }
  }

  (String, String) get cutImagePaths {
    switch (this) {
      case FruitType.melon:
        return ('assets/melon_cut.png', 'assets/melon_cut_right.png');
      case FruitType.banana:
        return ('assets/banana_cut_left.png', 'assets/banana_cut_right.png');
      case FruitType.durian:
        return ('assets/durian_cut_left.png', 'assets/durian_cut_right.png');
    }
  }
}

class Fruit extends GravitationalObject {
  Fruit({
    required this.type,
    required this.width,
    required this.height,
    required super.position,
    super.gravitySpeed = 0.0,
    super.additionalForce = const Offset(0, 0),
    super.rotation = 0.25,
  });

  final FruitType type;
  final double width;
  final double height;

  String get imagePath => type.uncutImagePath;
  (String, String) get cutImagePaths => type.cutImagePaths;

  bool isPointInside(Offset point) {
    if (point.dx < position.dx || point.dx > position.dx + width) return false;
    if (point.dy < position.dy || point.dy > position.dy + height) return false;
    return true;
  }
}
