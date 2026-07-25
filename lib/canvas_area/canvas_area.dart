import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'models/fruit.dart';
import 'models/fruit_part.dart';
import 'models/touch_slice.dart';
import 'slice_painter.dart';

class CanvasArea extends StatefulWidget {
  const CanvasArea({super.key});

  @override
  State<StatefulWidget> createState() {
    return _CanvasAreaState();
  }
}

class _CanvasAreaState extends State<CanvasArea> {
  int _score = 0;
  bool _isPaused = false;
  TouchSlice? _touchSlice;
  final List<Fruit> _fruits = <Fruit>[];
  final List<FruitPart> _fruitParts = <FruitPart>[];
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    _spawnRandomFruit();
    _tick();
    super.initState();
  }

  Future<void> _playSliceSound() async {
    try {
      await _audioPlayer.play(AssetSource('slice.wav'));
    } catch (e) {
      debugPrint('Error playing slice sound: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _spawnRandomFruit() {
    _fruits.add(
      Fruit(
        position: Offset(0, 200),
        width: 80,
        height: 80,
        additionalForce: Offset(
          5 + Random().nextDouble() * 5,
          Random().nextDouble() * -10,
        ),
        rotation: Random().nextDouble() / 3 - 0.16,
      ),
    );
  }

  void _tick() {
    if (!mounted) {
      return;
    }

    if (!_isPaused) {
      setState(() {
        for (Fruit fruit in _fruits) {
          fruit.applyGravity();
        }
        for (FruitPart fruitPart in _fruitParts) {
          fruitPart.applyGravity();
        }

        if (Random().nextDouble() > 0.97) {
          _spawnRandomFruit();
        }
      });
    }

    Future<void>.delayed(Duration(milliseconds: 30), _tick);
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _touchSlice = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: _getStack());
  }

  List<Widget> _getStack() {
    List<Widget> widgetsOnStack = <Widget>[];

    widgetsOnStack.add(_getBackground());
    widgetsOnStack.add(_getSlice());
    widgetsOnStack.addAll(_getFruitParts());
    widgetsOnStack.addAll(_getFruits());
    widgetsOnStack.add(_getGestureDetector());
    widgetsOnStack.add(
      Positioned(
        right: 16,
        top: 16,
        child: Text('Score: $_score', style: TextStyle(fontSize: 24)),
      ),
    );
    if (_isPaused) {
      widgetsOnStack.add(_getPauseOverlay());
    }
    widgetsOnStack.add(_getPauseButton());

    return widgetsOnStack;
  }

  Container _getBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          stops: <double>[0.2, 1.0],
          colors: <Color>[Color(0xffFFB75E), Color(0xffED8F03)],
        ),
      ),
    );
  }

  Widget _getSlice() {
    if (_touchSlice == null) {
      return Container();
    }

    return CustomPaint(
      size: Size.infinite,
      painter: SlicePainter(pointsList: _touchSlice!.pointsList),
    );
  }

  List<Widget> _getFruits() {
    List<Widget> list = <Widget>[];

    for (Fruit fruit in _fruits) {
      list.add(
        Positioned(
          top: fruit.position.dy,
          left: fruit.position.dx,
          child: Transform.rotate(
            angle: fruit.rotation * pi * 2,
            child: _getMelon(fruit),
          ),
        ),
      );
    }

    return list;
  }

  List<Widget> _getFruitParts() {
    List<Widget> list = <Widget>[];

    for (FruitPart fruitPart in _fruitParts) {
      list.add(
        Positioned(
          top: fruitPart.position.dy,
          left: fruitPart.position.dx,
          child: _getMelonCut(fruitPart),
        ),
      );
    }

    return list;
  }

  Widget _getMelonCut(FruitPart fruitPart) {
    return Transform.rotate(
      angle: fruitPart.rotation * pi * 2,
      child: Image.asset(
        fruitPart.isLeft
            ? 'assets/melon_cut.png'
            : 'assets/melon_cut_right.png',
        height: 80,
        fit: BoxFit.fitHeight,
      ),
    );
  }

  Widget _getMelon(Fruit fruit) {
    return Image.asset(
      'assets/melon_uncut.png',
      height: 80,
      fit: BoxFit.fitHeight,
    );
  }

  Widget _getPauseButton() {
    return Positioned(
      left: 8,
      top: 8,
      child: IconButton(
        icon: Icon(
          _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          color: Colors.white,
          size: 32,
        ),
        onPressed: _togglePause,
      ),
    );
  }

  Widget _getPauseOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Paused',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _togglePause,
                child: Text('Resume'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getGestureDetector() {
    return IgnorePointer(
      ignoring: _isPaused,
      child: GestureDetector(
        onScaleStart: (ScaleStartDetails details) {
          setState(() => _setNewSlice(details));
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          setState(() {
            _addPointToSlice(details);
            _checkCollision();
          });
        },
        onScaleEnd: (ScaleEndDetails details) {
          setState(() => _resetSlice());
        },
      ),
    );
  }

  void _checkCollision() {
    if (_touchSlice == null) {
      return;
    }

    for (Fruit fruit in List<Fruit>.from(_fruits)) {
      bool firstPointOutside = false;
      bool secondPointInside = false;

      for (Offset point in _touchSlice!.pointsList) {
        if (!firstPointOutside && !fruit.isPointInside(point)) {
          firstPointOutside = true;
          continue;
        }

        if (firstPointOutside && fruit.isPointInside(point)) {
          secondPointInside = true;
          continue;
        }

        if (secondPointInside && !fruit.isPointInside(point)) {
          _fruits.remove(fruit);
          _turnFruitIntoParts(fruit);
          _score += 10;
          break;
        }
      }
    }
  }

  void _turnFruitIntoParts(Fruit hit) {
    _playSliceSound();

    FruitPart leftFruitPart = FruitPart(
      position: Offset(hit.position.dx - hit.width / 8, hit.position.dy),
      width: hit.width / 2,
      height: hit.height,
      isLeft: true,
      gravitySpeed: hit.gravitySpeed,
      additionalForce: Offset(
        hit.additionalForce.dx - 1,
        hit.additionalForce.dy - 5,
      ),
      rotation: hit.rotation,
    );

    FruitPart rightFruitPart = FruitPart(
      position: Offset(
        hit.position.dx + hit.width / 4 + hit.width / 8,
        hit.position.dy,
      ),
      width: hit.width / 2,
      height: hit.height,
      isLeft: false,
      gravitySpeed: hit.gravitySpeed,
      additionalForce: Offset(
        hit.additionalForce.dx + 1,
        hit.additionalForce.dy - 5,
      ),
      rotation: hit.rotation,
    );

    setState(() {
      _fruitParts.add(leftFruitPart);
      _fruitParts.add(rightFruitPart);
      _fruits.remove(hit);
    });
  }

  void _resetSlice() {
    _touchSlice = null;
  }

  void _setNewSlice(dynamic details) {
    _touchSlice = TouchSlice(pointsList: <Offset>[details.localFocalPoint]);
  }

  void _addPointToSlice(ScaleUpdateDetails details) {
    if (_touchSlice?.pointsList == null || _touchSlice!.pointsList.isEmpty) {
      return;
    }

    if (_touchSlice!.pointsList.length > 16) {
      _touchSlice!.pointsList.removeAt(0);
    }
    _touchSlice!.pointsList.add(details.localFocalPoint);
  }
}
