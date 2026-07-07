import 'package:flutter/material.dart';

class BoardTheme {
  final String name;
  final Color lightSquare;
  final Color darkSquare;
  final Color selectedSquare;
  final Color lastMoveLight;
  final Color lastMoveDark;

  const BoardTheme({
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
    required this.selectedSquare,
    required this.lastMoveLight,
    required this.lastMoveDark,
  });

  static const classicGreen = BoardTheme(
    name: 'Classic Green',
    lightSquare: Color(0xFFEEEED2),
    darkSquare: Color(0xFF769656),
    selectedSquare: Color(0xFFF6F669),
    lastMoveLight: Color(0xFFF6F6A0),
    lastMoveDark: Color(0xFFBACA44),
  );

  static const brownWood = BoardTheme(
    name: 'Brown Wood',
    lightSquare: Color(0xFFF0D9B5),
    darkSquare: Color(0xFFB58863),
    selectedSquare: Color(0xFFF7EC74),
    lastMoveLight: Color(0xFFF6E58D),
    lastMoveDark: Color(0xFFCDA45D),
  );

  static const blueOcean = BoardTheme(
    name: 'Blue Ocean',
    lightSquare: Color(0xFFDEE9F0),
    darkSquare: Color(0xFF6C93BF),
    selectedSquare: Color(0xFFF7EF8A),
    lastMoveLight: Color(0xFFC9E4F5),
    lastMoveDark: Color(0xFF8FB8DB),
  );

  static const grayCoral = BoardTheme(
    name: 'Gray Coral',
    lightSquare: Color(0xFFE8E8E8),
    darkSquare: Color(0xFF9E9E9E),
    selectedSquare: Color(0xFFFF8A65),
    lastMoveLight: Color(0xFFFFCCBC),
    lastMoveDark: Color(0xFFBFBFBF),
  );

  static const List<BoardTheme> all = [
    classicGreen,
    brownWood,
    blueOcean,
    grayCoral,
  ];
}