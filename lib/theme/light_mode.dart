import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    // background: Colors.grey.shade300,
    background: Color.fromARGB(255, 239, 238, 243),
    primary: Color.fromARGB(255, 105, 108, 255),
    onPrimary: Colors.white,
    secondary: Color.fromARGB(255, 133, 146, 163),
    tertiary: Color.fromARGB(255, 113, 221, 55),
    error: Color.fromARGB(255, 255, 62, 29),
    inversePrimary: Color.fromARGB(255, 35, 52, 70),
  ),
  cardTheme:  CardThemeData(
    color: Color.fromARGB(255, 253, 253, 253),
    elevation: 0,
  ),
  dividerTheme: const DividerThemeData(color: Colors.transparent),
  drawerTheme: DrawerThemeData(backgroundColor: Colors.grey[200]),
  textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.grey[800],
        displayColor: Colors.black,
      ),
);
