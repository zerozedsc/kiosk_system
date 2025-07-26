import 'package:flutter/material.dart';

/// Responsive layout utility for CashierPage
class ResponsiveLayout {
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  /// Check if the current device is mobile sized
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if the current device is tablet sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if the current device is desktop sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaler = MediaQuery.textScalerOf(context);

    double scaleFactor;
    if (screenWidth < mobileBreakpoint) {
      scaleFactor = 0.8; // More aggressive scaling for mobile
    } else if (screenWidth < tabletBreakpoint) {
      scaleFactor = 0.9; // Moderate scaling for tablet
    } else {
      scaleFactor = 1.0; // Normal size for desktop
    }

    return textScaler.scale(baseSize * scaleFactor);
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    double mobile = 8.0,
    double tablet = 12.0,
    double desktop = 16.0,
  }) {
    if (isMobile(context)) {
      return EdgeInsets.all(mobile);
    } else if (isTablet(context)) {
      return EdgeInsets.all(tablet);
    } else {
      return EdgeInsets.all(desktop);
    }
  }

  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isMobile(context)) {
      return screenWidth * 0.95; // Almost full width on mobile
    } else if (isTablet(context)) {
      return screenWidth * 0.7;
    } else {
      return screenWidth * 0.5; // Smaller on desktop
    }
  }

  /// Get responsive dialog constraints
  static BoxConstraints getDialogConstraints(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return BoxConstraints(
      maxWidth: getDialogWidth(context),
      maxHeight: screenSize.height * 0.9,
    );
  }
}
