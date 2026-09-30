# Contributing to See Your Disk

Thanks for helping! This project is open to contributors.

## Getting started

1. Fork the repository and clone your fork.
2. Open `SeeYourDisk.xcodeproj` in Xcode 26+ and run the `SeeYourDisk` scheme (⌘R).
3. Create a branch from `development`: `git checkout -b feature/short-description development`.
4. Make your change, build, and try it on a real folder.
5. Open a pull request into `development` and describe what and why.

## Good first things to work on

- New cleanup rules (see `SeeYourDisk/Core/Cleanup.swift`): caches of other tools, browsers, IDEs
- Translations: add a language to `SeeYourDisk/Localizable.xcstrings`
- Scanner speed and accuracy (`SeeYourDisk/Core/DiskScanner.swift`)
- Duplicate-file detection for large files
- Accessibility and VoiceOver labels

## Guidelines

- **Safety first.** Cleanup rules must only touch data an app can regenerate. Anything else must be marked "Review" and go to the Trash, never be deleted directly.
- Keep the app local: no analytics, no network calls that send user data.
- Follow the surrounding code style; keep changes focused and small.
- All user-visible strings go into `Localizable.xcstrings` with English and Russian text.
- Do not commit signing certificates, provisioning profiles or App Store credentials.

## Reporting bugs

Open an issue with your macOS version, what you did and what you expected. For security or private questions write to lopol3000@gmail.com.
