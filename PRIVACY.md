# Privacy

LogJam is designed as a local, private journal.

## Data stored by the app

The app stores journal entries, work information, ratings, comments, settings, and user-selected cover images locally on the device with SwiftData.

## Data collection and transmission

The current project:

- does not require an account;
- does not contain advertising or analytics SDKs;
- does not track users;
- does not make network requests;
- does not transmit journal data to the project maintainers.

The system photo picker provides an image only after the user explicitly selects it. The app does not scan or upload the photo library.

## Backup files

The user may explicitly export a JSON backup from Settings. A backup includes journal text and the data of selected cover images. The user chooses where that file is saved or shared and is responsible for protecting it.

Restoring a valid backup replaces the current local journal only after an explicit confirmation.

## Forks and modified builds

This statement describes the source code in this repository. A third-party fork may add networking, analytics, or other behavior. Review a fork's source and privacy statement before installing it.
