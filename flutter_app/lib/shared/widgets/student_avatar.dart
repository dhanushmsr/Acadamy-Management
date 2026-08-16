import 'package:flutter/material.dart';
import '../../core/auth/api_client.dart';

/// Clean, executive vector avatar for Male (Blue) and Female (Pink) students.
class StudentAvatar extends StatelessWidget {
  final StudentSummary student;
  final double radius;

  const StudentAvatar({
    super.key,
    required this.student,
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final isFemale = student.isFemale;
    final bgColor = isFemale ? const Color(0xFFFDF2F8) : const Color(0xFFEFF6FF);
    final borderColor = isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB);
    final iconColor = isFemale ? const Color(0xFFBE185D) : const Color(0xFF1E40AF);
    final badgeBg = isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB);
    final badgeIcon = isFemale ? Icons.female_rounded : Icons.male_rounded;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isFemale ? Icons.face_3_rounded : Icons.person_rounded,
              size: radius * 1.2,
              color: iconColor,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(
              badgeIcon,
              size: radius * 0.4,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
