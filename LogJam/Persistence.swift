import Foundation
import SwiftData

@Model
final class WorkRecord {
    var id: UUID
    var categoryRawValue: String
    var title: String
    var creator: String
    @Attribute(.externalStorage) var coverData: Data?
    var createdAt: Date
    var modifiedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \EncounterRecord.work)
    var encounters: [EncounterRecord]

    init(
        id: UUID = UUID(),
        category: MediaCategory,
        title: String,
        creator: String,
        coverData: Data? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.categoryRawValue = category.rawValue
        self.title = title
        self.creator = creator
        self.coverData = coverData
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.encounters = []
    }

    var category: MediaCategory {
        MediaCategory(rawValue: categoryRawValue) ?? .film
    }
}

@Model
final class EncounterRecord {
    var id: UUID
    var date: Date
    var statusRawValue: String
    var rating: Double?
    var context: String
    var comment: String
    var detailsData: Data
    var createdAt: Date
    var modifiedAt: Date
    var work: WorkRecord?

    init(
        id: UUID = UUID(),
        date: Date,
        status: EntryStatus,
        rating: Double?,
        context: String,
        comment: String,
        details: [EntryDetail],
        work: WorkRecord?,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.statusRawValue = status.rawValue
        self.rating = rating
        self.context = context
        self.comment = comment
        self.detailsData = (try? JSONEncoder().encode(details)) ?? Data()
        self.work = work
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    var status: EntryStatus {
        EntryStatus(rawValue: statusRawValue) ?? .completed
    }

    var details: [EntryDetail] {
        (try? JSONDecoder().decode([EntryDetail].self, from: detailsData)) ?? []
    }

    var journalEntry: JournalEntry? {
        guard let work else { return nil }
        return JournalEntry(
            id: id,
            workID: work.id,
            category: work.category,
            title: work.title,
            creator: work.creator,
            date: date,
            status: status,
            rating: rating,
            context: context,
            comment: comment,
            details: details,
            coverData: work.coverData
        )
    }
}
