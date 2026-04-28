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
    final race = raceAsync.asData?.value;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (!_didRequestInitialKeyboard) {
      _didRequestInitialKeyboard = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNameField();
        }
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _KioskBackdrop()),
            Positioned.fill(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(32, 24, 32, 24 + bottomInset),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1480),
                        child: _buildKioskLayout(
                          context,
                          ref,
                          race,
                          constraints,
                        ),
                      ),
                    );
                  },
                ),
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

  Widget _buildKioskLayout(
    BuildContext context,
    WidgetRef ref,
    Race? race,
    BoxConstraints constraints,
  ) {
    final theme = Theme.of(context);
    final typedName = _nameController.text.trim();
    final normalizedTypedName = _normalizeLookupValue(typedName);
    final showSuggestions = race != null && normalizedTypedName.isNotEmpty;
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
    final isWideLayout = constraints.maxWidth >= 1080;
    final panelGap = isWideLayout ? 20.0 : 16.0;
    final entryPanelHeight = previewMatch == null
        ? (isWideLayout ? 182.0 : 172.0)
        : (isWideLayout ? 238.0 : 228.0);
    final actionPanelHeight = isWideLayout
        ? (constraints.maxHeight * 0.14).clamp(102.0, 126.0)
        : 110.0;
    final keyboardPanelHeight = isWideLayout
        ? (constraints.maxHeight * 0.28).clamp(220.0, 280.0)
        : (constraints.maxHeight * 0.34).clamp(230.0, 290.0);

    final suggestionPanel = _KioskSuggestionPanel(
      key: ValueKey<String>('suggestions-$normalizedTypedName'),
      query: typedName,
      raceReady: race != null,
      suggestions: suggestionMatches,
      isLoading: suggestionsAreLoading,
      selectedMatch: _selectedSuggestedMatch,
      onSuggestionSelected: _selectSuggestedMatch,
    );
    final keyboardPanel = _buildKeyboardPanel(
      context,
      isWideLayout: isWideLayout,
    );
    final feedbackPanel = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _feedback == null
          ? const SizedBox.shrink(key: ValueKey('empty-feedback'))
          : _FeedbackPanel(
              key: ValueKey(_feedback!.title),
              feedback: _feedback!,
            ),
    );

    if (!isWideLayout) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRaceBanner(context, race),
            SizedBox(height: panelGap),
            SizedBox(
              height: entryPanelHeight,
              child: _buildNameEntryPanel(context, theme, previewMatch),
            ),
            SizedBox(height: panelGap),
            SizedBox(
              height: actionPanelHeight,
              child: _buildPrintActionButton(context, race, previewMatch),
            ),
            SizedBox(height: panelGap),
            SizedBox(height: 280, child: suggestionPanel),
            SizedBox(height: panelGap),
            SizedBox(height: keyboardPanelHeight, child: keyboardPanel),
            if (_feedback != null) ...[
              const SizedBox(height: 18),
              feedbackPanel,
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRaceBanner(context, race),
        SizedBox(height: panelGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildNameEntryPanel(
                              context,
                              theme,
                              previewMatch,
                            ),
                          ),
                          SizedBox(height: panelGap),
                          SizedBox(
                            height: actionPanelHeight,
                            child: _buildPrintActionButton(
                              context,
                              race,
                              previewMatch,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: panelGap),
                    Expanded(flex: 12, child: suggestionPanel),
                  ],
                ),
              ),
              if (_feedback != null) ...[
                SizedBox(height: panelGap),
                feedbackPanel,
              ],
              SizedBox(height: panelGap),
              SizedBox(height: keyboardPanelHeight, child: keyboardPanel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardPanel(
    BuildContext context, {
    required bool isWideLayout,
  }) {
    return _KioskPanelShell(
      padding: EdgeInsets.fromLTRB(
        isWideLayout ? 20 : 16,
        isWideLayout ? 16 : 14,
        isWideLayout ? 20 : 16,
        isWideLayout ? 16 : 14,
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: _KioskQwertyPad(
              largeLayout: isWideLayout,
              enabled: !_isSubmitting,
              onLetterPressed: _insertKeyboardLetter,
              onPunctuationPressed: _appendKeyboardCharacter,
              onSpacePressed: _appendKeyboardSpace,
              onBackspacePressed: _removeLastCharacter,
              onClearPressed: _clearTypedName,
              onDonePressed: _handlePrint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRaceBanner(BuildContext context, Race? race) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _KioskPanelShell(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      borderRadius: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Runner Check-In',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 18,
              letterSpacing: 1.1,
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            race?.name ?? 'No race selected',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 34,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (race == null) ...[
            const SizedBox(height: 6),
            Text(
              'Ask the organizer to unlock setup and choose today\'s race.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNameEntryPanel(
    BuildContext context,
    ThemeData theme,
    CheckInMatch? previewMatch,
  ) {
    return _KioskPanelShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 150;

          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  enabled: !_isSubmitting,
                  readOnly: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w800,
                  ),
                  onTap: _focusNameField,
                  onSubmitted: (_) => _handlePrint(),
                  decoration: InputDecoration(
                    hintText: 'First name / last name',
                    helperText:
                        'Use the keyboard below to type. Matching names appear in the list.',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: compact ? 18 : 22,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: previewMatch == null
                      ? const SizedBox(
                          key: ValueKey('name-entry-spacer'),
                          height: 0,
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _SelectedRunnerPreview(
                            key: ValueKey(previewMatch.entry.barcodeValue),
                            match: previewMatch,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrintActionButton(
    BuildContext context,
    Race? race,
    CheckInMatch? previewMatch,
  ) {
    final theme = Theme.of(context);

    return FilledButton(
      onPressed: _isSubmitting ? null : _handlePrint,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        disabledBackgroundColor: theme.colorScheme.primary.withValues(
          alpha: 0.35,
        ),
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 90;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Print Barcode',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontSize: compact ? 21 : 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        previewMatch == null
                            ? race == null
                                  ? 'Select a race in organizer setup, then print.'
                                  : 'Select a matching runner, then print.'
                            : 'Selected: ${previewMatch.runner.name}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.92,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              },
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
    if (normalizedQuery.isEmpty) {
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

    return filtered.take(24).toList(growable: false);
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

  void _insertKeyboardLetter(String letter) {
    final currentValue = _nameController.text;
    final shouldUppercase =
        currentValue.isEmpty ||
        currentValue.endsWith(' ') ||
        currentValue.endsWith('-') ||
        currentValue.endsWith('\'');
    _appendKeyboardCharacter(
      shouldUppercase ? letter.toUpperCase() : letter.toLowerCase(),
    );
  }

  void _appendKeyboardCharacter(String character) {
    final updatedValue = '${_nameController.text}$character';
    _nameController.value = TextEditingValue(
      text: updatedValue,
      selection: TextSelection.collapsed(offset: updatedValue.length),
    );
    _focusNameField();
  }

  void _appendKeyboardSpace() {
    final currentValue = _nameController.text;
    if (currentValue.isEmpty || currentValue.endsWith(' ')) {
      return;
    }
    _appendKeyboardCharacter(' ');
  }

  void _removeLastCharacter() {
    final currentValue = _nameController.text;
    if (currentValue.isEmpty) {
      return;
    }
    final updatedValue = currentValue.substring(0, currentValue.length - 1);
    _nameController.value = TextEditingValue(
      text: updatedValue,
      selection: TextSelection.collapsed(offset: updatedValue.length),
    );
    _focusNameField();
  }

  void _clearTypedName() {
    if (_nameController.text.isEmpty) {
      return;
    }
    _nameController.clear();
    _focusNameField();
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
    final colorScheme = Theme.of(context).colorScheme;
    final palette = switch (feedback.tone) {
      _KioskFeedbackTone.success => (
        background: colorScheme.secondaryContainer,
        border: colorScheme.secondary.withValues(alpha: 0.42),
        text: colorScheme.onSecondaryContainer,
        icon: Icons.check_circle_outline,
      ),
      _KioskFeedbackTone.warning => (
        background: colorScheme.tertiaryContainer,
        border: colorScheme.tertiary.withValues(alpha: 0.46),
        text: colorScheme.onTertiaryContainer,
        icon: Icons.warning_amber_rounded,
      ),
      _KioskFeedbackTone.error => (
        background: colorScheme.errorContainer,
        border: colorScheme.error.withValues(alpha: 0.55),
        text: colorScheme.onErrorContainer,
        icon: Icons.error_outline,
      ),
      _KioskFeedbackTone.info => (
        background: colorScheme.primaryContainer,
        border: colorScheme.primary.withValues(alpha: 0.4),
        text: colorScheme.onPrimaryContainer,
        icon: Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(palette.icon, color: palette.text, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: feedback.onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.border,
                      foregroundColor: palette.text,
                    ),
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

class _KioskSuggestionPanel extends StatefulWidget {
  const _KioskSuggestionPanel({
    super.key,
    required this.query,
    required this.raceReady,
    required this.suggestions,
    required this.isLoading,
    required this.selectedMatch,
    required this.onSuggestionSelected,
  });

  final String query;
  final bool raceReady;
  final List<CheckInMatch> suggestions;
  final bool isLoading;
  final CheckInMatch? selectedMatch;
  final ValueChanged<CheckInMatch> onSuggestionSelected;

  @override
  State<_KioskSuggestionPanel> createState() => _KioskSuggestionPanelState();
}

class _KioskSuggestionPanelState extends State<_KioskSuggestionPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedQuery = widget.query.trim();
    final showScrollHint = widget.suggestions.length > 5;

    return _KioskPanelShell(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.suggestions.isNotEmpty
                ? 'Tap your name from the list'
                : 'Matching runners',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: showScrollHint ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Scroll to see more matching names',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                if (!widget.raceReady) {
                  return const _CenteredRosterMessage(
                    message:
                        'Choose a race in organizer setup to load the runner roster.',
                  );
                }

                if (trimmedQuery.isEmpty) {
                  return _CenteredRosterMessage(
                    message:
                        'Tap at least 1 letter to show matching runner names from the roster.',
                  );
                }

                if (widget.isLoading) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LinearProgressIndicator(
                        minHeight: 6,
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading matching runner names.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }

                if (widget.suggestions.isEmpty) {
                  return const _CenteredRosterMessage(
                    message: 'No saved runner names match those letters yet.',
                  );
                }

                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: showScrollHint,
                  trackVisibility: showScrollHint,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: widget.suggestions.length,
                    itemBuilder: (context, index) {
                      final match = widget.suggestions[index];
                      final isSelected =
                          widget.selectedMatch?.entry.id == match.entry.id &&
                          widget.selectedMatch?.runner.id == match.runner.id;
                      return OutlinedButton(
                        onPressed: () => widget.onSuggestionSelected(match),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          backgroundColor: isSelected
                              ? colorScheme.primaryContainer
                              : colorScheme.surface,
                          side: BorderSide(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1.2,
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
                                fontSize: 26,
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
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
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KioskQwertyPad extends StatelessWidget {
  const _KioskQwertyPad({
    required this.largeLayout,
    required this.enabled,
    required this.onLetterPressed,
    required this.onPunctuationPressed,
    required this.onSpacePressed,
    required this.onBackspacePressed,
    required this.onClearPressed,
    required this.onDonePressed,
  });

  static const List<List<String>> _rows = <List<String>>[
    <String>['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    <String>['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    <String>['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  final bool largeLayout;
  final bool enabled;
  final ValueChanged<String> onLetterPressed;
  final ValueChanged<String> onPunctuationPressed;
  final VoidCallback onSpacePressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: largeLayout ? 22 : 18,
      fontWeight: FontWeight.w700,
    );
    final keyHeight = largeLayout ? 50.0 : 46.0;
    final keyWidth = largeLayout ? 72.0 : 60.0;
    final rowSpacing = largeLayout ? 10.0 : 8.0;
    final keySpacing = largeLayout ? 10.0 : 8.0;
    final rowInset = largeLayout ? 28.0 : 20.0;
    final thirdRowSpecialWidth = largeLayout ? 104.0 : 88.0;
    final bottomKeyWidth = largeLayout ? 126.0 : 108.0;
    final punctuationWidth = largeLayout ? 86.0 : 72.0;
    final spaceWidth = largeLayout ? 320.0 : 250.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Kiosk keyboard', style: labelStyle),
        SizedBox(height: largeLayout ? 14 : 10),
        Padding(
          padding: EdgeInsets.only(bottom: rowSpacing),
          child: _buildLetterRow(
            _rows[0],
            keyWidth: keyWidth,
            keyHeight: keyHeight,
            keySpacing: keySpacing,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: rowSpacing),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: rowInset),
            child: _buildLetterRow(
              _rows[1],
              keyWidth: keyWidth,
              keyHeight: keyHeight,
              keySpacing: keySpacing,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: rowSpacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _KioskKeyboardKey(
                label: 'Clear',
                icon: Icons.clear_all_rounded,
                width: thirdRowSpecialWidth,
                height: keyHeight,
                onPressed: enabled ? onClearPressed : null,
                isSpecial: true,
              ),
              SizedBox(width: keySpacing),
              _buildLetterRow(
                _rows[2],
                keyWidth: keyWidth,
                keyHeight: keyHeight,
                keySpacing: keySpacing,
                mainAxisSize: MainAxisSize.min,
              ),
              SizedBox(width: keySpacing),
              _KioskKeyboardKey(
                label: 'Backspace',
                icon: Icons.backspace_outlined,
                width: thirdRowSpecialWidth,
                height: keyHeight,
                onPressed: enabled ? onBackspacePressed : null,
                isSpecial: true,
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KioskKeyboardKey(
              label: '\'',
              width: punctuationWidth,
              height: keyHeight,
              onPressed: enabled ? () => onPunctuationPressed('\'') : null,
              isSpecial: true,
            ),
            SizedBox(width: keySpacing),
            _KioskKeyboardKey(
              label: '-',
              width: punctuationWidth,
              height: keyHeight,
              onPressed: enabled ? () => onPunctuationPressed('-') : null,
              isSpecial: true,
            ),
            SizedBox(width: keySpacing),
            _KioskKeyboardKey(
              label: 'Space',
              icon: Icons.space_bar,
              width: spaceWidth,
              height: keyHeight,
              onPressed: enabled ? onSpacePressed : null,
              isSpecial: true,
            ),
            SizedBox(width: keySpacing),
            _KioskKeyboardKey(
              label: 'Done',
              icon: Icons.keyboard_return_rounded,
              width: bottomKeyWidth,
              height: keyHeight,
              onPressed: enabled ? onDonePressed : null,
              isSpecial: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLetterRow(
    List<String> letters, {
    required double keyWidth,
    required double keyHeight,
    required double keySpacing,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: mainAxisSize,
      children: [
        for (var index = 0; index < letters.length; index++) ...[
          _KioskKeyboardKey(
            label: letters[index],
            width: keyWidth,
            height: keyHeight,
            onPressed: enabled ? () => onLetterPressed(letters[index]) : null,
          ),
          if (index != letters.length - 1) SizedBox(width: keySpacing),
        ],
      ],
    );
  }
}

class _KioskKeyboardKey extends StatelessWidget {
  const _KioskKeyboardKey({
    required this.label,
    required this.onPressed,
    required this.width,
    required this.height,
    this.icon,
    this.isSpecial = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final IconData? icon;
  final bool isSpecial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isSpecial
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: height >= 50 ? 20 : 17,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSpecial ? 12 : 10),
          ),
        ),
        child: icon == null
            ? FittedBox(fit: BoxFit.scaleDown, child: Text(label))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: height >= 52 ? 22 : 20),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SelectedRunnerPreview extends StatelessWidget {
  const _SelectedRunnerPreview({super.key, required this.match});

  final CheckInMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.42),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Barcode preview for ${match.runner.name}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            match.entry.barcodeValue,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredRosterMessage extends StatelessWidget {
  const _CenteredRosterMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _KioskPanelShell extends StatelessWidget {
  const _KioskPanelShell({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 34,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colorScheme.outlineVariant, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
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
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.36),
            colorScheme.tertiaryContainer.withValues(alpha: 0.26),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
