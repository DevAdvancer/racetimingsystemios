import 'package:flutter/material.dart';

class PrimaryActionTile extends StatelessWidget {
  const PrimaryActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 320 || constraints.maxHeight < 300;
        final padding = compact ? 20.0 : 30.0;
        final iconBoxSize = compact ? 64.0 : 84.0;
        final iconSize = compact ? 32.0 : 40.0;
        final badgeVertical = compact ? 6.0 : 8.0;
        final badgeHorizontal = compact ? 10.0 : 12.0;
        final pillGap = compact ? 8.0 : 12.0;
        final sectionGap = compact ? 12.0 : 18.0;
        final arrowBoxSize = compact ? 38.0 : 46.0;
        final arrowRadius = compact ? 14.0 : 16.0;
        final titleStyle = compact
            ? theme.textTheme.titleLarge?.copyWith(height: 1.15)
            : theme.textTheme.headlineMedium?.copyWith(height: 1.1);
        final subtitleStyle =
            (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                ?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                );
        final badgeStyle =
            (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                ?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    colorScheme.primaryContainer,
                    colorScheme.tertiaryContainer.withValues(alpha: 0.82),
                    colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: iconBoxSize,
                          width: iconBoxSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              compact ? 22 : 28,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: compact ? 16 : 20,
                                offset: Offset(0, compact ? 8 : 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: badgeHorizontal,
                                vertical: badgeVertical,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text('Simple step', style: badgeStyle),
                            ),
                            SizedBox(height: pillGap),
                            Container(
                              height: arrowBoxSize,
                              width: arrowBoxSize,
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: BorderRadius.circular(
                                  arrowRadius,
                                ),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: compact ? 20 : 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: sectionGap),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 14,
                        vertical: compact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Tap once to open', style: badgeStyle),
                    ),
                    SizedBox(height: sectionGap),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          title,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: compact ? 3 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
