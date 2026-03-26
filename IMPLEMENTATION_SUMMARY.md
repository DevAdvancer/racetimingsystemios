# Race Timer Change Summary

## Overview

This update completes all 10 requested changes for the iPad race timing app. The work focused on simplifying the public runner experience, protecting organizer tools, improving race-day timing workflows, and tightening import/export behavior so everything remains consistent in the local SQLite database and downstream CSVs.

## Completed Changes

### 1. Simplified runner-facing check-in and print screen

- Replaced the old runner-facing registration UI with a kiosk-style screen.
- The public screen now shows only:
  - one large name input/search field
  - one large print button
  - minimal confirmation messaging
- Filters, debug controls, list views, and organizer controls are hidden from runners.
- The kiosk flow is optimized for large text and fast use on a landscape tablet.

### 2. Same-screen ad-hoc registration for unknown runners

- If a typed runner is not found, the kiosk now offers add-and-print from the same screen.
- The app creates the runner in local SQLite, generates or reuses a stable barcode, creates the race entry, and prints the label without leaving the kiosk flow.
- Newly added runners are preserved for future exports.

### 3. Admin tools moved behind a 3-digit passcode

- Runner-facing screens no longer expose setup, diagnostics, import/export, or race management actions.
- A small gear entry point now leads to a passcode prompt.
- Organizer access is protected by a 3-digit admin code stored in app settings.
- Admin screens include a lock action that returns the device to runner mode.

### 4. Bulk race creation and automatic race-day selection

- Organizers can now bulk-create a season of races by entering a list of dates.
- The app automatically prefers today’s scheduled race on race day.
- If no race is scheduled for today, the manual race creation flow remains available as fallback.

### 5. Two ways to start the race clock

- Added a large `START RACE` button to race control.
- Added printable `START RACE` command barcode support so scanning the sticker triggers the same gun time.
- The running race clock continues to display after start.

### 6. Early starter support

- Added early-start recording before gun time.
- Volunteers can:
  - scan `EARLY START`, then scan a runner barcode
  - or scan a runner barcode and tap `Mark Early Start`
- Each early starter receives an individual start time.
- Finish timing now uses the runner’s personal start time when present.
- Early starts are flagged in results and exports.

### 7. Individual finish timing with no global race end requirement

- Finish scans now work strictly runner by runner.
- Scanning a runner after the race starts records that runner’s finish time and elapsed time.
- The scanner screen immediately highlights the last finisher with name and elapsed time.
- Duplicate scans are detected and logged without overwriting the original finish.

### 8. Live finish-order results during the race

- The scanner screen now includes a live results panel for volunteers.
- The live list shows finishers only, in finish order.
- Large fonts and clearer row styling were added for race-day readability.
- Early starters are clearly tagged in the results list.

### 9. Improved CSV/XLSX roster import in admin tools

- Import remains available from organizer tools.
- The import pipeline now:
  - parses CSV and XLSX files
  - validates rows before commit
  - skips duplicate roster rows cleanly
  - rejects conflicting barcode assignments to protect database integrity
  - reports invalid rows separately from duplicates
- Imported runners are stored in local SQLite and remain available for check-in and later export.

### 10. One-click CSV export for a selected race

- The export screen now lets organizers choose which race to export.
- Export remains one click once a race is selected.
- The CSV includes the requested core fields:
  - runner name
  - barcode
  - start time
  - finish time
  - elapsed time
  - early-start flag
- Supporting race/result fields are also included for operational clarity.
- Export file names include race date and race identifier.

## Data and Workflow Notes

- Early-start timing is stored per race entry in SQLite.
- Exported start time uses the runner’s personal start when present, otherwise the race gun time.
- Imported ad-hoc and pre-registered runners both flow through the same local database and race entry model.
- Finish results, imports, and exports all now align with the same local data model.

## Verification

The following verification completed successfully:

- `flutter test`
- `flutter analyze`
- `flutter build ios --release --no-codesign`

## Build Output

- Built app: `build/ios/iphoneos/Runner.app`

## Important Remaining Caveat

- The Flutter-side print/check-in flow is fully wired for the new kiosk behavior.
- Real Brother label printing on iOS still depends on the native printer bridge implementation already present in the iOS layer. If that native channel remains stubbed in the deployment environment, the workflow compiles and runs but physical label printing will still require that native integration to be completed or confirmed.

## Latest Adjustments

- Bulk race creation now supports importing an Excel or CSV race schedule file that creates races, not runners.
- The race schedule import accepts a race date column and can also use race name and series name columns when present.
- The kiosk now offers an explicit on-the-spot `Add Runner and Print` action when a typed runner is not found.
- Payment status is now included as a CSV export column.
- Text sizes were increased across the app, and the kiosk now uses the same dark visual theme family as the main admin experience.
