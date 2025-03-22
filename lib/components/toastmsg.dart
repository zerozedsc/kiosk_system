export 'package:vibration/vibration.dart';

import '../configs/configs.dart';
import 'package:vibration/vibration.dart';




enum ToastLevel {
  info,
  success,
  warning,
  error,
  debug,
}

enum ToastPosition {
  top,
  bottom,
  center,
  topRight,
}

void showToastMessage(
  BuildContext context, 
  String message, 
  ToastLevel level, {
  ToastPosition position = ToastPosition.top,
}) {
  // Skip if context is not valid
  if (!context.mounted) return;
  
  // Get overlay safely
  final OverlayState? overlayState = Overlay.maybeOf(context);
  if (overlayState == null) return;
  
  final Color backgroundColor;
  final Color textColor = Colors.white;
  final IconData icon;
  
  // Set colors and icons based on message level
  switch (level) {
    case ToastLevel.info:
      backgroundColor = Colors.blue;
      icon = Icons.info;
      vibrateWithRhythm([
        (50, 0),  // Single gentle pulse
      ]);
      AudioManager().playSound(soundPath: 'assets/sounds/info.mp3');
      break;
    case ToastLevel.success:
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
      vibrateWithRhythm([
        (100, 0.05),  // Short initial pulse
        (200, 0.1),   // Longer second pulse with slight pause
      ]);
      AudioManager().playSound(soundPath: 'assets/sounds/success.mp3');
      break;
    case ToastLevel.warning:
      backgroundColor = Colors.orange;
      icon = Icons.warning;
      vibrateWithRhythm([
        (200, 0.1),  // Initial longer pulse
        (100, 0.2),  // Short pulse with longer pause
        (200, 0.05), // Final attention pulse with minimal pause
      ]);
      AudioManager().playSound(soundPath: 'assets/sounds/warning.mp3');
      break;
    case ToastLevel.error:
      backgroundColor = Colors.red;
      icon = Icons.error;
      vibrateWithRhythm([
        (200, 0.05),  // Short sharp initial pulse
        (100, 0.1),   // Quick pause then shorter pulse
        (300, 0.05),  // Brief pause then stronger pulse
        (100, 0.1),   // Quick pause
        (400, 0),     // Final strong pulse
      ]);
      AudioManager().playSound(soundPath: 'assets/sounds/error.mp3');
      break;
    case ToastLevel.debug:
      backgroundColor = Colors.grey;
      icon = Icons.bug_report;
      break;
  }
  
  // Calculate size safely
  final screenSize = MediaQuery.of(context).size;
  final toastWidth = screenSize.width - 40;
  
  // Create overlay entry with positioning
  final overlayEntry = OverlayEntry(
    builder: (_) {
      late Widget positionedWidget;
      switch (position) {
        case ToastPosition.top:
          positionedWidget = Positioned(
            top: 50,
            width: toastWidth,
            left: 20,
            child: _buildToastContent(backgroundColor, icon, textColor, message),
          );
          break;
        case ToastPosition.bottom:
          positionedWidget = Positioned(
            bottom: 50,
            width: toastWidth,
            left: 20,
            child: _buildToastContent(backgroundColor, icon, textColor, message),
          );
          break;
        case ToastPosition.center:
          positionedWidget = Positioned(
            top: screenSize.height / 2 - 30,
            width: toastWidth,
            left: 20,
            child: _buildToastContent(backgroundColor, icon, textColor, message),
          );
          break;
        case ToastPosition.topRight:
          positionedWidget = Positioned(
            top: 50,
            right: 20,
            width: toastWidth / 2,
            child: _buildToastContent(backgroundColor, icon, textColor, message),
          );
          break;
      }
      return positionedWidget;
    },
  );
  
  // Insert and schedule removal
  try {
    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  } catch (e) {
    print('Error showing toast: $e');
  }
}

void vibratePhone(int duration) {
  if (canVibrate == false) {
    return; // Exit if device doesn't have vibrator
  }
  Vibration.vibrate(duration: duration); // Vibrate for 500ms
}

Future<void> vibrateWithRhythm(List<(int, double)> pattern) async {
  if (canVibrate == false) {
    return; // Exit if device doesn't have vibrator
  }

  for (final (vibrationDuration, pauseDuration) in pattern) {
    await Vibration.vibrate(duration: vibrationDuration);
    await Future.delayed(Duration(milliseconds: (pauseDuration * 1000).round()));
  }
}

Widget _buildToastContent(Color backgroundColor, IconData icon, Color textColor, String message) {
  return Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    ),
  );
}
