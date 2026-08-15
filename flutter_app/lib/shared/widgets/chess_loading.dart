import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A row of chess pieces that hop in sequence, like a knight bouncing
/// across the board - used anywhere the app would otherwise show a
/// plain spinner. Pure Unicode glyphs, no image assets required.
class ChessLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const ChessLoadingIndicator({
    super.key,
    this.size = 32,
    this.color = const Color(0xFF1E2142),
  });

  @override
  State<ChessLoadingIndicator> createState() => _ChessLoadingIndicatorState();
}

class _ChessLoadingIndicatorState extends State<ChessLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _pieces = ['♞', '♝', '♜', '♛']; // knight, bishop, rook, queen

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_pieces.length, (i) {
            // Each piece's hop is offset from the others so they move
            // as a wave rather than all bouncing in unison.
            final t = (_controller.value + (i / _pieces.length)) % 1.0;
            final hop = -widget.size * 0.45 * math.sin(t * math.pi);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.12),
              child: Transform.translate(
                offset: Offset(0, hop),
                child: Text(
                  _pieces[i],
                  style: TextStyle(fontSize: widget.size, color: widget.color),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Drop-in replacement for `Center(child: CircularProgressIndicator())`.
class ChessLoadingScreen extends StatelessWidget {
  final String? message;
  const ChessLoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ChessLoadingIndicator(size: 36),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}
