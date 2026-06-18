import 'package:flutter/material.dart';

class ClosphereColors {
  // THE TOTAL SWAP
  static const Color black = Color(0xFFFFFFFF); // Background is now White
  static const Color white = Color(0xFF000000); // Elements are now Black
  static const Color grey = Color(0xFFF5F5F5); // Light grey for inputs
}

class ClosphereText {
  static const TextStyle logoStyle = TextStyle(
    color: ClosphereColors.white, // Now Black
    fontSize: 55,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -3,
  );

  static const TextStyle sloganStyle = TextStyle(
    color: Color(0xFF888888), // Subtle dark grey
    fontSize: 10,
    letterSpacing: 4,
    fontWeight: FontWeight.w300,
  );
}