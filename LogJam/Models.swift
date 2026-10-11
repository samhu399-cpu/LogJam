import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    func text(_ english: String, _ simplifiedChinese: String) -> String {
        self == .english ? english : simplifiedChinese
    }

    func fieldLabel(_ canonicalLabel: String) -> String {
        guard self == .simplifiedChinese else { return canonicalLabel }
        return switch canonicalLabel {
        case "Release year": "发行年份"
        case "Country of production": "制作国家或地区"
        case "Specific locations": "具体地点"
        case "MPAA rating": "MPAA 分级"
        case "Genre": "类型"
        case "Translator / editor": "译者 / 编辑"
        case "Publishing house": "出版社"
        case "Publication date": "出版日期"
        case "Performer": "演奏者"
        case "Movement(s)": "乐章"
        case "Catalogue / opus no.": "目录号 / 作品号"
        case "Conductor": "指挥"
        case "Ensemble": "乐团"
        case "Recording / performance": "录音 / 演出"
        case "Context": "情境"
        default: canonicalLabel
        }
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

enum MediaCategory: String, CaseIterable, Identifiable, Codable {
    case film = "Films"
    case book = "Books"
    case classical = "Classical"

    var id: Self { self }

    var singular: String {
        switch self {
        case .film: "Film"
        case .book: "Book"
        case .classical: "Classical music"
        }
    }

    func label(in language: AppLanguage) -> String {
        switch self {
        case .film: language.text("Films", "电影")
        case .book: language.text("Books", "书籍")
        case .classical: language.text("Classical", "古典音乐")
        }
    }

    func singular(in language: AppLanguage) -> String {
        switch self {
        case .film: language.text("Film", "电影")
        case .book: language.text("Book", "书籍")
        case .classical: language.text("Classical music", "古典音乐")
        }
    }

    var systemImage: String {
        switch self {
        case .film: "film"
        case .book: "book.closed"
        case .classical: "music.note"
        }
    }

    var tint: Color {
        switch self {
        case .film: Color(red: 0.64, green: 0.27, blue: 0.20)
        case .book: Color(red: 0.18, green: 0.36, blue: 0.31)
        case .classical: Color(red: 0.36, green: 0.29, blue: 0.52)
        }
    }
}

enum EntryStatus: String, CaseIterable, Identifiable, Codable {
    case completed = "Completed"
    case ongoing = "Ongoing"
    case sampled = "Sampled"
    case abandoned = "Abandoned"

    var id: Self { self }

    func label(in language: AppLanguage) -> String {
        switch self {
        case .completed: language.text("Completed", "已完成")
        case .ongoing: language.text("Ongoing", "进行中")
        case .sampled: language.text("Sampled", "体验过")
        case .abandoned: language.text("Abandoned", "已放弃")
        }
    }
}

enum LogMode: String, CaseIterable, Identifiable {
    case quick = "Quick"
    case detailed = "Detailed"

    var id: Self { self }

    func label(in language: AppLanguage) -> String {
        switch self {
        case .quick: language.text("Quick", "快速")
        case .detailed: language.text("Detailed", "详细")
        }
    }
}

struct EntryDetail: Identifiable, Hashable, Codable {
    let id: UUID
    var label: String
    var value: String

    init(id: UUID = UUID(), label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

struct JournalEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let workID: UUID
    var category: MediaCategory
    var title: String
    var creator: String
    var date: Date
    var status: EntryStatus
    var rating: Double?
    var context: String
    var comment: String
    var details: [EntryDetail]
    var coverData: Data?

    init(
        id: UUID = UUID(),
        workID: UUID = UUID(),
        category: MediaCategory,
        title: String,
        creator: String,
        date: Date,
        status: EntryStatus = .completed,
        rating: Double? = nil,
        context: String = "",
        comment: String = "",
        details: [EntryDetail] = [],
        coverData: Data? = nil
    ) {
        self.id = id
        self.workID = workID
        self.category = category
        self.title = title
        self.creator = creator
        self.date = date
        self.status = status
        self.rating = rating
        self.context = context
        self.comment = comment
        self.details = details
        self.coverData = coverData
    }

    var ratingText: String {
        guard let rating else { return "Unrated" }
        return rating.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct JournalArchive: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let entries: [JournalEntry]

    init(entries: [JournalEntry]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = .now
        self.entries = entries.sorted { $0.date > $1.date }
    }

    init(schemaVersion: Int, exportedAt: Date = .now, entries: [JournalEntry]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.entries = entries
    }

    var workCount: Int {
        Set(entries.map(\.workID)).count
    }
}

enum JournalArchiveError: LocalizedError, Equatable {
    case unreadableFile
    case unsupportedSchema(Int)
    case emptyArchive
    case duplicateEncounter
    case emptyTitle
    case invalidRating
    case inconsistentWork

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "The selected file is not a valid LogJam backup."
        case let .unsupportedSchema(version):
            "This backup uses unsupported schema version \(version)."
        case .emptyArchive:
            "This backup contains no encounters."
        case .duplicateEncounter:
            "This backup contains duplicate encounter identifiers."
        case .emptyTitle:
            "Every restored encounter must have a title."
        case .invalidRating:
            "A restored rating is outside LogJam's supported range."
        case .inconsistentWork:
            "Encounters for the same work contain conflicting work information."
        }
    }
}

enum JournalArchiveCodec {
    static func encode(_ archive: JournalArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> JournalArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let archive: JournalArchive
        do {
            archive = try decoder.decode(JournalArchive.self, from: data)
        } catch {
            throw JournalArchiveError.unreadableFile
        }

        try validate(archive)
        return archive
    }

    static func validate(_ archive: JournalArchive) throws {
        guard archive.schemaVersion == JournalArchive.currentSchemaVersion else {
            throw JournalArchiveError.unsupportedSchema(archive.schemaVersion)
        }
        guard !archive.entries.isEmpty else {
            throw JournalArchiveError.emptyArchive
        }
        guard Set(archive.entries.map(\.id)).count == archive.entries.count else {
            throw JournalArchiveError.duplicateEncounter
        }
        guard archive.entries.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw JournalArchiveError.emptyTitle
        }
        guard archive.entries.allSatisfy({ entry in
            guard let rating = entry.rating else { return true }
            return rating.isFinite && (0...11).contains(rating)
        }) else {
            throw JournalArchiveError.invalidRating
        }

        for encounters in Dictionary(grouping: archive.entries, by: \.workID).values {
            guard let first = encounters.first else { continue }
            let isConsistent = encounters.allSatisfy {
                $0.category == first.category &&
                $0.title == first.title &&
                $0.creator == first.creator &&
                $0.coverData == first.coverData
            }
            guard isConsistent else {
                throw JournalArchiveError.inconsistentWork
            }
        }
    }
}

struct JournalExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private var archiveData: Data

    init(entries: [JournalEntry] = []) {
        archiveData = (try? JournalArchiveCodec.encode(JournalArchive(entries: entries))) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        archiveData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: archiveData)
    }
}

struct WorkSummary: Identifiable, Hashable {
    let id: UUID
    var category: MediaCategory
    var title: String
    var creator: String
    var coverData: Data?
    var encounterCount: Int
    var latestEncounterDate: Date
}

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var persistenceError: String?

    private var modelContext: ModelContext?
    private var hasLoaded = false

    var works: [WorkSummary] {
        Dictionary(grouping: entries, by: \.workID)
            .compactMap { workID, encounters in
                guard let latest = encounters.max(by: { $0.date < $1.date }) else { return nil }
                return WorkSummary(
                    id: workID,
                    category: latest.category,
                    title: latest.title,
                    creator: latest.creator,
                    coverData: latest.coverData,
                    encounterCount: encounters.count,
                    latestEncounterDate: latest.date
                )
            }
            .sorted { $0.latestEncounterDate > $1.latestEncounterDate }
    }

    func encounters(for workID: UUID) -> [JournalEntry] {
        entries
            .filter { $0.workID == workID }
            .sorted { $0.date > $1.date }
    }

    func work(withID workID: UUID) -> WorkSummary? {
        works.first { $0.id == workID }
    }

    func entry(withID entryID: UUID) -> JournalEntry? {
        entries.first { $0.id == entryID }
    }

    func configure(with modelContext: ModelContext) {
        guard !hasLoaded else { return }
        hasLoaded = true
        self.modelContext = modelContext

        do {
            let descriptor = FetchDescriptor<EncounterRecord>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let savedEncounters = try modelContext.fetch(descriptor)
            entries = savedEncounters.compactMap(\.journalEntry)
        } catch {
            persistenceError = error.localizedDescription
            entries = []
        }
    }

    func add(_ entry: JournalEntry) {
        persistenceError = nil
        entries.insert(entry, at: 0)

        guard let modelContext else { return }
        let savedWorks = (try? modelContext.fetch(FetchDescriptor<WorkRecord>())) ?? []
        let work: WorkRecord
        if let existingWork = savedWorks.first(where: { $0.id == entry.workID }) {
            work = existingWork
            work.title = entry.title
            work.creator = entry.creator
            work.categoryRawValue = entry.category.rawValue
            work.coverData = entry.coverData
            work.modifiedAt = .now
        } else {
            work = WorkRecord(
                id: entry.workID,
                category: entry.category,
                title: entry.title,
                creator: entry.creator,
                coverData: entry.coverData
            )
            modelContext.insert(work)
        }
        let encounter = EncounterRecord(
            id: entry.id,
            date: entry.date,
            status: entry.status,
            rating: entry.rating,
            context: entry.context,
            comment: entry.comment,
            details: entry.details,
            work: work
        )
        modelContext.insert(encounter)

        do {
            try modelContext.save()
        } catch {
            persistenceError = error.localizedDescription
            modelContext.rollback()
            entries.removeAll { $0.id == entry.id }
        }
    }

    func update(_ entry: JournalEntry) {
        guard let original = entries.first(where: { $0.id == entry.id }) else { return }
        persistenceError = nil
        let previousEntries = entries

        entries = entries.map { savedEntry in
            if savedEntry.id == entry.id {
                return entry
            }

            guard original.workID == entry.workID, savedEntry.workID == entry.workID else {
                return savedEntry
            }

            var updatedEntry = savedEntry
            updatedEntry.category = entry.category
            updatedEntry.title = entry.title
            updatedEntry.creator = entry.creator
            updatedEntry.coverData = entry.coverData
            return updatedEntry
        }
        entries.sort { $0.date > $1.date }

        guard let modelContext else { return }

        do {
            let savedEncounters = try modelContext.fetch(FetchDescriptor<EncounterRecord>())
            let savedWorks = try modelContext.fetch(FetchDescriptor<WorkRecord>())
            guard let encounter = savedEncounters.first(where: { $0.id == entry.id }) else {
                entries = previousEntries
                return
            }

            let work: WorkRecord
            if let existingWork = savedWorks.first(where: { $0.id == entry.workID }) {
                work = existingWork
            } else {
                work = WorkRecord(
                    id: entry.workID,
                    category: entry.category,
                    title: entry.title,
                    creator: entry.creator,
                    coverData: entry.coverData
                )
                modelContext.insert(work)
            }

            work.title = entry.title
            work.creator = entry.creator
            work.categoryRawValue = entry.category.rawValue
            work.coverData = entry.coverData
            work.modifiedAt = .now

            encounter.date = entry.date
            encounter.statusRawValue = entry.status.rawValue
            encounter.rating = entry.rating
            encounter.context = entry.context
            encounter.comment = entry.comment
            encounter.detailsData = (try? JSONEncoder().encode(entry.details)) ?? Data()
            encounter.modifiedAt = .now
            encounter.work = work

            try modelContext.save()
        } catch {
            persistenceError = error.localizedDescription
            modelContext.rollback()
            entries = previousEntries
        }
    }

    @discardableResult
    func deleteEncounter(id entryID: UUID) -> Bool {
        guard let entry = entry(withID: entryID) else { return true }
        guard let modelContext else {
            entries.removeAll { $0.id == entryID }
            return true
        }

        persistenceError = nil
        do {
            let savedEncounters = try modelContext.fetch(FetchDescriptor<EncounterRecord>())
            guard let encounter = savedEncounters.first(where: { $0.id == entryID }) else {
                entries.removeAll { $0.id == entryID }
                return true
            }

            if encounters(for: entry.workID).count == 1, let work = encounter.work {
                modelContext.delete(work)
            } else {
                modelContext.delete(encounter)
            }

            try modelContext.save()
            entries.removeAll { $0.id == entryID }
            return true
        } catch {
            persistenceError = error.localizedDescription
            modelContext.rollback()
            return false
        }
    }

    @discardableResult
    func deleteWork(id workID: UUID) -> Bool {
        guard let modelContext else {
            entries.removeAll { $0.workID == workID }
            return true
        }

        persistenceError = nil
        do {
            let savedWorks = try modelContext.fetch(FetchDescriptor<WorkRecord>())
            if let work = savedWorks.first(where: { $0.id == workID }) {
                modelContext.delete(work)
                try modelContext.save()
            }
            entries.removeAll { $0.workID == workID }
            return true
        } catch {
            persistenceError = error.localizedDescription
            modelContext.rollback()
            return false
        }
    }

    @discardableResult
    func restore(from archive: JournalArchive) -> Bool {
        persistenceError = nil

        do {
            try JournalArchiveCodec.validate(archive)
        } catch {
            persistenceError = error.localizedDescription
            return false
        }

        guard let modelContext else {
            persistenceError = "The journal store is not ready."
            return false
        }

        let previousEntries = entries
        do {
            let savedEncounters = try modelContext.fetch(FetchDescriptor<EncounterRecord>())
            let savedWorks = try modelContext.fetch(FetchDescriptor<WorkRecord>())
            savedEncounters.forEach(modelContext.delete)
            savedWorks.forEach(modelContext.delete)

            for (workID, encounters) in Dictionary(grouping: archive.entries, by: \.workID) {
                guard let representative = encounters.max(by: { $0.date < $1.date }) else { continue }
                let work = WorkRecord(
                    id: workID,
                    category: representative.category,
                    title: representative.title,
                    creator: representative.creator,
                    coverData: representative.coverData
                )
                modelContext.insert(work)

                for entry in encounters {
                    modelContext.insert(EncounterRecord(
                        id: entry.id,
                        date: entry.date,
                        status: entry.status,
                        rating: entry.rating,
                        context: entry.context,
                        comment: entry.comment,
                        details: entry.details,
                        work: work
                    ))
                }
            }

            try modelContext.save()
            entries = archive.entries.sorted { $0.date > $1.date }
            return true
        } catch {
            modelContext.rollback()
            entries = previousEntries
            persistenceError = error.localizedDescription
            return false
        }
    }

    func clearPersistenceError() {
        persistenceError = nil
    }
}
