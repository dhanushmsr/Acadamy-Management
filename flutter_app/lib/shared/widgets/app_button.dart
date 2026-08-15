import 'package:flutter/material.dart';

/// Rounded gradient CTA button matching the visual style of the original
/// academy app (dark navy, fully rounded, gradient fill).
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2E5C), Color(0xFF15172E)],
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }
}
