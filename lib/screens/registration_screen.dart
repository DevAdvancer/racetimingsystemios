import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/models/check_in_match.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/models/check_in_result.dart';
import 'package:race_timer/models/race.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/widgets/admin_access_dialog.dart';
import 'package:race_timer/widgets/barcode_widget.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _didRequestInitialKeyboard = false;
  _KioskFeedback? _feedback;
  CheckInMatch? _selectedSuggestedMatch;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    _setLandscapeMode();
  }

  Future<void> _setLandscapeMode() {
    return SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raceAsync = ref.watch(currentRaceProvider);
    final theme = Theme.of(context);
    final race = raceAsync.asData?.value;
    if (race != null && !_didRequestInitialKeyboard) {
      _didRequestInitialKeyboard = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNameField();
        }
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _KioskBackdrop()),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Runner Check-In',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 56,
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                race == null
                                    ? 'Ask the organizer to unlock setup and choose today\'s race.'
                                    : race.name,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: 34,
                                  color: race == null
                                      ? theme.colorScheme.onErrorContainer
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildInputCard(context, ref, race),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _feedback == null
                                    ? const SizedBox(
                                        key: ValueKey('empty-feedback'),
                                        height: 116,
                                      )
                                    : _FeedbackPanel(
                                        key: ValueKey(_feedback!.title),
                                        feedback: _feedback!,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _AdminCornerButton(onPressed: _promptForAdminAccess),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context, WidgetRef ref, Race? race) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typedName = _nameController.text.trim();
    final normalizedTypedName = _normalizeLookupValue(typedName);
    final showSuggestions = race != null && normalizedTypedName.length >= 2;
    final checkInStateAsync = showSuggestions
        ? ref.watch(checkInProvider)
        : null;
    final suggestionMatches = showSuggestions
        ? _buildSuggestionMatches(
            typedName,
            checkInStateAsync?.asData?.value.roster ?? const <CheckInMatch>[],
          )
        : const <CheckInMatch>[];
    final previewMatch = _resolvePreviewMatch(
      typedName: typedName,
      suggestions: suggestionMatches,
    );
    final suggestionsAreLoading =
        showSuggestions &&
        (checkInStateAsync?.isLoading ?? false) &&
        suggestionMatches.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  'Barcode Print Kiosk',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Type your name',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 40,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Type the first 2 letters to see matching names. Tap your name to preview the barcode before printing.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            enabled: !_isSubmitting && race != null,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            enableSuggestions: false,
            autocorrect: false,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 46,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            onTap: _focusNameField,
            onSubmitted: (_) => _handlePrint(),
            decoration: InputDecoration(
              hintText: 'First and last name',
              hintStyle: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 30,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: colorScheme.primaryContainer,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 30,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: colorScheme.outline, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: colorScheme.primary, width: 3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _KioskSuggestionPanel(
              key: ValueKey<String>('suggestions-$normalizedTypedName'),
              query: typedName,
              suggestions: suggestionMatches,
              isLoading: suggestionsAreLoading,
              selectedMatch: _selectedSuggestedMatch,
              onSuggestionSelected: _selectSuggestedMatch,
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _BarcodePreviewPanel(
              key: ValueKey<String>(
                previewMatch?.entry.barcodeValue ??
                    'preview-$normalizedTypedName',
              ),
              query: typedName,
              previewMatch: previewMatch,
              isLoading: suggestionsAreLoading,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'If we do not find your name, you can add yourself and print a barcode right here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 108,
            child: FilledButton(
              onPressed: _isSubmitting || race == null ? null : _handlePrint,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                textStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text('Print Barcode'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNameChanged() {
    final typedName = _nameController.text.trim();
    final selectedMatch = _selectedSuggestedMatch;
    final keepSelection =
        selectedMatch != null &&
        _normalizeLookupValue(selectedMatch.runner.name) ==
            _normalizeLookupValue(typedName);
    setState(() {
      if (!keepSelection) {
        _selectedSuggestedMatch = null;
      }
    });
  }

  void _selectSuggestedMatch(CheckInMatch match) {
    final fullName = match.runner.name;
    _nameController.value = TextEditingValue(
      text: fullName,
      selection: TextSelection.collapsed(offset: fullName.length),
    );
    setState(() {
      _selectedSuggestedMatch = match;
    });
    _focusNameField();
  }

  List<CheckInMatch> _buildSuggestionMatches(
    String typedName,
    List<CheckInMatch> roster,
  ) {
    final normalizedQuery = _normalizeLookupValue(typedName);
    if (normalizedQuery.length < 2) {
      return const <CheckInMatch>[];
    }

    final filtered = roster.where((match) {
      return _normalizeLookupValue(match.runner.name).contains(normalizedQuery);
    }).toList();

    filtered.sort((left, right) {
      final leftName = _normalizeLookupValue(left.runner.name);
      final rightName = _normalizeLookupValue(right.runner.name);
      final leftRank = _suggestionRank(leftName, normalizedQuery);
      final rightRank = _suggestionRank(rightName, normalizedQuery);
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }
      return left.runner.name.compareTo(right.runner.name);
    });

    return filtered.take(6).toList(growable: false);
  }

  int _suggestionRank(String candidateName, String normalizedQuery) {
    if (candidateName == normalizedQuery) {
      return 0;
    }
    if (candidateName.startsWith(normalizedQuery)) {
      return 1;
    }
    return 2;
  }

  CheckInMatch? _resolvePreviewMatch({
    required String typedName,
    required List<CheckInMatch> suggestions,
  }) {
    final normalizedTypedName = _normalizeLookupValue(typedName);
    if (normalizedTypedName.length < 2) {
      return null;
    }

    final selectedMatch = _selectedSuggestedMatch;
    if (selectedMatch != null &&
        _normalizeLookupValue(selectedMatch.runner.name) ==
            normalizedTypedName) {
      return selectedMatch;
    }

    final exactMatches = suggestions
        .where((match) {
          return _normalizeLookupValue(match.runner.name) ==
              normalizedTypedName;
        })
        .toList(growable: false);
    if (exactMatches.length == 1) {
      return exactMatches.first;
    }
    if (suggestions.length == 1) {
      return suggestions.first;
    }
    return null;
  }

  String _normalizeLookupValue(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _handlePrint() async {
    final typedName = _nameController.text.trim();
    if (typedName.isEmpty) {
      _setFeedback(
        const _KioskFeedback(
          title: 'Enter your name',
          message: 'Type your full name, then tap Print Barcode.',
          tone: _KioskFeedbackTone.warning,
        ),
      );
      _focusNameField();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final raceService = ref.read(raceServiceProvider);
    final lookup = await raceService.lookupRunnerForCheckIn(typedName);
    if (!mounted) {
      return;
    }

    switch (lookup.outcome) {
      case CheckInOutcome.ready:
        final result = await raceService.printCheckInMatch(
          lookup.selectedMatch!,
        );
        if (!mounted) {
          return;
        }
        _applyCheckInResult(result, addedRunner: false);
        break;
      case CheckInOutcome.notFound:
        _setFeedback(
          _KioskFeedback(
            title: 'Runner not found',
            message:
                'We could not find $typedName. Tap Add Runner and Print to add this runner on the spot.',
            tone: _KioskFeedbackTone.warning,
            actionLabel: 'Add Runner and Print',
            onAction: () => _addRunnerOnTheSpot(typedName),
          ),
        );
        break;
      case CheckInOutcome.multipleMatches:
        _setFeedback(
          const _KioskFeedback(
            title: 'Keep typing your full name',
            message:
                'We found more than one runner with a similar name. Add more of your full name, then tap Print Barcode again.',
            tone: _KioskFeedbackTone.warning,
          ),
        );
        break;
      case CheckInOutcome.noActiveRace:
        _setFeedback(
          const _KioskFeedback(
            title: 'Race not ready',
            message:
                'Ask the organizer to unlock setup and select today\'s race.',
            tone: _KioskFeedbackTone.warning,
          ),
        );
        break;
      case CheckInOutcome.validationError:
      case CheckInOutcome.failure:
      case CheckInOutcome.idle:
      case CheckInOutcome.printed:
      case CheckInOutcome.printerWarning:
        _setFeedback(
          _KioskFeedback(
            title: 'Print could not start',
            message: lookup.message,
            tone: _KioskFeedbackTone.error,
          ),
        );
        break;
    }
  }

  Future<void> _addRunnerOnTheSpot(String runnerName) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = _KioskFeedback(
        title: 'Adding runner',
        message: 'Creating the runner and sending the barcode label now.',
        tone: _KioskFeedbackTone.info,
      );
    });

    final result = await ref
        .read(raceServiceProvider)
        .createAdHocRunnerAndPrint(runnerName);
    if (!mounted) {
      return;
    }
    _applyCheckInResult(result, addedRunner: true);
  }

  Future<void> _promptForAdminAccess() async {
    await _hideSoftKeyboard();
    if (ref.read(adminAccessProvider)) {
      if (mounted) {
        context.go(AppRoutes.raceDashboard);
      }
      return;
    }

    final settings = await ref.read(settingsServiceProvider).loadSettings();
    if (!mounted) {
      return;
    }

    final accessGranted = await showAdminAccessDialog(
      context,
      expectedPasscode: settings.adminPasscode,
    );

    if (accessGranted != true || !mounted) {
      _focusNameField();
      return;
    }

    ref.read(adminAccessProvider.notifier).unlock();
    context.go(AppRoutes.raceDashboard);
  }

  void _applyCheckInResult(CheckInResult result, {required bool addedRunner}) {
    final successTitle = addedRunner ? 'Runner added' : 'Label ready';
    final successMessage = addedRunner
        ? '${result.selectedMatch?.runner.name ?? 'Runner'} was added and the barcode label was sent to the printer.'
        : 'The barcode label was sent for ${result.selectedMatch?.runner.name ?? 'this runner'}.';

    final warningTitle = addedRunner ? 'Runner added' : 'Printer needs help';
    final warningMessage = addedRunner
        ? '${result.selectedMatch?.runner.name ?? 'Runner'} was added, but the printer needs attention before the label can print.'
        : result.message;

    final feedback = switch (result.outcome) {
      CheckInOutcome.printed => _KioskFeedback(
        title: successTitle,
        message: successMessage,
        tone: _KioskFeedbackTone.success,
      ),
      CheckInOutcome.printerWarning => _KioskFeedback(
        title: warningTitle,
        message: warningMessage,
        tone: _KioskFeedbackTone.warning,
      ),
      CheckInOutcome.validationError => _KioskFeedback(
        title: 'Check the name',
        message: result.message,
        tone: _KioskFeedbackTone.warning,
      ),
      CheckInOutcome.noActiveRace => const _KioskFeedback(
        title: 'Race not ready',
        message: 'Ask the organizer to unlock setup and select today\'s race.',
        tone: _KioskFeedbackTone.warning,
      ),
      CheckInOutcome.multipleMatches => const _KioskFeedback(
        title: 'Keep typing your full name',
        message:
            'We found more than one runner with a similar name. Add more of your full name, then tap Print Barcode again.',
        tone: _KioskFeedbackTone.warning,
      ),
      CheckInOutcome.notFound => _KioskFeedback(
        title: 'Runner not found',
        message: result.message,
        tone: _KioskFeedbackTone.warning,
      ),
      CheckInOutcome.failure => _KioskFeedback(
        title: 'Could not print',
        message: result.message,
        tone: _KioskFeedbackTone.error,
      ),
      CheckInOutcome.ready || CheckInOutcome.idle => _KioskFeedback(
        title: 'Ready',
        message: result.message,
        tone: _KioskFeedbackTone.info,
      ),
    };

    _setFeedback(feedback);
    if (result.outcome == CheckInOutcome.printed ||
        result.outcome == CheckInOutcome.printerWarning) {
      _selectedSuggestedMatch = null;
      _nameController.clear();
    }
    _focusNameField();
  }

  void _setFeedback(_KioskFeedback feedback) {
    setState(() {
      _isSubmitting = false;
      _feedback = feedback;
    });
  }

  void _focusNameField() {
    if (!_nameFocusNode.canRequestFocus) {
      return;
    }
    _nameFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  Future<void> _hideSoftKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }
}

class _AdminCornerButton extends StatelessWidget {
  const _AdminCornerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Organizer setup',
        icon: const Icon(Icons.settings_outlined),
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({super.key, required this.feedback});

  final _KioskFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final palette = switch (feedback.tone) {
      _KioskFeedbackTone.success => (
        background: const Color(0xFF142920),
        border: const Color(0xFF2F7B57),
        text: const Color(0xFF9CF4C7),
        icon: Icons.check_circle,
      ),
      _KioskFeedbackTone.warning => (
        background: const Color(0xFF392916),
        border: const Color(0xFFE39B42),
        text: const Color(0xFFFFD59D),
        icon: Icons.info,
      ),
      _KioskFeedbackTone.error => (
        background: const Color(0xFF40171D),
        border: const Color(0xFFFF6B6B),
        text: const Color(0xFFFFD9DE),
        icon: Icons.error,
      ),
      _KioskFeedbackTone.info => (
        background: const Color(0xFF173043),
        border: const Color(0xFF4FA3FF),
        text: const Color(0xFFE7F5FF),
        icon: Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(palette.icon, color: palette.text, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 30,
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feedback.message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (feedback.actionLabel != null &&
                    feedback.onAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: feedback.onAction,
                    child: Text(feedback.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KioskSuggestionPanel extends StatelessWidget {
  const _KioskSuggestionPanel({
    super.key,
    required this.query,
    required this.suggestions,
    required this.isLoading,
    required this.selectedMatch,
    required this.onSuggestionSelected,
  });

  final String query;
  final List<CheckInMatch> suggestions;
  final bool isLoading;
  final CheckInMatch? selectedMatch;
  final ValueChanged<CheckInMatch> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedQuery = query.trim();

    if (trimmedQuery.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          'Type at least 2 letters to see matching runner names.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            const LinearProgressIndicator(minHeight: 6),
            const SizedBox(height: 14),
            Text(
              'Loading matching runner names.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
        ),
        child: Text(
          'No saved runner names match those letters yet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onErrorContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tap your name from the list',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final match = suggestions[index];
                final isSelected =
                    selectedMatch?.entry.id == match.entry.id &&
                    selectedMatch?.runner.id == match.runner.id;
                return OutlinedButton(
                  onPressed: () => onSuggestionSelected(match),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surface,
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.runner.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 28,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.entry.barcodeValue,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodePreviewPanel extends StatelessWidget {
  const _BarcodePreviewPanel({
    super.key,
    required this.query,
    required this.previewMatch,
    required this.isLoading,
  });

  final String query;
  final CheckInMatch? previewMatch;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedQuery = query.trim();

    if (previewMatch != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Barcode preview for ${previewMatch!.runner.name}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            RunnerBarcodePreview(
              data: previewMatch!.entry.barcodeValue,
              runnerName: previewMatch!.runner.name,
              height: 78,
              padding: const EdgeInsets.all(16),
              borderRadius: 22,
            ),
            const SizedBox(height: 10),
            Text(
              'This saved barcode will be printed when you tap Print Barcode.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final message = switch ((trimmedQuery.length >= 2, isLoading)) {
      (true, true) => 'Looking up the saved barcode for this runner.',
      (true, false) =>
        'Select a matching name to preview the saved barcode before printing.',
      _ =>
        'The saved barcode preview will appear here after you type 2 letters.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _KioskFeedback {
  const _KioskFeedback({
    required this.title,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final _KioskFeedbackTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
}

enum _KioskFeedbackTone { info, success, warning, error }

class _KioskBackdrop extends StatelessWidget {
  const _KioskBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer,
            Theme.of(context).scaffoldBackgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: const SizedBox(width: 260, height: 260),
            ),
          ),
          Positioned(
            right: -40,
            bottom: -60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.12),
              ),
              child: const SizedBox(width: 320, height: 320),
            ),
          ),
        ],
      ),
    );
  }
}
