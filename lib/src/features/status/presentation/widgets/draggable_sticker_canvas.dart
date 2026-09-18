import 'package:flutter/material.dart';

class DraggableStickerCanvas extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final void Function(Offset position, double scale)? onTransformChanged;

  const DraggableStickerCanvas({
    Key? key,
    required this.child,
    required this.onTap,
    this.onTransformChanged,
  }) : super(key: key);

  @override
  State<DraggableStickerCanvas> createState() => _DraggableStickerCanvasState();
}

class _DraggableStickerCanvasState extends State<DraggableStickerCanvas> {
  Offset _position = const Offset(100, 200);
  double _scale = 1.0;
  
  // For zooming and panning
  double _baseScale = 1.0;
  Offset _basePosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onScaleStart: (details) {
              _baseScale = _scale;
              _basePosition = _position - details.focalPoint;
            },
            onScaleUpdate: (details) {
              setState(() {
                _scale = _baseScale * details.scale;
                _position = details.focalPoint + _basePosition;
              });
              widget.onTransformChanged?.call(_position, _scale);
            },
            onTap: widget.onTap,
            child: Transform.scale(
              scale: _scale,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
