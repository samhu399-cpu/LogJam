import SwiftData
import XCTest
@testable import LogJam

final class JournalArchiveTests: XCTestCase {
    func testRoundTripPreservesEveryEntryFieldAndCover() throws {
        let entries = sampleEntries()
        let original = JournalArchive(
            schemaVersion: JournalArchive.currentSchemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_800_000_000),
            entries: entries
        )

        let data = try JournalArchiveCodec.encode(original)
        let restored = try JournalArchiveCodec.decode(data)

        XCTAssertEqual(restored.schemaVersion, JournalArchive.currentSchemaVersion)
        XCTAssertEqual(restored.exportedAt, original.exportedAt)
        XCTAssertEqual(restored.entries, entries)
        XCTAssertEqual(restored.workCount, 2)
    }

    func testRejectsFutureSchemaBeforeChangingJournal() throws {
        let archive = JournalArchive(schemaVersion: 99, entries: sampleEntries())

        XCTAssertThrowsError(try JournalArchiveCodec.validate(archive)) { error in
            XCTAssertEqual(error as? JournalArchiveError, .unsupportedSchema(99))
        }
    }

    func testRejectsDuplicateEncounterIdentifiers() throws {
        let entry = sampleEntries()[0]
        let archive = JournalArchive(schemaVersion: 1, entries: [entry, entry])

        XCTAssertThrowsError(try JournalArchiveCodec.validate(archive)) { error in
            XCTAssertEqual(error as? JournalArchiveError, .duplicateEncounter)
        }
    }

    func testRejectsRatingAboveHiddenElevenPointLimit() throws {
        var entry = sampleEntries()[0]
        entry.rating = 11.01
        let archive = JournalArchive(schemaVersion: 1, entries: [entry])

        XCTAssertThrowsError(try JournalArchiveCodec.validate(archive)) { error in
            XCTAssertEqual(error as? JournalArchiveError, .invalidRating)
        }
    }

    func testRejectsConflictingMetadataForOneWork() throws {
        var entries = Array(sampleEntries().prefix(2))
        entries[1].title = "A conflicting title"
        let archive = JournalArchive(schemaVersion: 1, entries: entries)

        XCTAssertThrowsError(try JournalArchiveCodec.validate(archive)) { error in
            XCTAssertEqual(error as? JournalArchiveError, .inconsistentWork)
        }
    }

    @MainActor
    func testRestoreReplacesExistingDataAndCreatesNoEmptyWorks() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkRecord.self,
            EncounterRecord.self,
            configurations: configuration
        )
        let store = JournalStore()
        store.configure(with: container.mainContext)
        store.add(JournalEntry(
            category: .film,
            title: "Old journal entry",
            creator: "Old creator",
            date: .distantPast
        ))

        let archive = JournalArchive(entries: sampleEntries())
        XCTAssertTrue(store.restore(from: archive))

        XCTAssertEqual(store.entries, archive.entries.sorted { $0.date > $1.date })
        XCTAssertEqual(store.works.count, 2)
        XCTAssertEqual(store.encounters(for: archive.entries[0].workID).count, 2)

        let persistedWorks = try container.mainContext.fetch(FetchDescriptor<WorkRecord>())
        let persistedEncounters = try container.mainContext.fetch(FetchDescriptor<EncounterRecord>())
        XCTAssertEqual(persistedWorks.count, 2)
        XCTAssertEqual(persistedEncounters.count, 3)
        XCTAssertTrue(persistedWorks.allSatisfy { !$0.encounters.isEmpty })
        XCTAssertFalse(persistedWorks.contains { $0.title == "Old journal entry" })
    }

    @MainActor
    func testInvalidRestoreLeavesExistingJournalUnchanged() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkRecord.self,
            EncounterRecord.self,
            configurations: configuration
        )
        let store = JournalStore()
        store.configure(with: container.mainContext)
        let existing = JournalEntry(
            category: .book,
            title: "Keep me",
            creator: "Existing author",
            date: .now
        )
        store.add(existing)

        var invalid = sampleEntries()[0]
        invalid.rating = .infinity
        XCTAssertFalse(store.restore(from: JournalArchive(schemaVersion: 1, entries: [invalid])))
        XCTAssertEqual(store.entries, [existing])

        let persistedWorks = try container.mainContext.fetch(FetchDescriptor<WorkRecord>())
        XCTAssertEqual(persistedWorks.map(\.title), ["Keep me"])
    }

    private func sampleEntries() -> [JournalEntry] {
        let filmWorkID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let cover = Data([0x01, 0x02, 0x03, 0x04])
        return [
            JournalEntry(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                workID: filmWorkID,
                category: .film,
                title: "In the Mood for Love",
                creator: "Wong Kar-wai",
                date: Date(timeIntervalSince1970: 1_790_000_000),
                status: .completed,
                rating: 11,
                context: "Cinema",
                comment: "A first encounter.",
                details: [EntryDetail(label: "Release year", value: "2000")],
                coverData: cover
            ),
            JournalEntry(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                workID: filmWorkID,
                category: .film,
                title: "In the Mood for Love",
                creator: "Wong Kar-wai",
                date: Date(timeIntervalSince1970: 1_795_000_000),
                status: .completed,
                rating: 9.75,
                context: "At home",
                comment: "A rewatch.",
                details: [EntryDetail(label: "Release year", value: "2000")],
                coverData: cover
            ),
            JournalEntry(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                workID: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                category: .book,
                title: "The Waves",
                creator: "Virginia Woolf",
                date: Date(timeIntervalSince1970: 1_792_000_000),
                status: .ongoing,
                rating: 8.25,
                context: "Train",
                comment: "",
                details: [EntryDetail(label: "Publishing house", value: "Hogarth Press")]
            )
        ]
    }
}
