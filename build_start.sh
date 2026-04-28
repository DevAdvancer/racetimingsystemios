#!/bin/bash

set -e

echo "Running Flutter analyze on touched files..."
flutter analyze

echo "Building iOS simulator app..."
flutter build ios --simulator

echo "Installing app on booted simulator..."
xcrun simctl install booted build/ios/iphonesimulator/Runner.app

echo "Launching app..."
xcrun simctl launch booted com.Russ.RaceTimer

echo "Done."
