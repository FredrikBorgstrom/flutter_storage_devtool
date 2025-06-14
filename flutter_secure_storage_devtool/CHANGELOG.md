# Changelog

## 0.3.2

* **IMPROVED:** Removed verbose debug output
  - Removed all `developer.log()` statements throughout the library

## 0.3.1

* **IMPROVED:** Updated repository references
  - Renamed GitHub repository to `flutter_secure_storage_devtool` for consistency
  - Updated all package URLs and documentation links
  - Fixed screenshot links in README to point to new repository location

## 0.3.0

* **NEW:** Added Web and WASM platform compatibility
  - Implemented conditional imports to support Web and WASM compilation
  - Added platform-specific implementations for secure cross-platform operation
  - Package now supports all Flutter platforms: iOS, Android, Web, Windows, macOS, Linux
* **IMPROVED:** Updated dependencies for better compatibility
  - Updated `flutter_secure_storage` to `^9.2.0` for listener functionality support
  - Updated `devtools_extensions` to `^0.4.0` for latest DevTools features
  - Fixed lower bound dependency compatibility issues
* **IMPROVED:** Enhanced pub.dev scoring
  - Resolved platform support issues that were affecting pub.dev scoring
  - Fixed dependency constraint lower bounds compatibility
  - Improved package maintainability and cross-platform support

## 0.2.0

* **NEW:** Added JSON value expansion and formatting
  - Automatic JSON detection for values
  - Clickable expansion for JSON values with proper indentation
  - Copy formatted JSON to clipboard functionality
  - Dark mode support with black background for JSON display
* **NEW:** Added "Fetch All" button in app bar for manual data refresh
* **NEW:** Added indexed updates with operation type indicators
  - Sequential numbering for updates starting from #1
  - Visual operation type indicators (UPDATED, DELETED, CLEARED) with icons and colors
  - Enhanced update record display with operation context
* **NEW:** Added key rename functionality
  - Rename storage keys while preserving values
  - Two-step operation: delete old key → create new key with same value
  - Input validation and user-friendly dialogs
  - Purple-themed UI for rename operations
* **IMPROVED:** Enhanced UI with better visual hierarchy and color coding
* **IMPROVED:** Fixed deprecated `withOpacity` usage for better Flutter compatibility

## 0.1.1

* Fixed publishing error

## 0.1.0

* Initial release
* Added support for viewing Flutter Secure Storage values in real-time
* Added device grouping
* Added settings for customizing the display
* Added support for filtering null values
* Added support for showing newest entries on top
* Added support for clearing data on reload 