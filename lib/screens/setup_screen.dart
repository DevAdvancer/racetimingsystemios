import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/core/user_facing_error.dart';
import 'package:race_timer/models/app_settings.dart';
import 'package:race_timer/models/discovered_printer.dart';
import 'package:race_timer/models/printer_status.dart';
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
  final TextEditingController _scannerCheckController = TextEditingController();
  final FocusNode _scannerCheckFocusNode = FocusNode();
  late final Future<PackageInfo> _packageInfoFuture;
  List<DiscoveredPrinter> _availablePrinters = const [];
  bool _discoveringPrinters = false;
  bool _loadedSettings = false;
  String? _printerDiscoveryMessage;
  String? _loadedPrinterMedia;
  PrinterConnectionType _printerConnectionType = PrinterConnectionType.network;
  PrinterOrientation _printerOrientation = PrinterOrientation.landscape;
  PrinterResolution _printerResolution = PrinterResolution.low;
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
    _scannerCheckController.dispose();
    _scannerCheckFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanForAvailablePrinters() async {
    setState(() {
      _discoveringPrinters = true;
      _printerDiscoveryMessage =
          _printerConnectionType == PrinterConnectionType.network
          ? 'Searching the local network for Brother QL-820NWB printers.'
          : 'Searching Bluetooth for Brother QL-820NWB printers.';
    });

    try {
      final printers = await ref
          .read(printerServiceProvider)
          .discoverPrinters(connectionType: _printerConnectionType);
      if (!mounted) {
        return;
      }

      var message = printers.isEmpty
          ? _printerConnectionType == PrinterConnectionType.network
                ? 'No Brother QL-820NWB printers were found on Wi-Fi. Make sure the iPad and printer are on the same network, or save the printer IP address manually.'
                : 'No Brother QL-820NWB printers were found over Bluetooth. Save the exact Bluetooth name, serial number, or MAC address manually.'
          : 'Found ${printers.length} available ${printers.length == 1 ? 'printer' : 'printers'}. Tap one to use it for this iPad.';

      DiscoveredPrinter? defaultPrinter;
      for (final printer in printers) {
        if (_isDefaultPrinter(printer)) {
          defaultPrinter = printer;
          break;
        }
      }
      if (defaultPrinter != null) {
        _printerHostController.text = defaultPrinter.host;
        final status = await _saveAndVerifyDiscoveredPrinter();
        message =
            '${defaultPrinter.displayName} matched ${AppConstants.defaultPrinterHost} and was saved for this iPad. ${_printerStatusSummary(status)}';
      } else if (printers.length == 1 &&
          _printerHostController.text.trim().isEmpty) {
        _printerHostController.text = printers.first.host;
        final status = await _saveAndVerifyDiscoveredPrinter();
        message =
            '${printers.first.displayName} was found and saved for this iPad. ${_printerStatusSummary(status)}';
      }

      setState(() {
        _availablePrinters = printers;
        _printerDiscoveryMessage = message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availablePrinters = const [];
        _printerDiscoveryMessage = userFacingErrorMessage(
          error,
          fallback: 'The printer list could not be loaded right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _discoveringPrinters = false;
        });
      }
    }
  }

  Future<void> _useDiscoveredPrinter(DiscoveredPrinter printer) async {
    setState(() {
      _printerHostController.text = printer.host;
      _printerDiscoveryMessage =
          'Using ${printer.displayName} as ${printer.modelName}. Saving this selection for this iPad.';
    });
    final status = await _saveAndVerifyDiscoveredPrinter();
    if (!mounted) {
      return;
    }
    setState(() {
      _printerDiscoveryMessage =
          'Using ${printer.displayName} as ${printer.modelName}. This printer was saved for this iPad. ${_printerStatusSummary(status)}';
    });
  }

  Future<PrinterStatus> _saveAndVerifyDiscoveredPrinter() async {
    await _savePrinterSettings();
    final status = await ref.read(printerServiceProvider).configure();
    final loadedMedia = _loadedMediaFromStatus(status);
    if (loadedMedia != null) {
      _loadedPrinterMedia = loadedMedia;
      await _savePrinterSettings();
    }
    return status;
  }

  Future<AppSettings> _savePrinterSettings() async {
    final loadedSettings = ref.read(settingsProvider).asData?.value;
    final currentSettings =
        loadedSettings ??
        await ref.read(settingsProvider.future) ??
        AppSettings.defaults();
    final updated = currentSettings.copyWith(
      printerHost: _printerHostController.text.trim(),
      printerMedia: _loadedPrinterMedia ?? currentSettings.printerMedia,
      printerOrientation: _printerOrientation,
      printerResolution: _printerResolution,
      printerConnectionType: _printerConnectionType,
    );
    return ref.read(settingsProvider.notifier).saveSettings(updated);
  }

  bool _isDefaultPrinter(DiscoveredPrinter printer) {
    final defaultName = AppConstants.defaultPrinterHost.toLowerCase();
    return printer.host.toLowerCase() == defaultName ||
        printer.displayName.toLowerCase() == defaultName;
  }

  String? _loadedMediaFromStatus(PrinterStatus status) {
    final nativeMedia = status.loadedMedia?.trim();
    if (nativeMedia != null && nativeMedia.isNotEmpty) {
      return nativeMedia;
    }

    final match = RegExp(
      r'Loaded media:\s*([^\.]+)',
      caseSensitive: false,
    ).firstMatch(status.message);
    return match?.group(1)?.trim();
  }

  String _printerStatusSummary(PrinterStatus status) {
    final loadedMedia = _loadedMediaFromStatus(status);
    if (status.isReady && loadedMedia != null) {
      return 'Verified connection using the loaded $loadedMedia label roll.';
    }
    if (status.isReady) {
      return 'Verified connection.';
    }
    return 'Saved, but verification needs attention: ${status.message}';
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
      _loadedPrinterMedia = settings.printerMedia.trim().isEmpty
          ? null
          : settings.printerMedia;
      _adminPasscodeController.text = settings.adminPasscode;
      _printerConnectionType = settings.printerConnectionType;
      _printerOrientation = settings.printerOrientation;
      _printerResolution = settings.printerResolution;
      _lastScannerCheckAt = settings.lastScannerCheckAt;
      _lastScannerCheckValue = settings.lastScannerCheckValue;
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Choose Race',
          onPressed: () => context.go(AppRoutes.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const BrandAppBarTitle(pageTitle: 'Organizer Setup'),
        actions: [
          IconButton(
            tooltip: 'Runner Kiosk',
            onPressed: () {
              context.go(AppRoutes.registration);
              ref.read(adminAccessProvider.notifier).lock();
            },
            icon: const Icon(Icons.badge_outlined),
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
                  title: 'App Version',
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
                            'Current version: ${snapshot.data!.version}.',
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
                  title: 'Choose or Create Race',
                  children: [
                    Text(
                      'Create the race volunteers will use today, or return to Choose Race to open an existing race.',
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
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.adminHome),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Open Choose Race'),
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Race Roster Tools',
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
                  title: 'Point Tools',
                  children: [
                    Text(
                      'Use point tools to review overall standings or award points from the selected race dashboard.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.overallPoints),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Open Overall Points'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.raceDashboard),
                          icon: const Icon(Icons.dashboard_outlined),
                          label: const Text('Open Race Dashboard'),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildSectionCard(
                  context,
                  title: 'Printer Setup and Verify',
                  children: [
                    Text(
                      'Set up the Brother QL-820NWB connection for this iPad. The app defaults to ${AppConstants.defaultPrinterHost}, prints landscape by default, and uses the label roll currently loaded in the printer.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    const StatusBanner(
                      title: 'Recommended connection',
                      message:
                          'Use Wi-Fi / network printing first. The app searches the local network, verifies the QL-820NWB model family, and prefers ${AppConstants.defaultPrinterHost} when that printer appears.',
                      tone: StatusBannerTone.info,
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
                          _availablePrinters = const [];
                          _printerDiscoveryMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _printerHostController,
                      decoration: InputDecoration(
                        labelText: _printerConnectionType.targetFieldLabel,
                        helperText: _printerConnectionType.targetHelpText,
                        hintText:
                            _printerConnectionType ==
                                PrinterConnectionType.bluetooth
                            ? 'Example: ${AppConstants.defaultPrinterHost}, serial number, or available Bluetooth name'
                            : 'Example: 192.168.1.45, brother-printer.local, ${AppConstants.defaultPrinterHost}, or leave blank to auto-discover',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<PrinterOrientation>(
                      segments: const [
                        ButtonSegment<PrinterOrientation>(
                          value: PrinterOrientation.landscape,
                          icon: Icon(Icons.stay_current_landscape_outlined),
                          label: Text('Landscape'),
                        ),
                        ButtonSegment<PrinterOrientation>(
                          value: PrinterOrientation.portrait,
                          icon: Icon(Icons.stay_current_portrait_outlined),
                          label: Text('Portrait'),
                        ),
                      ],
                      selected: <PrinterOrientation>{_printerOrientation},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _printerOrientation = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<PrinterResolution>(
                      segments: const [
                        ButtonSegment<PrinterResolution>(
                          value: PrinterResolution.low,
                          icon: Icon(Icons.bolt_outlined),
                          label: Text('Fast / Low Res'),
                        ),
                        ButtonSegment<PrinterResolution>(
                          value: PrinterResolution.high,
                          icon: Icon(Icons.high_quality_outlined),
                          label: Text('High Res'),
                        ),
                      ],
                      selected: <PrinterResolution>{_printerResolution},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _printerResolution = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    StatusBanner(
                      title: 'Print speed',
                      message: _printerResolution == PrinterResolution.low
                          ? 'Fast / Low Res skips extra status checks and uses faster Brother print settings. Wi-Fi usually gives the best chance of a 2-4 second label.'
                          : 'High Res keeps extra status checks and uses best-quality Brother print settings for sharper labels.',
                      tone: StatusBannerTone.info,
                    ),
                    const SizedBox(height: 12),
                    StatusBanner(
                      title: 'Loaded label roll',
                      message: _loadedPrinterMedia == null
                          ? 'No loaded label size has been detected yet. Use Check Printer to read the roll currently in the printer.'
                          : 'Detected from the printer: $_loadedPrinterMedia.',
                      tone: StatusBannerTone.info,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _discoveringPrinters
                          ? null
                          : () async {
                              await _scanForAvailablePrinters();
                            },
                      icon: Icon(
                        _printerConnectionType == PrinterConnectionType.network
                            ? Icons.wifi_find
                            : Icons.bluetooth_searching,
                      ),
                      label: Text(
                        _discoveringPrinters
                            ? 'Finding and verifying...'
                            : _printerConnectionType ==
                                  PrinterConnectionType.network
                            ? 'Find and Verify Wi-Fi Printer'
                            : 'Find and Verify Bluetooth Printer',
                      ),
                    ),
                    if (_printerDiscoveryMessage != null) ...[
                      const SizedBox(height: 12),
                      StatusBanner(
                        title: _availablePrinters.isEmpty
                            ? 'Printer discovery'
                            : 'Available printers',
                        message: _printerDiscoveryMessage!,
                        tone: _availablePrinters.isEmpty
                            ? StatusBannerTone.warning
                            : StatusBannerTone.success,
                      ),
                    ],
                    if (_availablePrinters.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._availablePrinters.map(
                        (printer) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Icon(
                              printer.connectionType ==
                                      PrinterConnectionType.network
                                  ? Icons.print_outlined
                                  : Icons.bluetooth_connected,
                            ),
                            title: Text(printer.displayName),
                            subtitle: Text(
                              '${printer.modelName} • ${printer.host}',
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await _useDiscoveredPrinter(printer);
                              },
                              child: const Text('Use This'),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                              await _savePrinterSettings();
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
                  title: 'Barcode Scanner Setup and Verify',
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
                  title: 'Reset Device Data',
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
                  title: 'Admin Access',
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
                  title: 'Race Schedule Tools',
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
                    title: 'Organizer Quick Setup Instructions',
                    children: [
                      const _InstructionLine(
                        text:
                            'Open Organizer Tools by clicking the three dots in the top right corner of the homepage.',
                      ),
                      const _InstructionLine(
                        text:
                            'Enter the 3 digit code (1,2,3). This can be changed once you are in the app.',
                      ),
                      const _InstructionLine(text: 'Open the Race Dashboard.'),
                      const _InstructionLine(
                        text: 'Open Choose or Create Race.',
                      ),
                      const _InstructionLine(text: 'Open Timing Screen.'),
                      const SizedBox(height: 18),
                      Text(
                        'Maintenance tools on this page:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const _MaintenanceToolList(),
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

class _InstructionLine extends StatelessWidget {
  const _InstructionLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(text, style: textStyle),
    );
  }
}

class _MaintenanceToolList extends StatelessWidget {
  const _MaintenanceToolList();

  static const _tools = <String>[
    'App version',
    'Race Roster tools',
    'Point tools',
    'Printer Set up and verify',
    'Barcode Scanner set up and verify',
    'Reset Device Data',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tool in _tools)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MaintenanceToolName(tool),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MaintenanceToolName extends StatelessWidget {
  const _MaintenanceToolName(this.tool);

  final String tool;

  @override
  Widget build(BuildContext context) {
    return Text(tool, style: Theme.of(context).textTheme.titleMedium);
  }
}
