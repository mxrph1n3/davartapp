import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 30,
      offset: Offset(0, 8),
    ),
  ];

  static const floating = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const subtle = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
