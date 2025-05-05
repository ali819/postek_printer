import 'package:flutter/material.dart';
import 'package:postek_printer/core/colors.dart';

class AppSnackbar {
  // GlobalKey agar bisa diakses dari mana saja tanpa context
  static final GlobalKey<ScaffoldMessengerState> scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  static void show({
    required String message,
    required String type, // 'error' atau 'success'
  }) {
    Color backgroundColor =
        type == 'success' ? AppColors.primary : AppColors.red;

    scaffoldKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: 'Tutup',
            textColor: Colors.white,
            onPressed: () {
              scaffoldKey.currentState?.hideCurrentSnackBar();
            },
          ),
        ),
      );
  }

  static void hide() {
    scaffoldKey.currentState?.hideCurrentSnackBar();
  }
}
