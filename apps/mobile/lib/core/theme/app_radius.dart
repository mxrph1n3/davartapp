import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double card = 18;
  static const double button = 18;
  static const double input = 18;
  static const double image = 20;
  static const double sheet = 24;
  static const double pill = 999;

  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const buttonRadius = BorderRadius.all(Radius.circular(button));
  static const inputRadius = BorderRadius.all(Radius.circular(input));
  static const imageRadius = BorderRadius.all(Radius.circular(image));
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(sheet));
  static const pillRadius = BorderRadius.all(Radius.circular(pill));

  // Legacy aliases
  static const borderMd = buttonRadius;
  static const borderSm = BorderRadius.all(Radius.circular(8));
  static const borderPill = pillRadius;
  static const borderLg = cardRadius;
}
