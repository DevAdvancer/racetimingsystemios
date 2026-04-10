import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/providers/check_in_provider.dart';
import 'package:race_timer/providers/race_provider.dart';
import 'package:race_timer/providers/results_provider.dart';
import 'package:race_timer/providers/settings_provider.dart';
import 'package:race_timer/services/export_service.dart';
import 'package:race_timer/widgets/branding.dart';
import 'package:race_timer/widgets/status_banner.dart';
import 'package:race_timer/widgets/theme_mode_switcher.dart';
import 'package:race_timer/widgets/user_dialogs.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final TextEditingController _adminPasscodeController =
      TextEditingController();
  final TextEditingController _bulkRaceDatesController =
      TextEditingController();
  final TextEditingController _bulkRaceNameController = TextEditingController();
  final TextEditingController _bulkSeriesNameController =
      TextEditingController();
  final TextEditingController _raceNameController = TextEditingController();
  final TextEditingController _printerHostController = TextEditingController();
  final TextEditingController _printerMediaController = TextEditingController(
    text: AppConstants.defaultPrinterMedia,
  );
  final TextEditingController _scannerCheckController = TextEditingController();
  final FocusNode _scannerCheckFocusNode = FocusNode();
  late final Future<PackageInfo> _packageInfoFuture;
  bool _loadedSettings = false;
  PrinterConnectionType _printerConnectionType =
      PrinterConnectionType.bluetooth;
  DateTime? _lastScannerCheckAt;
  String? _lastScannerCheckValue;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    _adminPasscodeController.dispose();
    _bulkRaceDatesController.dispose();
    _bulkRaceNameController.dispose();
    _bulkSeriesNameController.dispose();
    _raceNameController.dispose();
    _printerHostController.dispose();
    _printerMediaController.dispose();
    _scannerCheckController.dispose();
    _scannerCheckFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final racesAsync = ref.watch(raceListProvider);
    final currentRaceAsync = ref.watch(currentRaceProvider);
    final selectedThemeMode =
        settingsAsync.asData?.value.themeMode ?? AppThemeMode.light;

    settingsAsync.whenData((settings) {
      if (_loadedSettings) {
        return;
      }
      _loadedSettings = true;
      _printerHostController.text = settings.printerHost;
      _printerMediaController.text = settings.printerMedia;
      _adminPasscodeController.text = settings.adminPasscode;
      _printerConnectionType = settings.printerConnectionType;
      _lastScannerCheckAt = settings.lastScannerCheckAt;
      _lastScannerCheckValue = settings.lastScannerCheckValue;
    });

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(pageTitle: 'Organizer Setup'),
        actions: [
          IconButton(
            tooltip: 'Return to start screen',
            onPressed: () {
              ref.read(adminAccessProvider.notifier).lock();
              context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final setupSections = <Widget>[
                _buildSectionCard(
                  context,
                  title: '${AppConstants.appName} Details',
                  children: [
                    Row(
                      children: [
                        const BrandMark(size: 72, borderRadius: 22),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'See the installed app version here before race day so organizers know every iPad is on the same release.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<PackageInfo>(
                      future: _packageInfoFuture,
                      builder: (context, snapshot) {
                        final message = switch (snapshot.connectionState) {
                          ConnectionState.done when snapshot.hasData =>
                            'Current version: ${snapshot.data!.version} (build ${snapshot.data!.buildNumber}).',
                          ConnectionState.done =>
                            'The app version could not be loaded on this device right now.',
                          _ =>
                            'Loading the installed app version for this device.',
                        };

                        return StatusBanner(
                          title: 'Current app version',
                          message: message,
                          tone: snapshot.hasData
                              ? StatusBannerTone.info
                              : snapshot.connectionState == ConnectionState.done
                              ? StatusBannerTone.warning
                              : StatusBannerTone.info,
                        );
                      },
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 1: Save Race Name',
                  children: [
                    Text(
                      'This is the race volunteers will use today.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _raceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Type the race name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final raceName = _raceNameController.text.trim();
                        if (raceName.isEmpty) {
                          await showUserMessageDialog(
                            context,
                            title: 'Race name needed',
                            message:
                                'Please type the name of the race before you continue.',
                            tone: UserDialogTone.warning,
                          );
                          return;
                        }

                        try {
                          await ref
                              .read(currentRaceProvider.notifier)
                              .createRace(name: raceName);
                          _raceNameController.clear();
                          if (context.mounted) {
                            await showUserMessageDialog(
                              context,
                              title: 'Race saved',
                              message:
                                  'The race was created. Open that race dashboard next to import runners or add a walk-up.',
                              tone: UserDialogTone.success,
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            await showUserMessageDialog(
                              context,
                              title: 'Could not save race',
                              message:
                                  'The app could not save the race name. Please try again.',
                              tone: UserDialogTone.error,
                            );
                          }
                        }
                      },
                      child: const Text('Save Race Name'),
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 2: Race Roster Tools',
                  children: [
                    Text(
                      'Runner import and manual runner add now live inside the selected race dashboard so they only appear when a race is open.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    const StatusBanner(
                      title: 'Race-specific only',
                      message:
                          'Choose a race, open its dashboard, then use Import Runners or Add New Runner there.',
                      tone: StatusBannerTone.info,
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 3: Printer Setup',
                  children: [
                    Text(
                      'Set up the Brother QL-820NWB connection for this iPad. Bluetooth uses a saved manual printer target, and Wi-Fi can report when the printer is reachable on the current network.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<PrinterConnectionType>(
                      segments: const [
                        ButtonSegment<PrinterConnectionType>(
                          value: PrinterConnectionType.bluetooth,
                          icon: Icon(Icons.bluetooth),
                          label: Text('Bluetooth'),
                        ),
                        ButtonSegment<PrinterConnectionType>(
                          value: PrinterConnectionType.network,
                          icon: Icon(Icons.wifi),
                          label: Text('Wi-Fi'),
                        ),
                      ],
                      selected: <PrinterConnectionType>{_printerConnectionType},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _printerConnectionType = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _printerHostController,
                      decoration: InputDecoration(
                        labelText: _printerConnectionType.targetFieldLabel,
                        helperText: _printerConnectionType.targetHelpText,
                        hintText: _printerConnectionType ==
                                PrinterConnectionType.bluetooth
                            ? 'Example: QL-820NWB or 00:80:92:12:34:56'
                            : 'Example: 192.168.1.45 or brother-printer.local',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _printerMediaController,
                      decoration: const InputDecoration(
                        labelText: 'Label size',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await ref
                            .read(exportServiceProvider)
                            .exportRosterTemplate();
                        if (!context.mounted) {
                          return;
                        }
                        await showUserMessageDialog(
                          context,
                          title: result.succeeded
                              ? 'Roster template ready'
                              : 'Roster template unavailable',
                          message: result.message,
                          tone: result.succeeded
                              ? UserDialogTone.success
                              : UserDialogTone.error,
                        );
                      },
                      child: const Text('Download Roster Template'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The roster template includes these import columns: ${ExportService.rosterTemplateHeaders.join(', ')}. Leave Distance blank to use the primary distance for that race, or fill it in to auto-assign an alternate distance during import.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: settingsAsync.isLoading
                          ? null
                          : () async {
                              final currentSettings =
                                  settingsAsync.asData?.value ??
                                  AppSettings.defaults();
                              final updated = currentSettings.copyWith(
                                printerHost: _printerHostController.text.trim(),
                                printerMedia: _printerMediaController.text
                                    .trim(),
                                printerConnectionType: _printerConnectionType,
                              );
                              await ref
                                  .read(settingsProvider.notifier)
                                  .saveSettings(updated);
                              if (context.mounted) {
                                await showUserMessageDialog(
                                  context,
                                  title: 'Settings saved',
                                  message:
                                      'Device printer settings were saved for this iPad.',
                                  tone: UserDialogTone.success,
                                );
                              }
                            },
                      child: const Text('Save Printer Settings'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final status = await ref
                            .read(printerServiceProvider)
                            .configure();
                        if (context.mounted) {
                          await showUserMessageDialog(
                            context,
                            title: status.isReady
                                ? 'Printer ready'
                                : 'Printer check',
                            message: status.message,
                            tone: status.isReady
                                ? UserDialogTone.success
                                : UserDialogTone.warning,
                          );
                        }
                      },
                      child: const Text('Check Printer'),
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 4: Barcode Scanner Check',
                  children: [
                    Text(
                      'Use this check to confirm the Tera AT006 is connected and sending scans to the app.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildScannerCheckSection(context),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 5: Reset Device Data',
                  children: [
                    Text(
                      'Use this only when you want to clear the device and start over with a fresh race setup.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showUserConfirmDialog(
                          context,
                          title: 'Clear all race data?',
                          message:
                              'This will delete the race list, imported runners, and saved results from this device. Printer settings will stay saved.',
                          confirmText: 'Delete Data',
                          tone: UserDialogTone.warning,
                        );
                        if (!confirmed) {
                          return;
                        }

                        await ref.read(databaseServiceProvider).resetAllData();
                        await ref
                            .read(currentRaceProvider.notifier)
                            .clearSelectedRace();
                        ref.invalidate(raceListProvider);
                        ref.invalidate(currentRaceProvider);
                        ref.invalidate(resultsProvider);
                        ref.invalidate(checkInProvider);

                        if (context.mounted) {
                          await showUserMessageDialog(
                            context,
                            title: 'All race data cleared',
                            message:
                                'This device is now empty and ready for a fresh import.',
                            tone: UserDialogTone.success,
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear All Race Data'),
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 6: Admin Access',
                  children: [
                    Text(
                      'Set the 3-digit code organizers use to unlock setup and race management.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _adminPasscodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(3),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: '3-digit admin code',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: settingsAsync.isLoading
                          ? null
                          : () async {
                              final adminPasscode = _adminPasscodeController
                                  .text
                                  .trim();
                              if (adminPasscode.length != 3) {
                                await showUserMessageDialog(
                                  context,
                                  title: '3-digit code needed',
                                  message:
                                      'Please enter exactly 3 digits for the organizer access code.',
                                  tone: UserDialogTone.warning,
                                );
                                return;
                              }

                              final currentSettings =
                                  settingsAsync.asData?.value ??
                                  AppSettings.defaults();
                              final updated = currentSettings.copyWith(
                                adminPasscode: adminPasscode,
                              );
                              await ref
                                  .read(settingsProvider.notifier)
                                  .saveSettings(updated);
                              if (context.mounted) {
                                await showUserMessageDialog(
                                  context,
                                  title: 'Admin code saved',
                                  message:
                                      'Organizer access now uses the new 3-digit code.',
                                  tone: UserDialogTone.success,
                                );
                              }
                            },
                      child: const Text('Save Admin Code'),
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Step 7: Bulk Race Creation',
                  children: [
                    Text(
                      'Create the season by importing an Excel/CSV race schedule file or by typing one date per line.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bulkRaceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Fallback race title prefix',
                        hintText: 'Example: Saturday Park Run',
                        helperText:
                            'Used when the schedule file has dates only and no race name column.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bulkSeriesNameController,
                      decoration: const InputDecoration(
                        labelText: 'Series name (optional)',
                        hintText: 'Example: 2026 Park Series',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _importRaceSchedule();
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import Race Schedule File'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Accepted formats are Excel (.xlsx) and CSV (.csv). The file should contain a date column, and it may also include race name and series name columns.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _bulkRaceDatesController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'Race dates',
                        hintText: '2026-03-28\n2026-04-04\n2026-04-11',
                        helperText:
                            'Use one date per line. Supported formats: YYYY-MM-DD, MM/DD/YYYY, or Month Day, Year.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _createRaceSeriesFromTypedDates();
                      },
                      icon: const Icon(Icons.event_repeat),
                      label: const Text('Create Race Series From Dates'),
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Recent Races',
                  children: [
                    racesAsync.when(
                      data: (races) {
                        if (races.isEmpty) {
                          return const Text('No races created yet.');
                        }
                        return Column(
                          children: races
                              .map(
                                (race) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(race.name),
                                  subtitle: Text(race.statusLabel),
                                ),
                              )
                              .toList(),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stackTrace) => Text(
                        userFacingErrorMessage(
                          error,
                          fallback:
                              'The recent race list could not be loaded right now.',
                        ),
                      ),
                    ),
                  ],
                ),
              ];

              return ListView(
                children: [
                  _buildSectionCard(
                    context,
                    title: 'Quick Start',
                    children: const [
                      _SetupStep(
                        number: '1',
                        title: 'Save the race name',
                        message:
                            'Create the race first so the app knows which race dashboard volunteers should open.',
                      ),
                      SizedBox(height: 12),
                      _SetupStep(
                        number: '2',
                        title: 'Open the race dashboard',
                        message:
                            'Import runners or add a new runner from the selected race dashboard after you choose the race.',
                      ),
                      SizedBox(height: 12),
                      _SetupStep(
                        number: '3',
                        title: 'Save printer setup',
                        message:
                            'Choose Bluetooth or Wi-Fi and save the Brother QL-820NWB connection for this iPad.',
                      ),
                      SizedBox(height: 12),
                      _SetupStep(
                        number: '4',
                        title: 'Confirm the scanner',
                        message:
                            'Run the Tera AT006 scanner check so volunteers know the iPad is receiving barcode input.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  currentRaceAsync.when(
                    data: (race) => StatusBanner(
                      title: race?.name ?? 'No active race',
                      message: race == null
                          ? 'Start by saving a race name, then open that race dashboard to manage the roster.'
                          : 'Everything on this screen applies to ${race.name}.',
                      tone: race == null
                          ? StatusBannerTone.warning
                          : race.isRunning
                          ? StatusBannerTone.success
                          : StatusBannerTone.info,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => StatusBanner(
                      title: 'Setup unavailable',
                      message: userFacingErrorMessage(
                        error,
                        fallback:
                            'Setup could not load the current race. Please reopen the app and try again.',
                      ),
                      tone: StatusBannerTone.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context,
                    title: 'Light / Dark Mode',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 52,
                            width: 52,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              selectedThemeMode == AppThemeMode.dark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Use the buttons below to switch this iPad between light mode and dark mode. The selected mode is saved automatically for this device.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AppThemeModeSwitcher(
                        selectedMode: selectedThemeMode,
                        onChanged: settingsAsync.isLoading
                            ? null
                            : _updateThemeMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildResponsiveSetupSections(setupSections, wide: wide),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveSetupSections(
    List<Widget> sections, {
    required bool wide,
  }) {
    if (!wide) {
      return Column(children: _withSpacing(sections));
    }

    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (var index = 0; index < sections.length; index++) {
      if (index.isEven) {
        leftColumn.add(sections[index]);
      } else {
        rightColumn.add(sections[index]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: _withSpacing(leftColumn))),
        const SizedBox(width: 20),
        Expanded(child: Column(children: _withSpacing(rightColumn))),
      ],
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    if (children.isEmpty) {
      return const [];
    }

    return [
      for (var index = 0; index < children.length; index++) ...[
        children[index],
        if (index != children.length - 1) const SizedBox(height: 20),
      ],
    ];
  }

  Widget _buildScannerCheckSection(BuildContext context) {
    final scannerVerified = _lastScannerCheckAt != null;
    final scannerMessage = scannerVerified
        ? 'Scanner confirmed on ${DateFormat('MMM d, h:mm a').format(_lastScannerCheckAt!.toLocal())}${_lastScannerCheckValue == null || _lastScannerCheckValue!.isEmpty ? '.' : ' with $_lastScannerCheckValue.'}'
        : 'Tap inside the box below, then scan any barcode from the Tera AT006. If text appears and this card turns green, the scanner is connected.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBanner(
          title: scannerVerified
              ? 'Barcode scanner confirmed'
              : 'Barcode scanner not confirmed',
          message: scannerMessage,
          tone: scannerVerified
              ? StatusBannerTone.success
              : StatusBannerTone.warning,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _scannerCheckController,
          focusNode: _scannerCheckFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: _recordScannerCheck,
          decoration: const InputDecoration(
            labelText: 'Tap here, then scan a barcode',
            helperText:
                'This confirms the scanner is sending input to the app.',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                _scannerCheckController.clear();
                _scannerCheckFocusNode.requestFocus();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Start Scanner Check'),
            ),
            if (scannerVerified)
              TextButton(
                onPressed: () async {
                  final settings = await ref
                      .read(settingsServiceProvider)
                      .loadSettings();
                  await ref
                      .read(settingsServiceProvider)
                      .saveSettings(settings.copyWith(clearScannerCheck: true));
                  ref.invalidate(settingsProvider);
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _lastScannerCheckAt = null;
                    _lastScannerCheckValue = null;
                    _scannerCheckController.clear();
                  });
                },
                child: const Text('Clear Scanner Check'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _recordScannerCheck(String rawValue) async {
    final barcodeValue = rawValue.trim();
    if (barcodeValue.isEmpty) {
      return;
    }

    final verifiedAt = DateTime.now().toUtc();
    final settings = await ref.read(settingsServiceProvider).loadSettings();
    await ref
        .read(settingsServiceProvider)
        .saveSettings(
          settings.copyWith(
            lastScannerCheckAt: verifiedAt,
            lastScannerCheckValue: barcodeValue,
          ),
        );
    ref.invalidate(settingsProvider);
    if (!mounted) {
      return;
    }
    setState(() {
      _lastScannerCheckAt = verifiedAt;
      _lastScannerCheckValue = barcodeValue;
      _scannerCheckController.clear();
    });
    _scannerCheckFocusNode.requestFocus();
  }

  Future<void> _createRaceSeriesFromTypedDates() async {
    try {
      final raceDates = ref
          .read(raceServiceProvider)
          .parseBulkRaceDates(_bulkRaceDatesController.text);
      final result = await ref
          .read(raceServiceProvider)
          .createRacesFromDates(
            namePrefix: _bulkRaceNameController.text,
            seriesName: _bulkSeriesNameController.text,
            dates: raceDates,
          );

      await _refreshRaceLists();

      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Race dates created',
        message:
            'Created ${result.createdCount} races. Skipped ${result.skippedCount} duplicates that already existed.',
        tone: UserDialogTone.success,
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Dates need attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not create races',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The race dates could not be saved right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }

  Future<void> _importRaceSchedule() async {
    try {
      final schedule = await ref.read(importServiceProvider).pickRaceSchedule();
      if (schedule == null) {
        return;
      }

      final result = await ref
          .read(raceServiceProvider)
          .createRacesFromSchedule(
            entries: schedule.entries,
            fallbackNamePrefix: _bulkRaceNameController.text,
            fallbackSeriesName: _bulkSeriesNameController.text,
          );

      await _refreshRaceLists();

      if (!mounted) {
        return;
      }

      final messageParts = <String>[
        'Created ${result.createdCount} races from ${schedule.sourceName}.',
      ];
      if (result.skippedCount > 0) {
        messageParts.add(
          'Skipped ${result.skippedCount} duplicates that already existed.',
        );
      }
      if (schedule.invalidRowCount > 0) {
        messageParts.add(
          'Ignored ${schedule.invalidRowCount} rows that did not contain a usable race date.',
        );
      }

      await showUserMessageDialog(
        context,
        title: 'Race schedule imported',
        message: messageParts.join(' '),
        tone: UserDialogTone.success,
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Schedule needs attention',
        message: error.message,
        tone: UserDialogTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showUserMessageDialog(
        context,
        title: 'Could not import race schedule',
        message: userFacingErrorMessage(
          error,
          fallback:
              'The race schedule file could not be imported right now. Please try again.',
        ),
        tone: UserDialogTone.error,
      );
    }
  }

  Future<void> _refreshRaceLists() async {
    ref.invalidate(raceListProvider);
    await ref.read(currentRaceProvider.notifier).refresh();
  }

  Future<void> _updateThemeMode(AppThemeMode themeMode) async {
    final currentThemeMode =
        ref.read(settingsProvider).asData?.value.themeMode ??
        AppThemeMode.light;
    if (currentThemeMode == themeMode) {
      return;
    }

    try {
      await ref.read(settingsProvider.notifier).updateThemeMode(themeMode);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The display theme could not be updated. Please try again.',
          ),
        ),
      );
    }
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.message,
  });

  final String number;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(number, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
