import 'package:flutter/material.dart';

/// Temporary stand-in for screens not built out yet.
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$title screen goes here', style: const TextStyle(fontSize: 16)),
    );
  }
}
