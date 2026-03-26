import 'package:flutter/material.dart';

enum StatusBannerTone { info, success, warning, error }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String message;
  final StatusBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = switch (tone) {
      StatusBannerTone.info => (
        icon: Icons.info_outline,
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
        border: colorScheme.primary.withValues(alpha: 0.35),
      ),
      StatusBannerTone.success => (
        icon: Icons.check_circle_outline,
        background: const Color(0xFF142920),
        foreground: const Color(0xFF9CF4C7),
        border: const Color(0xFF2C6D53),
      ),
      StatusBannerTone.warning => (
        icon: Icons.warning_amber_rounded,
        background: const Color(0xFF392916),
        foreground: const Color(0xFFFFD59D),
        border: const Color(0xFFE39B42),
      ),
      StatusBannerTone.error => (
        icon: Icons.error_outline,
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        border: colorScheme.error.withValues(alpha: 0.55),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(palette.icon, color: palette.foreground, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: palette.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
