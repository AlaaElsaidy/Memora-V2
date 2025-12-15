import 'package:alzcare/config/screen_sizer/screen_sizer_utility.dart';
import 'package:flutter/material.dart';

/// A responsive wrapper widget that initializes screen sizing utilities
/// and provides responsive behavior across different screen sizes.
/// 
/// This widget acts as a responsive layer that adapts the app to different
/// device sizes while maintaining the design proportions based on the design size.
/// It wraps the entire app and ensures all screens have access to responsive sizing.
class ScreenSizer extends StatefulWidget {
  /// The child widget to be wrapped (typically MaterialApp)
  final Widget child;

  /// The design size used as a reference for scaling
  final Size designSize;

  /// Whether to allow font scaling based on screen size
  final bool allowFontScaling;

  /// Minimum text scaling factor
  final double minTextAdaptFactor;

  /// Maximum text scaling factor
  final double maxTextAdaptFactor;

  const ScreenSizer({
    super.key,
    required this.child,
    required this.designSize,
    this.allowFontScaling = true,
    this.minTextAdaptFactor = 0.5,
    this.maxTextAdaptFactor = 2.0,
  });

  @override
  State<ScreenSizer> createState() => _ScreenSizerState();
}

class _ScreenSizerState extends State<ScreenSizer> {
  @override
  void initState() {
    super.initState();
    // Initialize with default values (will be updated in build)
    ScreenSizerUtility.init(
      designHeight: widget.designSize.height,
      designWidth: widget.designSize.width,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final deviceSize = mediaQuery.size;

        // Initialize screen sizer utility with design size
        // This is called on every build to ensure it's responsive to screen changes
        // This ensures all screens (pages) have access to the initialized utility
        ScreenSizerUtility.init(
          designHeight: widget.designSize.height,
          designWidth: widget.designSize.width,
        );

        // Calculate responsive text scaling based on screen size
        final widthRatio = deviceSize.width / widget.designSize.width;
        final heightRatio = deviceSize.height / widget.designSize.height;

        // Use average ratio for balanced scaling
        final averageRatio = (widthRatio + heightRatio) / 2;

        // Clamp the text scaling factor to prevent extreme values
        final textScaleFactor = averageRatio.clamp(
          widget.minTextAdaptFactor,
          widget.maxTextAdaptFactor,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: widget.allowFontScaling
                ? TextScaler.linear(textScaleFactor)
                : mediaQuery.textScaler,
          ),
          child: OrientationBuilder(
            builder: (context, orientation) {
              // Ensure ScreenSizerUtility is initialized for all screens
              // This Builder ensures every page/screen gets the proper context
              return Builder(
                builder: (context) {
                  // Re-initialize to ensure all pages have access
                  ScreenSizerUtility.init(
                    designHeight: widget.designSize.height,
                    designWidth: widget.designSize.width,
                  );

                  // Return the child (MaterialApp) which contains all pages
                  return widget.child;
                },
              );
            },
          ),
        );
      },
    );
  }
}
