import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 250);
  static const normal = Duration(milliseconds: 300);
  static const curve = Curves.easeOut;
}
