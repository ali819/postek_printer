import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:postek_printer/core/colors.dart' show AppColors;

enum DialogType { question, delete }

class CustomDialog {
  static void show(
    BuildContext context, {
    required String title,
    required DialogType type,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dialog',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            FocusScope.of(context).unfocus();
                          },
                          child: const Text(
                            "Batal",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            FocusScope.of(context).unfocus();
                            onConfirm();
                          },
                          child: const Text(
                            "Ya, Lanjutkan",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }
}
