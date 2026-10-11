# LogJam

[简体中文](README.zh-Hans.md)

LogJam is a private, local-first iPhone journal for films, books, and classical music. It is designed to record personal encounters with a work rather than build another catalogue, recommendation service, or social network.

The app is free and open source. It has no account system, advertising, analytics, cloud service, or in-app purchases.

## What it includes

- Film, book, and classical-music journals
- Quick and detailed logging templates
- Repeat viewings, readings, and listening encounters attached to one work
- Editable and deletable encounters
- Searchable home and library views
- Optional cover photos with distortion-free cropping
- Generated category artwork when no cover is selected
- Ten-point ratings with two decimal places and a hidden value of 11
- English and Simplified Chinese interfaces
- Local SwiftData persistence
- Versioned JSON backup and restore, including cover images
- Seven archive and restore unit tests

## Requirements

- A Mac capable of running Xcode
- Xcode 26.6 or a compatible newer release
- iOS 17 or later for a physical iPhone

No paid Apple Developer Program membership is required to build the app in the simulator or install it on your own iPhone with a Personal Team.

## Run in the simulator

1. Clone or download this repository.
2. Open `LogJam.xcodeproj` in Xcode.
3. Select the `LogJam` scheme and an iPhone simulator.
4. Press **Run** (`Command-R`).

## Install on your own iPhone for free

1. In Xcode, open **Settings > Accounts** and sign in with your Apple Account.
2. Select the `LogJam` target, then **Signing & Capabilities**.
3. Choose your Personal Team.
4. Replace `com.example.LogJam` with a bundle identifier unique to you, such as `com.yourname.LogJam`.
5. Connect your iPhone, select it as the run destination, and press **Run**.

Apple's free Personal Team provisioning expires periodically, so Xcode may require you to rebuild and reinstall the app. Export your journal from Settings before reinstalling or making changes that may remove the app's local data.

## Data and privacy

LogJam stores journal data on the device using SwiftData. It does not make network requests or send analytics. A photo is imported only after the user selects it, and a backup leaves the app only when the user explicitly exports it.

Backups can contain journal text and the full data of selected cover images. Treat exported `.json` files as private personal data. See [PRIVACY.md](PRIVACY.md) for the full project privacy statement.

## Repository layout

```text
LogJam/
├── LogJam.xcodeproj/       Xcode project and shared scheme
├── LogJam/                 App source
│   ├── LogJamApp.swift
│   ├── Models.swift
│   ├── Persistence.swift
│   └── Views.swift
└── LogJamTests/            Archive and restore tests
```

## Product scope

Version 1.0 is deliberately local and iPhone-only. Accounts, social features, metadata lookup, CloudKit sync, additional media categories, and iPad-specific layouts are not part of the current scope.

The Rooms tab is experimental. Home is the browsing timeline, while Library is the work-oriented space for repeat encounters.

For an overview of the Work/Encounter model and persistence boundaries, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Contributing

Bug reports, wording improvements, accessibility fixes, and focused pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

LogJam is available under the [MIT License](LICENSE).
