import 'package:flutter/material.dart';

/// A modern notification component inspired by iPhone's Dynamic Island.
///
/// This widget displays notifications in a sleek, animated pill-shaped container
/// that can be positioned at the top of the screen and supports blinking animations.
class NotificationIsland extends StatefulWidget {
  /// The message to display in the notification
  final String message;

  /// The icon to display alongside the message
  final IconData? icon;

  /// The background color of the notification
  final Color backgroundColor;

  /// The text color
  final Color textColor;

  /// Whether the notification should blink/pulse
  final bool shouldBlink;

  /// Whether the notification is visible
  final bool isVisible;

  /// Duration for the blink animation
  final Duration blinkDuration;

  /// Custom width for the notification (optional)
  final double? width;

  /// Callback when the notification is tapped
  final VoidCallback? onTap;

  const NotificationIsland({
    Key? key,
    required this.message,
    this.icon,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    this.shouldBlink = false,
    this.isVisible = true,
    this.blinkDuration = const Duration(milliseconds: 800),
    this.width,
    this.onTap,
  }) : super(key: key);

  @override
  State<NotificationIsland> createState() => _NotificationIslandState();
}

class _NotificationIslandState extends State<NotificationIsland>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _slideController;
  late Animation<double> _blinkAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Blink animation controller
    _blinkController = AnimationController(
      duration: widget.blinkDuration,
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Slide animation controller for show/hide
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    // Start animations based on initial state
    if (widget.isVisible) {
      _slideController.forward();
    }
    if (widget.shouldBlink) {
      _startBlinking();
    }
  }

  @override
  void didUpdateWidget(NotificationIsland oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility changes
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }

    // Handle blinking changes
    if (widget.shouldBlink != oldWidget.shouldBlink) {
      if (widget.shouldBlink) {
        _startBlinking();
      } else {
        _blinkController.stop();
        _blinkController.value = 1.0;
      }
    }
  }

  void _startBlinking() {
    _blinkController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: widget.shouldBlink ? _blinkAnimation.value : 1.0,
            child: child,
          );
        },
        child: Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: widget.width,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.textColor, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Predefined notification types for common use cases
class NotificationTypes {
  static const NotificationIsland offline = NotificationIsland(
    message: 'No Internet Connection',
    icon: Icons.wifi_off,
    backgroundColor: Colors.red,
    textColor: Colors.white,
    shouldBlink: true,
  );

  static const NotificationIsland connecting = NotificationIsland(
    message: 'Connecting...',
    icon: Icons.wifi,
    backgroundColor: Colors.orange,
    textColor: Colors.white,
    shouldBlink: true,
  );

  static const NotificationIsland connected = NotificationIsland(
    message: 'Connected',
    icon: Icons.wifi,
    backgroundColor: Colors.green,
    textColor: Colors.white,
    shouldBlink: false,
  );

  static NotificationIsland custom({
    required String message,
    IconData? icon,
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
    bool shouldBlink = false,
    VoidCallback? onTap,
  }) {
    return NotificationIsland(
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      textColor: textColor,
      shouldBlink: shouldBlink,
      onTap: onTap,
    );
  }
}

/// Enumeration for predefined notification positions
enum NotificationPosition {
  top,
  topLeft,
  topRight,
  center,
  centerLeft,
  centerRight,
  bottom,
  bottomLeft,
  bottomRight,
}

/// A flexible positioned wrapper for the NotificationIsland that can be placed anywhere on screen
class PositionedNotificationIsland extends StatelessWidget {
  final NotificationIsland notification;

  // Predefined position
  final NotificationPosition? position;

  // Custom positioning (overrides position if provided)
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  // Padding from edges
  final EdgeInsets padding;

  // Animation direction for slide-in effect
  final Offset? slideDirection;

  const PositionedNotificationIsland({
    Key? key,
    required this.notification,
    this.position = NotificationPosition.top,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.padding = const EdgeInsets.all(16),
    this.slideDirection,
  }) : super(key: key);

  /// Named constructors for common positions
  PositionedNotificationIsland.top({
    Key? key,
    required NotificationIsland notification,
    double topPadding = 50,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.top,
         padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
       );

  PositionedNotificationIsland.bottom({
    Key? key,
    required NotificationIsland notification,
    double bottomPadding = 50,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.bottom,
         padding: EdgeInsets.only(bottom: bottomPadding, left: 16, right: 16),
       );

  PositionedNotificationIsland.center({
    Key? key,
    required NotificationIsland notification,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.center,
         padding: const EdgeInsets.all(16),
       );

  PositionedNotificationIsland.topLeft({
    Key? key,
    required NotificationIsland notification,
    double topPadding = 50,
    double leftPadding = 16,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.topLeft,
         padding: EdgeInsets.only(top: topPadding, left: leftPadding),
       );

  PositionedNotificationIsland.topRight({
    Key? key,
    required NotificationIsland notification,
    double topPadding = 50,
    double rightPadding = 16,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.topRight,
         padding: EdgeInsets.only(top: topPadding, right: rightPadding),
       );

  PositionedNotificationIsland.bottomLeft({
    Key? key,
    required NotificationIsland notification,
    double bottomPadding = 50,
    double leftPadding = 16,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.bottomLeft,
         padding: EdgeInsets.only(bottom: bottomPadding, left: leftPadding),
       );

  PositionedNotificationIsland.bottomRight({
    Key? key,
    required NotificationIsland notification,
    double bottomPadding = 50,
    double rightPadding = 16,
  }) : this(
         key: key,
         notification: notification,
         position: NotificationPosition.bottomRight,
         padding: EdgeInsets.only(bottom: bottomPadding, right: rightPadding),
       );

  /// Custom positioning constructor
  const PositionedNotificationIsland.custom({
    Key? key,
    required NotificationIsland notification,
    double? top,
    double? bottom,
    double? left,
    double? right,
    Offset? slideDirection,
  }) : this(
         key: key,
         notification: notification,
         position: null,
         top: top,
         bottom: bottom,
         left: left,
         right: right,
         slideDirection: slideDirection,
         padding: EdgeInsets.zero,
       );

  @override
  Widget build(BuildContext context) {
    // Use custom positioning if provided
    if (top != null || bottom != null || left != null || right != null) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: notification,
      );
    }

    // Use predefined positioning
    switch (position!) {
      case NotificationPosition.top:
        return Positioned(
          top: padding.top,
          left: padding.left,
          right: padding.right,
          child: notification,
        );

      case NotificationPosition.topLeft:
        return Positioned(
          top: padding.top,
          left: padding.left,
          child: notification,
        );

      case NotificationPosition.topRight:
        return Positioned(
          top: padding.top,
          right: padding.right,
          child: notification,
        );

      case NotificationPosition.center:
        return Positioned(
          top: 0,
          bottom: 0,
          left: padding.left,
          right: padding.right,
          child: Center(child: notification),
        );

      case NotificationPosition.centerLeft:
        return Positioned(
          top: 0,
          bottom: 0,
          left: padding.left,
          child: Center(child: notification),
        );

      case NotificationPosition.centerRight:
        return Positioned(
          top: 0,
          bottom: 0,
          right: padding.right,
          child: Center(child: notification),
        );

      case NotificationPosition.bottom:
        return Positioned(
          bottom: padding.bottom,
          left: padding.left,
          right: padding.right,
          child: notification,
        );

      case NotificationPosition.bottomLeft:
        return Positioned(
          bottom: padding.bottom,
          left: padding.left,
          child: notification,
        );

      case NotificationPosition.bottomRight:
        return Positioned(
          bottom: padding.bottom,
          right: padding.right,
          child: notification,
        );
    }
  }
}

/// Legacy alias for backward compatibility
typedef TopNotificationIsland = PositionedNotificationIsland;
