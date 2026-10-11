# Contributing to LogJam

Thank you for helping improve LogJam.

## Before opening a change

- Keep the journal local-first and usable without an account.
- Preserve both English and Simplified Chinese interfaces when changing user-facing text.
- Keep film, book, and classical music behavior consistent unless a difference is intentional.
- Avoid adding analytics, advertising, or network dependencies without prior discussion.
- Open an issue before beginning a large feature or changing the data model or backup schema.

## Build and test

1. Open `LogJam.xcodeproj` in Xcode.
2. Select the shared `LogJam` scheme.
3. Run the app in an iPhone simulator.
4. Run **Product > Test** (`Command-U`).

Before submitting a pull request, test the affected flow in English and Simplified Chinese. Changes to persistence or backups should include a focused unit test and remain compatible with existing schema-version-1 backups unless a documented migration is included.

## Pull requests

Keep pull requests focused. Explain the user-facing behavior, testing performed, and any data-migration or privacy implications. Do not include Xcode user state, build products, signing certificates, provisioning profiles, or personal bundle identifiers.
