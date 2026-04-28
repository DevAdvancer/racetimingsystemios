#!/bin/bash

set -e  # stop on error

echo "Cleaning Flutter project..."
flutter clean

echo "Getting dependencies..."
flutter pub get

echo "Removing iOS Pods and lock files..."
rm -rf ios/Pods ios/Podfile.lock

echo "Clearing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "Reinstalling CocoaPods..."
cd ios
pod deintegrate
pod repo update
pod install
cd ..

echo "Opening Xcode workspace..."
open ios/Runner.xcworkspace

echo "Done. Now build the project from Xcode or run: flutter run"
