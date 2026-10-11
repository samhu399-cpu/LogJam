# Architecture

## Product model

LogJam separates a cultural work from an encounter with that work.

- `WorkRecord` stores stable work-level information such as category, title, creator, and cover.
- `EncounterRecord` stores one viewing, reading, or listening experience, including date, status, rating, context, comment, and detailed fields.
- One work can own many encounters. Removing a whole work cascades to its encounters; removing the last encounter also removes the now-empty work after confirmation.

The app-facing `JournalEntry` value type is the portable representation used by forms and archive operations. Persistence maps between that value and SwiftData records.

## Persistence boundary

`Persistence.swift` owns SwiftData records and conversion logic. `Models.swift` owns portable domain values, language/category definitions, archive encoding, and archive validation. `Views.swift` owns the current SwiftUI interface and its form state.

The archive format is versioned. A restore is decoded and fully validated before existing records are changed. Invalid input must leave the current journal intact.

## Privacy boundary

Version 1.0 has no server, account, analytics, advertising, or network client. Data leaves the app only through an explicit backup export. Any future networking feature should be discussed as a product, privacy, and architecture change rather than added as an incidental dependency.

## Localization

The current interface uses the persisted `AppLanguage` setting and explicit English/Simplified Chinese text pairs. New user-visible strings and logging fields must be checked in both languages.
