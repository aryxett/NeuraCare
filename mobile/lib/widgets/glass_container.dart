import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color baseColor;
  final double borderOpacity;
  final bool animateHover;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20.0,
    this.baseColor = Colors.white,
    this.borderOpacity = 0.1,
    this.animateHover = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fallbackColor = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.white.withOpacity(0.9); // Clean white pane for light mode

    final fallbackBorderColor = isDark
        ? Colors.white.withOpacity(borderOpacity)
        : Colors.black.withOpacity(0.05); // Subtle shadow border

    // If baseColor is explicitly passed and is not the default white, use it with opacity
    Color finalContainerColor;
    if (baseColor != Colors.white) {
      finalContainerColor = baseColor.withOpacity(isDark ? 0.1 : 0.8);
    } else {
      finalContainerColor = Theme.of(context).cardTheme.color ?? fallbackColor;
    }

    final containerBorderColor =
        Theme.of(context).cardTheme.shape is RoundedRectangleBorder
            ? ((Theme.of(context).cardTheme.shape as RoundedRectangleBorder)
                .side
                .color)
            : fallbackBorderColor;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: finalContainerColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: containerBorderColor == Colors.transparent
                    ? fallbackBorderColor
                    : containerBorderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.05), // softer shadow for both modes
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
