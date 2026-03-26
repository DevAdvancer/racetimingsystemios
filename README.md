# RaceTimer

RaceTimer is an offline-first Flutter race timing app for iPad, macOS, and Windows. The race-day device keeps all timing data in local SQLite and does not need internet connectivity once the roster has been imported.

## Current Workflow

1. Create a race in `Setup & Import`.
2. Import an `.xlsx` or `.csv` runner roster for that race.
3. The app reuses an existing local runner barcode when the same runner appears again in a later race.
4. Volunteers use `Check In & Print` to search by name and print the saved barcode label.
5. Start the race from `Race Control`.
6. Scan finishers with a HID barcode scanner from `Scan Finishers`.
7. If a barcode is unknown or scanned twice, the app warns the volunteer, keeps the original finish time, and logs the event locally.
8. View live results and export CSV when the race is complete.

## Product Rules

- Race day is fully offline.
- Runner barcodes are runner-level, not race-level.
- Returning runners keep the same barcode across weekly races.
- The app imports rosters from files; it does not connect directly to Stripe or an online registration API.
- One active race is managed at a time. The active race is the running race, or the most recent pending race if none is running.

## Tech Stack

- Flutter
- Riverpod
- SQLite via `sqflite` / `sqflite_common_ffi`
- Excel import via `excel`
- CSV export via `csv`
- Routing via `go_router`
- Brother printer bridge via iOS `MethodChannel`

## Main Screens

- `Home`: volunteer dashboard with `Check In & Print`, `Start Race`, and `Scan Finishers`
- `Setup & Import`: create race, import roster, configure printer, toggle dry run
- `Check In & Print`: search imported runners by name and print reusable barcode labels
- `Race Control`: start and end the race, show the live clock
- `Scan Finishers`: receive HID scanner input and record finish times
- `Live Results`: view finish order
- `Export Results`: save or share results as CSV with the race date and identifier in the file name
- `Diagnostics`: database check, printer test, dry-run seeding, and recent scan warning review

## Import Format

Supported file types:

- `.xlsx`
- `.csv`

Supported name headers:

- `Name`
- `Runner Name`
- `Full Name`
- `Participant`
- `Participant Name`

If no recognizable header is found, the app uses the first column as the runner name column.

## Database Notes

The app stores:

- `runners`: local runner master records, reusable barcode values, payment status, and membership status
- `races`: race metadata, race date, gun time, and optional series association
- `race_entries`: imported participation records for each race plus finish timing
- `scan_event_logs`: locally logged duplicate scans, unknown barcodes, and scan-related warnings/errors
- `age_groups`, `race_entry_splits`, and `race_entry_rankings`: extension tables reserved for future category, split, and ranking features

Important behavior:

- `runners.barcode_value` is globally unique
- `(runner_id, race_id)` is unique in `race_entries`
- `race_entries.barcode_value` mirrors the runner barcode so a scanner can resolve the runner inside the active race
- duplicate finish scans are rejected, not overwritten
- unknown barcodes are shown to the volunteer instead of failing silently

## Printer Notes

The iOS app includes a Brother method-channel bridge in [AppDelegate.swift](/Users/abhirupkumar/Developer/IOS%20IPAD%20APPS/racetimingsystemios/ios/Runner/AppDelegate.swift). The Brother QL-820NWB integration is still a native stub until the Brother iOS SDK is linked, but the Flutter-side abstraction and settings flow are already wired.

Desktop builds keep working without native printer support; label printing is intended to run on iPad in production.

## Development

Install dependencies:

```bash
flutter pub get
```

Run checks:

```bash
flutter analyze
flutter test
```

Build the iOS simulator app:

```bash
flutter build ios --simulator --debug
```

## Dry Run

Enable `Dry Run Mode` in `Setup & Import` to seed sample runners for volunteer practice. Use `Diagnostics` to generate or clear test runners.
