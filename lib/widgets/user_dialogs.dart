import 'package:flutter/material.dart';

enum UserDialogTone { info, success, warning, error }

Future<void> showUserMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  UserDialogTone tone = UserDialogTone.info,
  String buttonText = 'OK',
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _UserDialogShell(
      title: title,
      message: message,
      tone: tone,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ],
    ),
  );
}

Future<bool> showUserConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Continue',
  String cancelText = 'Cancel',
  UserDialogTone tone = UserDialogTone.warning,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => _UserDialogShell(
          title: title,
          message: message,
          tone: tone,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      ) ??
      false;
}

class _UserDialogShell extends StatelessWidget {
  const _UserDialogShell({
    required this.title,
    required this.message,
    required this.tone,
    required this.actions,
  });

  final String title;
  final String message;
  final UserDialogTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = switch (tone) {
      UserDialogTone.info => (
        icon: Icons.info_outline,
        iconColor: colorScheme.primary,
        accent: colorScheme.primaryContainer,
      ),
      UserDialogTone.success => (
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF7CEAB3),
        accent: const Color(0xFF142920),
      ),
      UserDialogTone.warning => (
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFFFD59D),
        accent: const Color(0xFF392916),
      ),
      UserDialogTone.error => (
        icon: Icons.error_outline,
        iconColor: colorScheme.error,
        accent: colorScheme.errorContainer,
      ),
    };

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(palette.icon, color: palette.iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(title),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: actions,
    );
  }
}
