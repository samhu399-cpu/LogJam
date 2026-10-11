import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ComposerRequest: Identifiable {
    let id = UUID()
    var work: WorkSummary?
    var entry: JournalEntry?
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = JournalStore()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var composerRequest: ComposerRequest?
    @State private var showingSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(composerRequest: $composerRequest, showingSettings: $showingSettings)
            }
            .tabItem { Label(appLanguage.text("Home", "首页"), systemImage: "clock") }

            NavigationStack {
                LibraryView(composerRequest: $composerRequest)
            }
            .tabItem { Label(appLanguage.text("Library", "库"), systemImage: "books.vertical") }

            NavigationStack {
                RoomsView(composerRequest: $composerRequest)
            }
            .tabItem { Label(appLanguage.text("Rooms", "房间"), systemImage: "square.grid.2x2") }
        }
        .environmentObject(store)
        .environment(\.appLanguage, appLanguage)
        .environment(\.locale, appLanguage.locale)
        .tint(Color(red: 0.18, green: 0.16, blue: 0.13))
        .sheet(item: $composerRequest) { request in
            ComposeEntryView(
                existingWorks: store.works,
                initialWork: request.work,
                initialEntry: request.entry
            ) { entry in
                if request.entry == nil {
                    store.add(entry)
                } else {
                    store.update(entry)
                }
            }
            // Sheets are presented outside the TabView's environment subtree.
            // Pass the chosen app language explicitly so the logging form stays
            // in sync with the display pages.
            .environment(\.appLanguage, appLanguage)
            .environment(\.locale, appLanguage.locale)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(language: $appLanguage)
                .environmentObject(store)
        }
        .task {
            store.configure(with: modelContext)
        }
        .alert(
            appLanguage.text("Something went wrong", "出现了一些问题"),
            isPresented: Binding(
                get: { store.persistenceError != nil },
                set: { isPresented in
                    if !isPresented { store.clearPersistenceError() }
                }
            )
        ) {
            Button(appLanguage.text("OK", "好")) {
                store.clearPersistenceError()
            }
        } message: {
            Text(
                appLanguage.text(
                    "LogJam could not finish that change. Your journal was left as it was.\n\n",
                    "LogJam 无法完成这项更改，你的日志已保持原状。\n\n"
                ) + (store.persistenceError ?? "")
            )
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.appLanguage) private var language
    @Binding var composerRequest: ComposerRequest?
    @Binding var showingSettings: Bool
    @State private var filter: MediaCategory?

    private var visibleEntries: [JournalEntry] {
        store.entries
            .filter { filter == nil || $0.category == filter }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language.text("YOUR CULTURAL LIFE, REMEMBERED", "记住你的文化生活"))
                        .font(.caption2.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)
                    Text(language.text("A journal of\nclose encounters.", "记录每一次相遇。"))
                        .font(.system(.largeTitle, design: .serif, weight: .medium))
                    Text(language.text(
                        "Films that changed the weather of an evening. Books that stayed open in the mind. Music that rearranged a room.",
                        "那些伴随夜晚的电影，仍在脑海中翻动的书，以及萦绕在房间里的音乐。"
                    ))
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                if store.entries.isEmpty {
                    JournalEmptyState(
                        systemImage: "sparkles.rectangle.stack",
                        title: language.text("Your journal begins here", "从这里开始你的日志"),
                        message: language.text(
                            "Record a film, book, or piece of classical music you want to remember.",
                            "记录一部想要记住的电影、一本书，或一段古典音乐。"
                        ),
                        buttonTitle: language.text("Log your first encounter", "记录第一次相遇")
                    ) {
                        composerRequest = ComposerRequest()
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            FilterButton(language.text("All", "全部"), active: filter == nil) { filter = nil }
                            ForEach(MediaCategory.allCases) { category in
                                FilterButton(category.label(in: language), active: filter == category) { filter = category }
                            }
                        }
                    }

                    ForEach(visibleEntries) { entry in
                        NavigationLink {
                            EntryDetailView(entryID: entry.id, composerRequest: $composerRequest)
                        } label: {
                            TimelineEntryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("LogJam")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(language.text("Settings", "设置"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { composerRequest = ComposerRequest() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(language.text("Log encounter", "添加相遇"))
            }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.appLanguage) private var language
    @Binding var composerRequest: ComposerRequest?
    @State private var query = ""
    @State private var filter: MediaCategory?

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 18)]

    private var visibleWorks: [WorkSummary] {
        store.works.filter { work in
            let matchesCategory = filter == nil || work.category == filter
            let encounters = store.encounters(for: work.id)
            let haystack = ([work.title, work.creator] + encounters.flatMap { encounter in
                [encounter.comment, encounter.context] + encounter.details.flatMap { [$0.label, $0.value] }
            }).joined(separator: " ")
            return matchesCategory && (query.isEmpty || haystack.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(language.text("Browse the works first; unfold the memories inside.", "先浏览作品，再展开记忆。"))
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)

                if store.works.isEmpty {
                    JournalEmptyState(
                        systemImage: "books.vertical",
                        title: language.text("No works yet", "还没有作品"),
                        message: language.text(
                            "Works appear here automatically after you log an encounter.",
                            "记录一次相遇后，作品会自动出现在这里。"
                        ),
                        buttonTitle: language.text("Log an encounter", "记录一次相遇")
                    ) {
                        composerRequest = ComposerRequest()
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            FilterButton(language.text("All works", "全部作品"), active: filter == nil) { filter = nil }
                            ForEach(MediaCategory.allCases) { category in
                                FilterButton(category.label(in: language), active: filter == category) { filter = category }
                            }
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(visibleWorks) { work in
                            NavigationLink {
                                WorkDetailView(workID: work.id, composerRequest: $composerRequest)
                            } label: {
                                LibraryTile(work: work)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(language.text("Library", "库"))
        .searchable(text: $query, prompt: language.text("Find a work", "搜索作品"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { composerRequest = ComposerRequest() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(language.text("Log encounter", "添加相遇"))
            }
        }
    }
}

struct RoomsView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.appLanguage) private var language
    @Binding var composerRequest: ComposerRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(language.text("EXPERIMENTAL CATEGORY OVERVIEW", "实验性分类总览"))
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(language.text("What has moved you?", "什么曾打动你？"))
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                Text(language.text(
                    "A visual doorway into each collection.",
                    "每个收藏的一扇视觉入口"
                ))
                    .foregroundStyle(.secondary)

                if store.entries.isEmpty {
                    JournalEmptyState(
                        systemImage: "square.grid.2x2",
                        title: language.text("Your rooms are waiting", "你的房间正在等待"),
                        message: language.text(
                            "Each collection will take shape as your journal grows.",
                            "随着日志逐渐丰富，每个收藏也会慢慢成形。"
                        ),
                        buttonTitle: language.text("Add the first entry", "添加第一条记录")
                    ) {
                        composerRequest = ComposerRequest()
                    }
                } else {
                    ForEach(MediaCategory.allCases) { category in
                        let entries = store.entries.filter { $0.category == category }
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(category.label(in: language), systemImage: category.systemImage)
                                    .font(.system(.title2, design: .serif, weight: .semibold))
                                Spacer()
                                Text("\(entries.count)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(.thinMaterial, in: .capsule)
                            }
                            ForEach(entries.prefix(3)) { entry in
                                NavigationLink {
                                    EntryDetailView(entryID: entry.id, composerRequest: $composerRequest)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(entry.title).font(.headline)
                                            Text(entry.creator).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(entry.date, format: .dateTime.day().month(.abbreviated))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .foregroundStyle(.white)
                        .background(category.tint.gradient, in: .rect(cornerRadius: 22))
                    }
                }
            }
            .padding()
        }
        .navigationTitle(language.text("Rooms · Lab", "房间 · 实验"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { composerRequest = ComposerRequest() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(language.text("Log encounter", "添加相遇"))
            }
        }
    }
}

private struct RestoreNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: JournalStore
    @Binding var language: AppLanguage
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingRestoreConfirmation = false
    @State private var exportDocument = JournalExportDocument()
    @State private var pendingArchive: JournalArchive?
    @State private var restoreNotice: RestoreNotice?

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("Language", "语言")) {
                    Picker(language.text("App language", "应用语言"), selection: $language) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button {
                        exportDocument = JournalExportDocument(entries: store.entries)
                        showingExporter = true
                    } label: {
                        Label(language.text("Export journal", "导出日志"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.entries.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label(language.text("Restore from backup", "从备份恢复"), systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text(language.text("Data", "数据"))
                } footer: {
                    Text(language.text(
                        "Export saves every encounter and cover image. Restore validates a LogJam JSON backup, then replaces the journal on this device only after you confirm.",
                        "导出会保存全部相遇记录及封面图片。恢复功能会先验证 LogJam JSON 备份，并仅在你确认后替换此设备上的日志。"
                    ))
                }
            }
            .navigationTitle(language.text("Settings", "设置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(language.text("Close settings", "关闭设置"))
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { _ in }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                prepareRestore(from: result)
            }
            .confirmationDialog(
                language.text("Replace this journal?", "替换当前日志？"),
                isPresented: $showingRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button(language.text("Replace and restore", "替换并恢复"), role: .destructive) {
                    restorePendingArchive()
                }
                Button(language.text("Cancel", "取消"), role: .cancel) {
                    pendingArchive = nil
                }
            } message: {
                if let pendingArchive {
                    Text(language.text(
                        "This backup contains \(pendingArchive.entries.count) encounters across \(pendingArchive.workCount) works. Your current journal will be replaced. This cannot be undone unless you exported it first.",
                        "此备份包含 \(pendingArchive.workCount) 个作品及 \(pendingArchive.entries.count) 条相遇记录。当前日志将被替换；除非事先已导出，否则无法撤销。"
                    ))
                }
            }
            .alert(item: $restoreNotice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    dismissButton: .default(Text(language.text("OK", "好")))
                )
            }
        }
    }

    private var exportFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day())
        return "LogJam-Journal-\(date)"
    }

    private func prepareRestore(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityAccess { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            pendingArchive = try JournalArchiveCodec.decode(data)
            showingRestoreConfirmation = true
        } catch {
            pendingArchive = nil
            restoreNotice = RestoreNotice(
                title: language.text("Could not read backup", "无法读取备份"),
                message: localizedArchiveError(error)
            )
        }
    }

    private func restorePendingArchive() {
        guard let archive = pendingArchive else { return }
        pendingArchive = nil

        if store.restore(from: archive) {
            restoreNotice = RestoreNotice(
                title: language.text("Journal restored", "日志已恢复"),
                message: language.text(
                    "Restored \(archive.entries.count) encounters across \(archive.workCount) works.",
                    "已恢复 \(archive.workCount) 个作品及 \(archive.entries.count) 条相遇记录。"
                )
            )
        } else {
            let detail = store.persistenceError ?? language.text("The journal was left unchanged.", "当前日志未被更改。")
            store.clearPersistenceError()
            restoreNotice = RestoreNotice(
                title: language.text("Restore failed", "恢复失败"),
                message: detail
            )
        }
    }

    private func localizedArchiveError(_ error: Error) -> String {
        guard let archiveError = error as? JournalArchiveError else {
            return language.text(
                "LogJam could not open this file. Your journal was left unchanged.",
                "LogJam 无法打开此文件，当前日志未被更改。"
            )
        }

        return switch archiveError {
        case .unreadableFile:
            language.text("The selected file is not a valid LogJam backup.", "所选文件不是有效的 LogJam 备份。")
        case let .unsupportedSchema(version):
            language.text(
                "This backup uses unsupported schema version \(version).",
                "此备份使用了不受支持的结构版本 \(version)。"
            )
        case .emptyArchive:
            language.text("This backup contains no encounters.", "此备份中没有相遇记录。")
        case .duplicateEncounter:
            language.text("This backup contains duplicate encounters.", "此备份包含重复的相遇记录。")
        case .emptyTitle:
            language.text("An encounter in this backup has no title.", "此备份中有一条相遇记录没有标题。")
        case .invalidRating:
            language.text("A rating in this backup is outside the supported range.", "此备份中有一项评分超出支持范围。")
        case .inconsistentWork:
            language.text(
                "Encounters for the same work contain conflicting information.",
                "同一作品的多条相遇记录包含相互冲突的信息。"
            )
        }
    }
}

struct JournalEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
    }
}

struct ComposeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    let existingWorks: [WorkSummary]
    let initialWork: WorkSummary?
    let initialEntry: JournalEntry?
    let onSave: (JournalEntry) -> Void

    @State private var category: MediaCategory = .film
    @State private var selectedWork: WorkSummary?
    @State private var mode: LogMode = .quick
    @State private var title = ""
    @State private var creator = ""
    @State private var date = Date.now
    @State private var status: EntryStatus = .completed
    @State private var ratingText = ""
    @State private var context = ""
    @State private var comment = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverData: Data?

    @State private var releaseYear = ""
    @State private var productionCountry = ""
    @State private var specificLocations = ""
    @State private var mpaaRating = ""
    @State private var genre = ""

    @State private var translatorEditor = ""
    @State private var publishingHouse = ""
    @State private var publicationDate = ""

    @State private var performer = ""
    @State private var movements = ""
    @State private var catalogueNumber = ""
    @State private var conductor = ""
    @State private var ensemble = ""
    @State private var recording = ""

    private let mpaaOptions = ["", "G", "PG", "PG-13", "R", "NC-17", "Unrated"]

    init(
        existingWorks: [WorkSummary],
        initialWork: WorkSummary? = nil,
        initialEntry: JournalEntry? = nil,
        onSave: @escaping (JournalEntry) -> Void
    ) {
        self.existingWorks = existingWorks
        self.initialWork = initialWork
        self.initialEntry = initialEntry
        self.onSave = onSave
        _category = State(initialValue: initialEntry?.category ?? initialWork?.category ?? .film)
        _selectedWork = State(initialValue: initialWork)
        _mode = State(initialValue: initialEntry?.details.isEmpty == false ? .detailed : .quick)
        _title = State(initialValue: initialEntry?.title ?? initialWork?.title ?? "")
        _creator = State(initialValue: initialEntry?.creator ?? initialWork?.creator ?? "")
        _date = State(initialValue: initialEntry?.date ?? .now)
        _status = State(initialValue: initialEntry?.status ?? .completed)
        _ratingText = State(initialValue: initialEntry?.rating?.formatted(.number.precision(.fractionLength(0...2))) ?? "")
        _context = State(initialValue: initialEntry?.context ?? "")
        _comment = State(initialValue: initialEntry?.comment ?? "")
        _coverData = State(initialValue: initialEntry?.coverData ?? initialWork?.coverData)

        _releaseYear = State(initialValue: Self.detailValue("Release year", in: initialEntry))
        _productionCountry = State(initialValue: Self.detailValue("Country of production", in: initialEntry))
        _specificLocations = State(initialValue: Self.detailValue("Specific locations", in: initialEntry))
        _mpaaRating = State(initialValue: Self.detailValue("MPAA rating", in: initialEntry))
        _genre = State(initialValue: Self.detailValue("Genre", in: initialEntry))
        _translatorEditor = State(initialValue: Self.detailValue("Translator / editor", in: initialEntry))
        _publishingHouse = State(initialValue: Self.detailValue("Publishing house", in: initialEntry))
        _publicationDate = State(initialValue: Self.detailValue("Publication date", in: initialEntry))
        _performer = State(initialValue: Self.detailValue("Performer", in: initialEntry))
        _movements = State(initialValue: Self.detailValue("Movement(s)", in: initialEntry))
        _catalogueNumber = State(initialValue: Self.detailValue("Catalogue / opus no.", in: initialEntry))
        _conductor = State(initialValue: Self.detailValue("Conductor", in: initialEntry))
        _ensemble = State(initialValue: Self.detailValue("Ensemble", in: initialEntry))
        _recording = State(initialValue: Self.detailValue("Recording / performance", in: initialEntry))
    }

    private var workMatches: [WorkSummary] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard selectedWork == nil, !trimmedTitle.isEmpty else { return [] }
        return existingWorks
            .filter {
                $0.category == category &&
                ($0.title.localizedCaseInsensitiveContains(trimmedTitle) ||
                 $0.creator.localizedCaseInsensitiveContains(trimmedTitle))
            }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(language.text("Category", "类别"), selection: $category) {
                        ForEach(MediaCategory.allCases) { category in
                            Text(category.label(in: language)).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(language.text("Template", "模板"), selection: $mode) {
                        ForEach(LogMode.allCases) { mode in
                            Text(mode.label(in: language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(language.text("The work", "作品")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 14) {
                            CoverArtwork(category: category, imageData: coverData)
                                .frame(width: 58, height: 74)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.text("Entry cover photo", "记录封面"))
                                Text(language.text("Choose any image, or keep the generated pattern.", "选择任意图片，或保留生成的图案。"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) { _, item in
                        Task {
                            coverData = try? await item?.loadTransferable(type: Data.self)
                        }
                    }

                    TextField(category == .classical ? language.text("Work title", "作品标题") : language.text("Title", "标题"), text: $title)
                    TextField(creatorLabel, text: $creator)

                    if let selectedWork {
                        HStack {
                            Label(
                                initialEntry == nil
                                    ? language.text("Adding another encounter", "正在添加新的相遇记录")
                                    : language.text("Editing this encounter", "正在编辑此记录"),
                                systemImage: initialEntry == nil ? "arrow.clockwise" : "pencil"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(category.tint)
                            Spacer()
                            if initialEntry == nil {
                                Button(language.text("Change", "更换")) {
                                    clearSelectedWork()
                                }
                                .font(.caption.weight(.semibold))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(selectedWork.title)
                    } else if !workMatches.isEmpty {
                        Text(language.text("FROM YOUR LIBRARY", "来自你的收藏"))
                            .font(.caption2.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                        ForEach(workMatches) { work in
                            Button {
                                select(work)
                            } label: {
                                HStack(spacing: 10) {
                                    CoverArtwork(category: work.category, imageData: work.coverData)
                                        .frame(width: 34, height: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(work.title)
                                            .foregroundStyle(.primary)
                                        Text("\(work.creator) · \(encounterCountText(work.encounterCount))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if category == .classical {
                        TextField(language.text("Performer", "演奏者"), text: $performer)
                        TextField(language.text("Movement(s)", "乐章"), text: $movements, prompt: Text(language.text("e.g. Variation 25", "例如：变奏 25")))
                    }

                    if mode == .detailed {
                        detailedFields
                    }
                }

                Section(language.text("Your encounter", "你的体验")) {
                    DatePicker(dateLabel, selection: $date, displayedComponents: .date)
                    Picker(language.text("Status", "状态"), selection: $status) {
                        ForEach(EntryStatus.allCases) { status in
                            Text(status.label(in: language)).tag(status)
                        }
                    }
                    TextField(language.text("My rating", "我的评分"), text: $ratingText)
                        .keyboardType(.decimalPad)
                        .onChange(of: ratingText) { oldValue, newValue in
                            ratingText = ratingInput(from: newValue, fallback: oldValue)
                        }
                    Text(language.text("Up to two decimal places", "最多保留两位小数"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(language.text("Context", "情境"), text: $context, prompt: Text(language.text("One Liner", "相遇简记")))
                    TextField(language.text("Your comment", "你的评论"), text: $comment, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Label(
                            initialEntry == nil
                                ? language.text("Save encounter", "保存记录")
                                : language.text("Save changes", "保存修改"),
                            systemImage: "checkmark"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(
                initialEntry == nil
                    ? language.text("New encounter", "新记录")
                    : language.text("Edit encounter", "编辑记录")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(language.text("Cancel", "取消"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Image(systemName: "checkmark") }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel(language.text("Save encounter", "保存记录"))
                }
            }
        }
        .onChange(of: category) { _, newCategory in
            if initialEntry == nil, selectedWork?.category != newCategory {
                clearSelectedWork()
            }
        }
    }

    @ViewBuilder
    private var detailedFields: some View {
        switch category {
        case .film:
            TextField(language.text("Release year", "发行年份"), text: $releaseYear)
                .keyboardType(.numberPad)
            TextField(language.text("Country of production", "制作国家或地区"), text: $productionCountry)
            TextField(language.text("Specific locations", "具体地点"), text: $specificLocations)
            Picker(language.text("MPAA rating", "MPAA 分级"), selection: $mpaaRating) {
                ForEach(mpaaOptions, id: \.self) { option in
                    Text(option.isEmpty ? "—" : option).tag(option)
                }
            }
            TextField(language.text("Genre", "类型"), text: $genre)
        case .book:
            TextField(language.text("Translator / editor", "译者 / 编辑"), text: $translatorEditor)
            TextField(language.text("Publishing house", "出版社"), text: $publishingHouse)
            TextField(language.text("Publication date", "出版日期"), text: $publicationDate)
            TextField(language.text("Genre", "类型"), text: $genre)
        case .classical:
            TextField(language.text("Catalogue / opus no.", "目录号 / 作品号"), text: $catalogueNumber)
            TextField(language.text("Conductor", "指挥"), text: $conductor)
            TextField(language.text("Ensemble", "乐团"), text: $ensemble)
            TextField(language.text("Recording / performance", "录音 / 演出"), text: $recording)
        }
    }

    private var creatorLabel: String {
        switch category {
        case .film: language.text("Director", "导演")
        case .book: language.text("Author", "作者")
        case .classical: language.text("Composer", "作曲家")
        }
    }

    private var dateLabel: String {
        switch category {
        case .film: language.text("Watched on", "观看日期")
        case .book: language.text("Read on", "阅读日期")
        case .classical: language.text("Listened on", "聆听日期")
        }
    }

    private func save() {
        let detailPairs: [(String, String)]
        switch category {
        case .film:
            detailPairs = [
                ("Release year", releaseYear),
                ("Country of production", productionCountry),
                ("Specific locations", specificLocations),
                ("MPAA rating", mpaaRating),
                ("Genre", genre)
            ]
        case .book:
            detailPairs = [
                ("Translator / editor", translatorEditor),
                ("Publishing house", publishingHouse),
                ("Publication date", publicationDate),
                ("Genre", genre)
            ]
        case .classical:
            detailPairs = [
                ("Performer", performer),
                ("Movement(s)", movements),
                ("Catalogue / opus no.", catalogueNumber),
                ("Conductor", conductor),
                ("Ensemble", ensemble),
                ("Recording / performance", recording)
            ]
        }

        let details = detailPairs
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { EntryDetail(label: $0.0, value: $0.1) }

        onSave(JournalEntry(
            id: initialEntry?.id ?? UUID(),
            workID: selectedWork?.id ?? initialEntry?.workID ?? UUID(),
            category: category,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            creator: creator.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            status: status,
            rating: Double(ratingText),
            context: context,
            comment: comment,
            details: details,
            coverData: coverData
        ))
        dismiss()
    }

    private func select(_ work: WorkSummary) {
        selectedWork = work
        category = work.category
        title = work.title
        creator = work.creator
        coverData = work.coverData
    }

    private func clearSelectedWork() {
        selectedWork = nil
        title = ""
        creator = ""
        coverData = nil
    }

    private func encounterCountText(_ count: Int) -> String {
        language.text(
            count == 1 ? "1 encounter" : "\(count) encounters",
            "\(count) 次记录"
        )
    }

    private func ratingInput(from input: String, fallback: String) -> String {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        var result = ""
        var hasDecimal = false
        var decimalCount = 0

        for character in normalized {
            if character == ".", !hasDecimal {
                hasDecimal = true
                result.append(character)
            } else if character.isNumber {
                if hasDecimal {
                    guard decimalCount < 2 else { continue }
                    decimalCount += 1
                }
                result.append(character)
            }
        }

        if let value = Double(result), value > 11 {
            return fallback
        }
        return result
    }

    private static func detailValue(_ label: String, in entry: JournalEntry?) -> String {
        entry?.details.first(where: { $0.label == label })?.value ?? ""
    }
}

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: JournalStore
    @Environment(\.appLanguage) private var language
    let entryID: UUID
    @Binding var composerRequest: ComposerRequest?
    @State private var showingDeleteConfirmation = false

    private var entry: JournalEntry? {
        store.entry(withID: entryID)
    }

    private var isOnlyEncounter: Bool {
        guard let entry else { return false }
        return store.encounters(for: entry.workID).count == 1
    }

    var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 24) {
                    CoverArtwork(category: entry.category, imageData: entry.coverData)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.7, contentMode: .fit)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.category.singular(in: language).uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(entry.category.tint)
                        Text(entry.title)
                            .font(.system(.largeTitle, design: .serif, weight: .medium))
                        Text(entry.creator)
                            .foregroundStyle(.secondary)
                        HStack {
                            Label(entry.status.label(in: language), systemImage: "bookmark")
                            Spacer()
                            Text("\(language.text("My rating", "我的评分")) \(localizedRating(for: entry))")
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    if let work = store.work(withID: entry.workID) {
                        Button {
                            composerRequest = ComposerRequest(work: work, entry: entry)
                        } label: {
                            Label(language.text("Edit this encounter", "编辑此记录"), systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(entry.category.tint)
                    }

                    if !entry.comment.isEmpty {
                        Text(entry.comment)
                            .font(.system(.title3, design: .serif))
                            .lineSpacing(4)
                    }

                    if !entry.context.isEmpty {
                        DetailFact(label: language.fieldLabel("Context"), value: entry.context)
                    }
                    ForEach(entry.details) { detail in
                        DetailFact(label: language.fieldLabel(detail.label), value: detail.value)
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(language.text("Delete encounter", "删除此记录"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .navigationTitle(entry?.title ?? "LogJam")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let entry, let work = store.work(withID: entry.workID) {
                    Button(language.text("Edit", "编辑")) {
                        composerRequest = ComposerRequest(work: work, entry: entry)
                    }
                }
            }
        }
        .alert(
            language.text("Delete this encounter?", "删除这条记录？"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(language.text("Cancel", "取消"), role: .cancel) {}
            Button(language.text("Delete", "删除"), role: .destructive) {
                if store.deleteEncounter(id: entryID) {
                    dismiss()
                }
            }
        } message: {
            Text(
                isOnlyEncounter
                    ? language.text(
                        "This is the only encounter for this work. Deleting it will also remove the work from your Library.",
                        "这是该作品唯一的一条记录。删除后，该作品也会从你的库中移除。"
                    )
                    : language.text(
                        "The work and its other encounters will remain in your Library.",
                        "该作品及其他相遇记录仍会保留在你的库中。"
                    )
            )
        }
    }

    private func localizedRating(for entry: JournalEntry) -> String {
        entry.rating.map { $0.formatted(.number.precision(.fractionLength(0...2))) }
            ?? language.text("Unrated", "未评分")
    }
}

struct WorkDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: JournalStore
    @Environment(\.appLanguage) private var language
    let workID: UUID
    @Binding var composerRequest: ComposerRequest?
    @State private var showingDeleteConfirmation = false

    private var work: WorkSummary? {
        store.work(withID: workID)
    }

    private var encounters: [JournalEntry] {
        store.encounters(for: workID)
    }

    var body: some View {
        ScrollView {
            if let work {
                VStack(alignment: .leading, spacing: 24) {
                    CoverArtwork(category: work.category, imageData: work.coverData)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.7, contentMode: .fit)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(work.category.singular(in: language).uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(work.category.tint)
                        Text(work.title)
                            .font(.system(.largeTitle, design: .serif, weight: .medium))
                        Text(work.creator)
                            .foregroundStyle(.secondary)
                        Text(encounterCountText(encounters.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        composerRequest = ComposerRequest(work: work)
                    } label: {
                        Label(language.text("Log again", "再次记录"), systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(work.category.tint)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(language.text("Encounter history", "相遇记录"))
                            .font(.system(.title2, design: .serif, weight: .semibold))
                        ForEach(encounters) { encounter in
                            NavigationLink {
                                EntryDetailView(entryID: encounter.id, composerRequest: $composerRequest)
                            } label: {
                                EncounterHistoryRow(entry: encounter)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(language.text("Delete work", "删除作品"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(work?.title ?? "LogJam")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            language.text("Delete this work?", "删除这个作品？"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(language.text("Cancel", "取消"), role: .cancel) {}
            Button(language.text("Delete", "删除"), role: .destructive) {
                _ = store.deleteWork(id: workID)
            }
        } message: {
            Text(
                language.text(
                    "This will delete the work and all \(encounters.count) of its encounters. This cannot be undone.",
                    "这会删除该作品及其全部 \(encounters.count) 条相遇记录，且无法撤销。"
                )
            )
        }
        .onChange(of: work == nil) { _, isMissing in
            if isMissing { dismiss() }
        }
    }

    private func encounterCountText(_ count: Int) -> String {
        language.text(
            count == 1 ? "1 encounter" : "\(count) encounters",
            "\(count) 次相遇"
        )
    }
}

struct EncounterHistoryRow: View {
    @Environment(\.appLanguage) private var language
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(entry.date, format: .dateTime.day())
                    .font(.system(.title3, design: .serif, weight: .semibold))
                Text(entry.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.status.label(in: language))
                    .font(.subheadline.weight(.semibold))
                if !entry.context.isEmpty {
                    Text(entry.context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.rating.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? "—")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(entry.category.tint)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

struct TimelineEntryCard: View {
    @Environment(\.appLanguage) private var language
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(entry.date, format: .dateTime.day())
                    .font(.system(.title2, design: .serif))
                Text(entry.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 34)

            CoverArtwork(category: entry.category, imageData: entry.coverData)
                .frame(width: 64, height: 82)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.category.singular(in: language).uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(entry.category.tint)
                Text(entry.title)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(.primary)
                Text([entry.creator, entry.status.label(in: language)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.comment)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(entry.rating.map { "\(language.text("My rating", "我的评分")) \($0.formatted(.number.precision(.fractionLength(0...2))))" } ?? language.text("Unrated", "未评分"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(entry.category.tint)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}

struct LibraryTile: View {
    @Environment(\.appLanguage) private var language
    let work: WorkSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverArtwork(category: work.category, imageData: work.coverData)
                .aspectRatio(0.76, contentMode: .fit)
            Text(work.title)
                .font(.system(.headline, design: .serif))
                .lineLimit(1)
            Text(work.creator)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(language.text(
                work.encounterCount == 1 ? "1 encounter" : "\(work.encounterCount) encounters",
                "\(work.encounterCount) 次记录"
            ))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(work.category.tint)
        }
    }
}

struct CoverArtwork: View {
    let category: MediaCategory
    let imageData: Data?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    ZStack {
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)

                        Circle()
                            .fill(.white.opacity(0.13))
                            .frame(width: proxy.size.width * 0.95)
                            .offset(x: proxy.size.width * 0.34, y: -proxy.size.height * 0.27)

                        RoundedRectangle(cornerRadius: proxy.size.width * 0.12)
                            .stroke(.white.opacity(0.19), lineWidth: max(2, proxy.size.width * 0.035))
                            .frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.48)
                            .rotationEffect(.degrees(-28))
                            .offset(x: -proxy.size.width * 0.26, y: proxy.size.height * 0.24)

                        Circle()
                            .stroke(.white.opacity(0.14), lineWidth: max(2, proxy.size.width * 0.045))
                            .frame(width: proxy.size.width * 0.42)
                            .offset(x: proxy.size.width * 0.18, y: proxy.size.height * 0.28)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(.rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.14), radius: 8, y: 5)
    }

    private var gradientColors: [Color] {
        switch category {
        case .film: [Color(red: 0.83, green: 0.48, blue: 0.34), Color(red: 0.22, green: 0.14, blue: 0.13)]
        case .book: [Color(red: 0.17, green: 0.32, blue: 0.28), Color(red: 0.40, green: 0.53, blue: 0.47)]
        case .classical: [Color(red: 0.20, green: 0.16, blue: 0.29), Color(red: 0.52, green: 0.43, blue: 0.66)]
        }
    }
}

struct FilterButton: View {
    let title: String
    let active: Bool
    let action: () -> Void

    init(_ title: String, active: Bool, action: @escaping () -> Void) {
        self.title = title
        self.active = active
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(active ? .primary : .secondary)
            .buttonBorderShape(.capsule)
    }
}

struct DetailFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .overlay(alignment: .top) { Divider() }
    }
}
