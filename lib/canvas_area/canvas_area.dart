import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

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
  int _lives = 3;
  bool _isPaused = false;
  bool _isGameOver = false;
  TouchSlice? _touchSlice;
  final List<Fruit> _fruits = <Fruit>[];
  final List<FruitPart> _fruitParts = <FruitPart>[];

  // Track screen size safely
  Size _screenSize = Size.zero;

  @override
  void initState() {
    _spawnRandomFruit();
    _tick();
    super.initState();
  }

  Future<void> _playSliceSound() async {
    try {
      // Create a new lightweight player instance for each slice event
      final player = AudioPlayer();

      // Low latency mode is optimized for fast UI sound effects
      await player.setPlayerMode(PlayerMode.lowLatency);

      await player.play(AssetSource('slice.mp3'));

      // Dispose player automatically once the sound finishes playing
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Error playing slice sound: $e');
    }
  }

  Future<void> _vibrateOnSlice() async {
    try {
      // Check if the device has vibration hardware before attempting to vibrate
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(
          duration: 150,
        ); // Short 150ms pulse for slice feedback
      } else {
        debugPrint('No vibration.');
      }
    } catch (e) {
      debugPrint('Error triggering vibration: $e');
    }
  }

  Future<void> _playGameOverSound() async {
    try {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.play(AssetSource('game_over.mp3'));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Error playing game over sound: $e');
    }
  }

  Future<void> _vibrateOnGameOver() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      debugPrint('Error triggering game over vibration: $e');
    }
  }

  void _spawnRandomFruit() {
    // Randomly pick between melon, banana and durian
    final randomType =
        FruitType.values[Random().nextInt(FruitType.values.length)];

    _fruits.add(
      Fruit(
        type: randomType,
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

    if (!_isPaused && !_isGameOver) {
      setState(() {
        for (Fruit fruit in List<Fruit>.from(_fruits)) {
          fruit.applyGravity();
          _checkMissedFruit(fruit);
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

  void _checkMissedFruit(Fruit fruit) {
    // Check against cached screen height safely
    if (_screenSize.height > 0 && fruit.position.dy > _screenSize.height) {
      _fruits.remove(fruit);

      // ONLY decrease a life if the missed object is NOT a bomb
      if (!fruit.type.isBomb) {
        setState(() {
          _lives--;
          if (_lives <= 0) {
            _isGameOver = true;
            _playGameOverSound();
            _vibrateOnGameOver();
          }
        });
      }
    }
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _isGameOver = false;
      _fruits.clear();
      _fruitParts.clear();
      _isPaused = false;
    });
    _spawnRandomFruit();
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
    // Store screen size safely within build phase
    _screenSize = MediaQuery.sizeOf(context);

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
    widgetsOnStack.add(_getLivesDisplay());
    if (_isPaused) {
      widgetsOnStack.add(_getPauseOverlay());
    }
    if (_isGameOver) {
      widgetsOnStack.add(_getGameOverOverlay());
    }
    widgetsOnStack.add(_getPauseButton());

    return widgetsOnStack;
  }

  Widget _getLivesDisplay() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Row(
        children: List.generate(
          3,
          (index) => Icon(
            index < _lives ? Icons.favorite : Icons.heart_broken,
            color: Colors.red,
            size: 28,
          ),
        ),
      ),
    );
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
            child: _getFruitImage(fruit),
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
          child: _getFruitPartImage(fruitPart),
        ),
      );
    }

    return list;
  }

  Widget _getFruitPartImage(FruitPart fruitPart) {
    return Transform.rotate(
      angle: fruitPart.rotation * pi * 2,
      child: Image.asset(
        fruitPart.imagePath, // Dynamic image path based on FruitType and side
        height: 80,
        fit: BoxFit.fitHeight,
      ),
    );
  }

  Widget _getFruitImage(Fruit fruit) {
    return Image.asset(
      fruit.imagePath, // Dynamic image path based on FruitType
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
              ElevatedButton(onPressed: _togglePause, child: Text('Resume')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getGameOverOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Game Over',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Score: $_score',
                style: TextStyle(fontSize: 32, color: Colors.white),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _restartGame,
                child: Text('Play Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getGestureDetector() {
    return IgnorePointer(
      ignoring: _isPaused || _isGameOver,
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
          if (fruit.type.isBomb) {
            _handleBombSlice();
          } else {
            _turnFruitIntoParts(fruit);
            _score += 10;
          }
          break;
        }
      }
    }
  }

  void _handleBombSlice() {
    _playBombSound();
    _vibrateOnBomb();

    setState(() {
      _lives--;
      if (_lives <= 0) {
        _isGameOver = true;
        _playGameOverSound();
        _vibrateOnGameOver();
      }
    });
  }

  Future<void> _playBombSound() async {
    try {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.play(AssetSource('bomb.mp3'));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Error playing bomb sound: $e');
    }
  }

  Future<void> _vibrateOnBomb() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      debugPrint('Error triggering bomb vibration: $e');
    }
  }

  void _turnFruitIntoParts(Fruit hit) {
    _playSliceSound();
    _vibrateOnSlice();

    FruitPart leftFruitPart = FruitPart(
      type: hit.type,
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
      type: hit.type,
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
