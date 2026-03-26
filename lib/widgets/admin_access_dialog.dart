import 'package:flutter/material.dart';

Future<bool> showAdminAccessDialog(
  BuildContext context, {
  required String expectedPasscode,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) =>
            _AdminAccessDialog(expectedPasscode: expectedPasscode),
      ) ??
      false;
}

class _AdminAccessDialog extends StatefulWidget {
  const _AdminAccessDialog({required this.expectedPasscode});

  final String expectedPasscode;

  @override
  State<_AdminAccessDialog> createState() => _AdminAccessDialogState();
}

class _AdminAccessDialogState extends State<_AdminAccessDialog> {
  static const _digitRows = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
  ];

  String _enteredCode = '';
  String? _errorText;

  void _submit() {
    if (_enteredCode.length != 3) {
      setState(() {
        _errorText = 'Enter the 3-digit code.';
      });
      return;
    }

    if (_enteredCode != widget.expectedPasscode) {
      setState(() {
        _errorText = 'Incorrect organizer code.';
        _enteredCode = '';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _appendDigit(String digit) {
    if (_enteredCode.length >= 3) {
      return;
    }
    setState(() {
      _enteredCode = '$_enteredCode$digit';
      _errorText = null;
    });
    if (_enteredCode.length == 3) {
      _submit();
    }
  }

  void _deleteDigit() {
    if (_enteredCode.isEmpty) {
      return;
    }
    setState(() {
      _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(
              Icons.admin_panel_settings_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Text('Organizer Access')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tap the 3-digit organizer code to open the dashboard.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: List<Widget>.generate(3, (index) {
                final hasDigit = index < _enteredCode.length;
                return Expanded(
                  child: Container(
                    height: 78,
                    margin: EdgeInsets.only(right: index == 2 ? 0 : 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: hasDigit
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: hasDigit ? 2 : 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hasDigit ? _enteredCode[index] : '•',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: hasDigit ? 42 : 34,
                        color: hasDigit
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Text(
              _errorText ??
                  'The dashboard opens automatically as soon as the 3 digits match.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _errorText == null
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ..._digitRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: row
                      .map(
                        (digit) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: digit == row.last ? 0 : 12,
                            ),
                            child: _PinPadButton(
                              label: digit,
                              onPressed: () => _appendDigit(digit),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _PinPadButton(
                    label: '0',
                    onPressed: () => _appendDigit('0'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PinPadButton(
                    label: 'Clear',
                    icon: Icons.backspace_outlined,
                    onPressed: _deleteDigit,
                    filled: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _enteredCode.length == 3 ? _submit : null,
          child: const Text('Open Dashboard'),
        ),
      ],
    );
  }
}

class _PinPadButton extends StatelessWidget {
  const _PinPadButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon), const SizedBox(width: 8), Text(label)],
          );

    final buttonStyle = filled
        ? FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: Theme.of(context).textTheme.headlineSmall,
          )
        : OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: Theme.of(context).textTheme.titleLarge,
          );

    return filled
        ? FilledButton(onPressed: onPressed, style: buttonStyle, child: child)
        : OutlinedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: child,
          );
  }
}
