import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - 数据导入导出模型
struct BackupData: Codable {
    let id: Int
    let customDescription: String
}

// macOS 必须的文件文档协议
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents { self.data = data }
        else { throw CocoaError(.fileReadCorruptFile) }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 主题与排序枚举
enum AppTheme: String, CaseIterable {
    case system = "默认", ocean = "深海", forest = "极光", sunset = "暖阳", lavender = "熏衣草"
    var cardBackground: Color {
        switch self { case .system: return Color(NSColor.controlBackgroundColor); case .ocean: return Color.blue.opacity(0.08); case .forest: return Color.green.opacity(0.08); case .sunset: return Color.orange.opacity(0.08); case .lavender: return Color.purple.opacity(0.08) }
    }
    var accent: Color {
        switch self { case .system: return .accentColor; case .ocean: return .blue; case .forest: return .green; case .sunset: return .orange; case .lavender: return .purple }
    }
    var border: Color {
        switch self { case .system: return Color.secondary.opacity(0.2); case .ocean: return Color.blue.opacity(0.3); case .forest: return Color.green.opacity(0.3); case .sunset: return Color.orange.opacity(0.3); case .lavender: return Color.purple.opacity(0.3) }
    }
}

enum SortOption: String, CaseIterable {
    case nameAsc = "名称 (A-Z)"
    case nameDesc = "名称 (Z-A)"
    case starDesc = "Star数 (高到低)"
    case starAsc = "Star数 (低到高)"
    // 💡 新增的时间排序
    case timeDesc = "标星时间 (新到旧)"
    case timeAsc = "标星时间 (旧到新)"
}

// MARK: - 主视图
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var repos: [StarredRepo]
    
    @State private var isCardView: Bool = true
    @State private var editingRepo: StarredRepo?
    @AppStorage("githubUsername") private var username: String = ""
    @AppStorage("sortOption") private var sortOption: SortOption = .timeDesc // 默认最新收藏排前面
    @AppStorage("appTheme") private var currentTheme: AppTheme = .system
    @State private var searchText: String = ""
    
    // 背景与文件弹窗状态
    @State private var bgImage: NSImage? = nil
    @AppStorage("backgroundOpacity") private var bgOpacity: Double = 0.5
    @State private var isShowingSettings = false
    @State private var isShowingImagePicker = false
    
    // 💡 新增：导入导出状态
    @State private var isShowingDataExporter = false
    @State private var isShowingDataImporter = false
    @State private var backupDocument = BackupDocument()
    
    // 警告框状态
    @State private var isLoading: Bool = false
    @State private var showSyncAlert: Bool = false
    @State private var syncAlertMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var filteredAndSortedRepos: [StarredRepo] {
        let filtered = searchText.isEmpty ? repos : repos.filter { repo in
            let term = searchText.lowercased()
            return repo.name.lowercased().contains(term) || repo.customDescription.lowercased().contains(term) || (repo.originalDescription?.lowercased().contains(term) ?? false) || (repo.language?.lowercased().contains(term) ?? false)
        }
        return filtered.sorted { r1, r2 in
            switch sortOption {
            case .nameAsc: return r1.name.localizedStandardCompare(r2.name) == .orderedAscending
            case .nameDesc: return r1.name.localizedStandardCompare(r2.name) == .orderedDescending
            case .starDesc: return r1.starCount > r2.starCount
            case .starAsc: return r1.starCount < r2.starCount
            // 💡 新增的时间排序逻辑
            case .timeDesc: return r1.starredAt > r2.starredAt
            case .timeAsc: return r1.starredAt < r2.starredAt
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isCardView {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 16) {
                            ForEach(filteredAndSortedRepos) { repo in RepoCardView(repo: repo) { editingRepo = repo } }
                        }
                        .padding(.horizontal, 24).padding(.vertical, 16)
                    }
                } else {
                    List(filteredAndSortedRepos) { repo in RepoListViewRow(repo: repo) { editingRepo = repo } }
                    .scrollContentBackground(.hidden).padding(.horizontal, 16)
                }
            }
            .background {
                Group {
                    if let img = bgImage { Image(nsImage: img).resizable().scaledToFill().opacity(bgOpacity) }
                    else { Color(NSColor.windowBackgroundColor) }
                }.ignoresSafeArea()
            }
            .navigationTitle(searchText.isEmpty ? "我的 Star (\(repos.count))" : "搜索结果 (\(filteredAndSortedRepos.count))")
            .searchable(text: $searchText, prompt: "搜索仓库、描述或语言...")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    TextField("GitHub 用户名", text: $username).textFieldStyle(.roundedBorder).frame(minWidth: 120, idealWidth: 140, maxWidth: 180).onSubmit { Task { await syncData() } }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: { Task { await syncData() } }) {
                        if isLoading { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.triangle.2.circlepath") }
                    }.disabled(isLoading || username.isEmpty)
                }
                
                ToolbarItem(placement: .automatic) { Divider() }
                
                // 💡 核心改动：使用新的更直观的图标，并取消三级菜单嵌套
                ToolbarItem(placement: .automatic) {
                    Menu {
                        // 使用 EmptyView() 和 .pickerStyle(.inline) 可以把选项直接铺在第一级菜单
                        Picker(selection: $sortOption, label: EmptyView()) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        // 换了一个更好看、更符合排序语义的图标
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .help("排序方式")
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: { isShowingSettings.toggle() }) { Image(systemName: "paintpalette") }
                    .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("主题色彩").font(.headline)
                                Picker("", selection: $currentTheme) { ForEach(AppTheme.allCases, id: \.self) { theme in Text(theme.rawValue).tag(theme) } }.pickerStyle(.segmented)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自定义背景").font(.headline)
                                Button("选择背景图片...") { isShowingImagePicker = true }
                                if bgImage != nil {
                                    VStack(alignment: .leading) {
                                        Text("背景透明度: \(Int(bgOpacity * 100))%")
                                        Slider(value: $bgOpacity, in: 0.1...1.0)
                                    }
                                    Button("清除背景图片", role: .destructive) { clearBackgroundImage() }.foregroundColor(.red)
                                }
                            }
                            Divider()
                            // 💡 新增：数据备份与导入入口
                            VStack(alignment: .leading, spacing: 8) {
                                Text("数据管理").font(.headline)
                                HStack {
                                    Button("导出自定义描述...") { exportData() }
                                    Spacer()
                                    Button("导入备份文件...") { isShowingDataImporter = true }
                                }
                            }
                        }
                        .padding(20).frame(width: 320)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { withAnimation { isCardView.toggle() } }) { Image(systemName: isCardView ? "list.bullet" : "square.grid.2x2") }
                }
            }
            .sheet(item: $editingRepo) { repo in EditRepoView(repo: repo) }
            .alert("操作提示", isPresented: $showSyncAlert) { Button("好的", role: .cancel) { } } message: { Text(syncAlertMessage) }
            .alert("错误", isPresented: $showErrorAlert) { Button("确定", role: .cancel) { } } message: { Text(errorMessage) }
        }
        .frame(minWidth: 850, minHeight: 500)
        .onAppear { loadBackgroundImage() }
        
        // 💡 文件选择器集群：处理背景图、导出 JSON、导入 JSON
                .fileImporter(isPresented: $isShowingImagePicker, allowedContentTypes: [.image]) { result in
                    // 修复：直接接收单个 url，去掉 .first
                    if case .success(let url) = result { saveBackgroundImage(from: url) }
                }
                .fileExporter(isPresented: $isShowingDataExporter, document: backupDocument, contentType: .json, defaultFilename: "StarNotes_Backup") { result in
                    if case .success(_) = result {
                        syncAlertMessage = "备份文件导出成功！"
                        showSyncAlert = true
                    }
                }
                .fileImporter(isPresented: $isShowingDataImporter, allowedContentTypes: [.json]) { result in
                    // 修复：直接接收单个 url，去掉 .first
                    if case .success(let url) = result { importData(from: url) }
                }
        
    }
    
    // MARK: - 导入导出核心逻辑
    func exportData() {
        // 只提取 ID 和自定义描述，生成轻量级备份文件
        let backups = repos.map { BackupData(id: $0.id, customDescription: $0.customDescription) }
        if let encoded = try? JSONEncoder().encode(backups) {
            backupDocument = BackupDocument(data: encoded)
            isShowingDataExporter = true
        }
    }
    
    func importData(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let backups = try JSONDecoder().decode([BackupData].self, from: data)
            var updateCount = 0
            
            // 匹配 ID，只覆盖自定义描述字段
            for backup in backups {
                if let repo = repos.first(where: { $0.id == backup.id }) {
                    repo.customDescription = backup.customDescription
                    updateCount += 1
                }
            }
            try? modelContext.save()
            syncAlertMessage = "成功导入并更新了 \(updateCount) 条自定义描述！"
            showSyncAlert = true
        } catch {
            errorMessage = "导入失败，请检查文件格式是否正确。"
            showErrorAlert = true
        }
    }
    
    // MARK: - 网络同步逻辑
    func syncData() async {
        guard !username.isEmpty else { return }
        isLoading = true
        let service = GitHubService()
        do {
            let fetchedItems = try await service.fetchStarredRepos(for: username)
            let fetchedIDs = Set(fetchedItems.map { $0.repo.id })
            
            var newlyAddedCount = 0
            var deletedCount = 0
            
            for localRepo in repos {
                if !fetchedIDs.contains(localRepo.id) {
                    modelContext.delete(localRepo)
                    deletedCount += 1
                }
            }
            
            for item in fetchedItems {
                let fetched = item.repo
                let starredAt = item.starredAt // 从新接口拿到标星时间
                
                if let existingRepo = repos.first(where: { $0.id == fetched.id }) {
                    existingRepo.starCount = fetched.stargazersCount
                    existingRepo.originalDescription = fetched.description
                    existingRepo.starredAt = starredAt // 更新时间防丢失
                } else {
                    let newRepo = StarredRepo(id: fetched.id, name: fetched.name, fullName: fetched.fullName, originalDescription: fetched.description, htmlUrl: fetched.htmlUrl, language: fetched.language, starCount: fetched.stargazersCount, starredAt: starredAt)
                    modelContext.insert(newRepo)
                    newlyAddedCount += 1
                }
            }
            try? modelContext.save()
            syncAlertMessage = "共获取到 \(fetchedItems.count) 个仓库。\n✨ 新增 \(newlyAddedCount) 个\n🗑️ 清理 \(deletedCount) 个"
            showSyncAlert = true
        } catch {
            errorMessage = "无法拉取数据，请检查网络或用户名。"
            showErrorAlert = true
        }
        isLoading = false
    }
    
    // MARK: - 背景图片管理逻辑
    private func getBackgroundURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("custom_background.jpg")
    }
    private func saveBackgroundImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
            try? data.write(to: getBackgroundURL())
            bgImage = NSImage(data: data)
        }
    }
    private func loadBackgroundImage() {
        if let data = try? Data(contentsOf: getBackgroundURL()) { bgImage = NSImage(data: data) }
    }
    private func clearBackgroundImage() {
        try? FileManager.default.removeItem(at: getBackgroundURL())
        bgImage = nil
    }
}
