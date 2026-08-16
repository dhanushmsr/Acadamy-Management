import 'package:flutter/material.dart';

/// Formats any 24-hour time string ("18:30" or "09:00") into Indian 12-Hour AM/PM format ("6:30 PM", "9:00 AM").
String format12HourAMPM(String? timeStr) {
  if (timeStr == null || timeStr.trim().isEmpty) return '';
  final str = timeStr.trim();
  try {
    if (str.toUpperCase().contains('AM') || str.toUpperCase().contains('PM')) {
      return str;
    }
    final parts = str.split(':');
    if (parts.length >= 2) {
      int hr = int.parse(parts[0]);
      final min = int.parse(parts[1]);
      final period = hr >= 12 ? 'PM' : 'AM';
      hr = hr % 12;
      if (hr == 0) hr = 12;
      final minStr = min.toString().padLeft(2, '0');
      return '$hr:$minStr $period';
    }
  } catch (_) {}
  return str;
}

/// Formats a [TimeOfDay] into 12-Hour AM/PM format (e.g. "6:30 PM").
String formatTimeOfDay12Hour(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
