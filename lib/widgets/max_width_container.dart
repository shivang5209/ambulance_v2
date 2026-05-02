import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveHelper.value<double>(
            context,
            mobile: double.infinity,
            tablet: 800,
            desktop: 1200,
          ),
        ),
        child: child,
      ),
    );
  }
}
