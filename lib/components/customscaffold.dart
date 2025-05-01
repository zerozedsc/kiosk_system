import 'package:flutter/material.dart';

class CustomScaffold extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const CustomScaffold({
    Key? key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: backgroundColor ?? Colors.white,
        padding: padding,
        width: double.infinity,
        height: double.infinity,
        child: child,
      ),
    );
  }
}
