import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // App title
  static const TextStyle appTitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Section headers
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Prices
  static const TextStyle price = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Buttons
  static const TextStyle button = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Body text
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Helper text
  static const TextStyle helper = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle shoppingItem(bool checked) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 15.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    decoration: checked ? TextDecoration.lineThrough : null,
    color: checked ? Colors.black38 : Colors.black87,
  );

}
