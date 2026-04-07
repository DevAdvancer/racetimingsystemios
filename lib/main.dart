import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/platform_support.dart';
import 'package:race_timer/core/router.dart';
import 'package:race_timer/core/theme.dart';
import 'package:race_timer/database/database_helper.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/services/settings_service.dart';
import 'package:race_timer/widgets/branding.dart';

Future<void> main() async {
  await PlatformSupport.ensureInitialized();
  final databaseHelper = await DatabaseHelper.create();
  await databaseHelper.ensureInitialized();
  final settingsService = await SettingsService.create();

  runApp(
    ProviderScope(
      overrides: [
        databaseHelperProvider.overrideWithValue(databaseHelper),
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const RoxburyRacesApp(),
    ),
  );
}

class RoxburyRacesApp extends ConsumerWidget {
  const RoxburyRacesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appThemeMode = ref.watch(
      settingsProvider.select(
        (settings) => settings.asData?.value.themeMode ?? AppThemeMode.light,
      ),
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: buildRoxburyRacesLightTheme(),
      darkTheme: buildRoxburyRacesDarkTheme(),
      themeMode: switch (appThemeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        return _LaunchAnimationShell(child: child ?? const SizedBox.shrink());
      },
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _LaunchAnimationShell extends StatefulWidget {
  const _LaunchAnimationShell({required this.child});

  final Widget child;

  @override
  State<_LaunchAnimationShell> createState() => _LaunchAnimationShellState();
}

class _LaunchAnimationShellState extends State<_LaunchAnimationShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
    ]).animate(_controller);
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _ringScale = Tween<double>(
      begin: 0.82,
      end: 1.34,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _ringOpacity = Tween<double>(
      begin: 0.28,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            opacity: _showSplash ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.tertiaryContainer.withValues(alpha: 0.9),
                    theme.scaffoldBackgroundColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: _ringScale.value,
                          child: Container(
                            height: 172,
                            width: 172,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(
                                alpha: _ringOpacity.value * 0.16,
                              ),
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: _ringOpacity.value,
                                ),
                                width: 2.2,
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _logoOpacity.value.clamp(0, 1),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: const BrandMark(size: 132, borderRadius: 34),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
