import 'package:flutter/material.dart';

class AppColors {
  // Primary Greens
  static const Color primary = Color(0xFF2E7D32); // Deep forest green
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent = Color(0xFF00E676); // Bright lime green for success/highlights
  static const Color secondary = Color(0xFF81C784); // Lighter green for UI highlights
  
  // Extended Palette — Premium accents
  static const Color teal = Color(0xFF00897B);
  static const Color amber = Color(0xFFFF8F00);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color indigo = Color(0xFF5C6BC0);
  static const Color purple = Color(0xFF7E57C2);
  static const Color mint = Color(0xFF26A69A);

  // Gradients
  static const List<Color> primaryGradient = [Color(0xFF43A047), Color(0xFF1B5E20)];
  static const List<Color> tealGradient = [Color(0xFF26A69A), Color(0xFF00695C)];
  static const List<Color> amberGradient = [Color(0xFFFFB300), Color(0xFFFF6F00)];
  static const List<Color> coralGradient = [Color(0xFFFF8A80), Color(0xFFE53935)];

  // Backgrounds
  static const Color background = Color(0xFFF5F9F6); // Very light mint/grey
  static const Color surface = Colors.white;
  static const Color cardLight = Color(0xFFE8F5E9); // Light green for cards

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Colors.white;

  // Status
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF1976D2);

  // Waste Category Colors — vibrant and distinctive
  static const Color organic = Color(0xFFFF9800);   // Vivid orange for organic waste
  static const Color plastic = Color(0xFF42A5F5);   // Bright blue for plastic
  static const Color paper = Color(0xFF8D6E63);     // Warm brown for paper
  static const Color metal = Color(0xFF78909C);     // Steel grey for metal
  static const Color glass = Color(0xFF66BB6A);     // Green for glass
  static const Color ewaste = Color(0xFFAB47BC);    // Purple for e-waste
  static const Color hazardous = Color(0xFFEF5350); // Red for hazardous
}
