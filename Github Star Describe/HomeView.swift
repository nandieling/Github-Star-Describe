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

// MARK: - AI 二次确认数据
struct AIConfirmData: Identifiable {
    let id: Int
    let repo: StarredRepo
    let newText: String
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
    
    // MARK: - AI 描述状态
    @AppStorage("aiGateway") private var aiGateway: String = AIConfig.defaultGateway
    @AppStorage("aiModel") private var aiModel: String = AIConfig.defaultModel
    @State private var aiKeyText: String = ""
    // 💡 新增：清空输入框时避免误删已保存的密钥
    @State private var suppressKeySave = false
    @State private var isVerifyingAI: Bool = false
    @State private var aiVerifyMessage: String = ""
    @State private var aiVerifyOK: Bool? = nil
    @State private var batchRunning: Bool = false
    @State private var batchTask: Task<Void, Never>? = nil
    @State private var batchProgressText: String = ""
    @State private var batchLastError: String = ""
    @State private var singleAIRunningID: Int? = nil
    @State private var aiConfirm: AIConfirmData? = nil
    
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
                            ForEach(filteredAndSortedRepos) { repo in
                                RepoCardView(repo: repo,
                                             onEdit: { editingRepo = repo },
                                             onAIDescribe: { generateSingleAI(for: repo) },
                                             aiRunning: singleAIRunningID == repo.id)
                            }
                        }
                        .padding(.horizontal, 24).padding(.vertical, 16)
                    }
                } else {
                    List(filteredAndSortedRepos) { repo in
                        RepoListViewRow(repo: repo,
                                        onEdit: { editingRepo = repo },
                                        onAIDescribe: { generateSingleAI(for: repo) },
                                        aiRunning: singleAIRunningID == repo.id)
                    }
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
                            // 💡 新增：AI 描述设置
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI 描述").font(.headline)
                                TextField("网关地址", text: $aiGateway, prompt: Text(AIConfig.defaultGateway))
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { Task { await verifyAIKey() } }
                                TextField("模型名称", text: $aiModel, prompt: Text(AIConfig.defaultModel))
                                    .textFieldStyle(.roundedBorder)
                                SecureField("API 密钥", text: $aiKeyText, prompt: Text("用于 OpenAI 协议网关"))
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: aiKeyText) { _, newValue in
                                        if suppressKeySave { return }
                                        KeychainStore.set(newValue, account: KeychainStore.aiKeyAccount)
                                        aiVerifyOK = nil
                                    }
                                HStack(spacing: 8) {
                                    Button(action: { Task { await verifyAIKey() } }) {
                                        if isVerifyingAI {
                                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("检测中...") }
                                        } else {
                                            Label("检测验证", systemImage: "checkmark.seal")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isVerifyingAI || aiKeyText.isEmpty)
                                    Button("清除") {
                                        suppressKeySave = true
                                        aiKeyText = ""
                                        suppressKeySave = false
                                        KeychainStore.set("", account: KeychainStore.aiKeyAccount)
                                        aiVerifyOK = nil
                                        aiVerifyMessage = ""
                                    }
                                    .font(.caption)
                                    .disabled(!hasSavedKey && aiKeyText.isEmpty)
                                    Spacer()
                                    if let ok = aiVerifyOK {
                                        Label(aiVerifyMessage, systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(ok ? .green : .red)
                                            .lineLimit(2)
                                    }
                                }
                                Text("批量描述按卡片顺序生成，只处理未手动编辑且未生成过 AI 描述的仓库；已有描述可在单个卡片上重新生成并确认后替换。")
                                    .font(.caption2).foregroundColor(.secondary)
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
                        .padding(20).frame(width: 340)
                    }
                    .onChange(of: isShowingSettings) { _, showing in
                        // 预填充本机已保存的密钥（Keychain 按用户隔离，不会随软件包分发）
                        if showing {
                            aiKeyText = KeychainStore.get(KeychainStore.aiKeyAccount)
                            aiVerifyOK = nil
                            aiVerifyMessage = ""
                        }
                    }
                }
                
                // 💡 新增：AI 批量自动描述（右上角）
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { startBatchAI() }) {
                        if batchRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                    }
                    .disabled(batchRunning || repos.isEmpty)
                    .help("AI 批量自动描述（不覆盖手动编辑）")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { withAnimation { isCardView.toggle() } }) { Image(systemName: isCardView ? "list.bullet" : "square.grid.2x2") }
                }
            }
            .sheet(item: $editingRepo) { repo in EditRepoView(repo: repo) }
            // 💡 新增：AI 批量描述进度
            .sheet(isPresented: $batchRunning) {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text(batchProgressText.isEmpty ? "正在启动 AI 批量描述..." : batchProgressText)
                        .font(.callout).lineLimit(2).frame(maxWidth: 300)
                    Button("取消", role: .cancel) { batchTask?.cancel() }
                }
                .padding(32)
                .frame(width: 360)
                .interactiveDismissDisabled()
            }
            // 💡 新增：单个 AI 描述二次确认
            .sheet(item: $aiConfirm) { data in AIConfirmSheet(data: data) }
            .alert("操作提示", isPresented: $showSyncAlert) { Button("好的", role: .cancel) { } } message: { Text(syncAlertMessage) }
            .alert("错误", isPresented: $showErrorAlert) { Button("确定", role: .cancel) { } } message: { Text(errorMessage) }
        }
        .frame(minWidth: 850, minHeight: 500)
        .onAppear {
            loadBackgroundImage()
            aiKeyText = KeychainStore.get(KeychainStore.aiKeyAccount)
        }
        
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
    
    // MARK: - AI 配置与验证
    var hasSavedKey: Bool {
        !KeychainStore.get(KeychainStore.aiKeyAccount).trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func makeAIConfig() -> AIConfig {
        AIConfig(gateway: aiGateway, apiKey: KeychainStore.get(KeychainStore.aiKeyAccount), model: aiModel)
    }
    
    @MainActor
    func verifyAIKey() async {
        // 输入框为空时直接使用已保存的密钥
        let enteredKey = aiKeyText.trimmingCharacters(in: .whitespaces)
        guard !enteredKey.isEmpty || hasSavedKey else { return }
        isVerifyingAI = true
        aiVerifyMessage = ""
        defer { isVerifyingAI = false }
        do {
            let count = try await AIService(config: makeAIConfig()).verifyKey()
            aiVerifyOK = true
            aiVerifyMessage = count > 0 ? "验证成功，发现 \(count) 个可用模型" : "验证成功，网关连接正常"
        } catch {
            aiVerifyOK = false
            aiVerifyMessage = error.localizedDescription
        }
    }
    
    // MARK: - AI 批量描述
    @MainActor
    func startBatchAI() {
        // 按卡片当前排列顺序（含搜索过滤与排序）执行
        // 手动编辑过或已 AI 描述过的仓库直接跳过，只有单独点击卡片 AI 按钮或自定义编辑才能修改它们
        let candidates = filteredAndSortedRepos.filter { $0.descriptionSource == .initial }
        guard !candidates.isEmpty else {
            syncAlertMessage = "没有可描述的仓库：所有仓库的描述都已手动编辑或已生成过 AI 描述，批量描述直接跳过。如需修改，请单独点击卡片上的 AI 按钮或编辑描述。"
            showSyncAlert = true
            return
        }
        let config = makeAIConfig()
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            isShowingSettings = true
            syncAlertMessage = "请先在设置（调色板图标）的「AI 描述」中填写 API 密钥，并点击「检测验证」。"
            showSyncAlert = true
            return
        }
        batchLastError = ""
        batchProgressText = "准备开始，共 \(candidates.count) 个仓库待描述..."
        batchRunning = true
        batchTask = Task {
            var okCount = 0
            var failCount = 0
            let service = AIService(config: config)
            for (index, repo) in candidates.enumerated() {
                if Task.isCancelled { break }
                batchProgressText = "正在描述 (\(index + 1)/\(candidates.count))：\(repo.name)"
                do {
                    let text = try await service.describe(repo: repo)
                    repo.customDescription = text
                    repo.descriptionSource = .ai
                    okCount += 1
                    try? modelContext.save()
                } catch is CancellationError {
                    break
                } catch {
                    failCount += 1
                    if batchLastError.isEmpty { batchLastError = error.localizedDescription }
                }
                // 稍作停顿，避免请求过于密集
                if index < candidates.count - 1 {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }
            let wasCancelled = Task.isCancelled
            batchRunning = false
            var message = "AI 批量描述完成：成功 \(okCount) 个"
            if failCount > 0 { message += "，失败 \(failCount) 个" }
            if wasCancelled { message += "\n（已取消，剩余仓库跳过）" }
            if !batchLastError.isEmpty { message += "\n首个失败原因：\(batchLastError)" }
            syncAlertMessage = message
            showSyncAlert = true
        }
    }
    
    // MARK: - 单个 AI 描述（需二次确认后才替换）
    @MainActor
    func generateSingleAI(for repo: StarredRepo) {
        guard singleAIRunningID == nil else { return }
        let config = makeAIConfig()
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            isShowingSettings = true
            syncAlertMessage = "请先在设置（调色板图标）的「AI 描述」中填写 API 密钥，并点击「检测验证」。"
            showSyncAlert = true
            return
        }
        singleAIRunningID = repo.id
        Task {
            defer { singleAIRunningID = nil }
            do {
                let text = try await AIService(config: config).describe(repo: repo)
                aiConfirm = AIConfirmData(id: repo.id, repo: repo, newText: text)
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
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
            
            // 匹配 ID，只覆盖自定义描述字段（导入视为手动来源，批量 AI 不覆盖）
            for backup in backups {
                if let repo = repos.first(where: { $0.id == backup.id }) {
                    repo.customDescription = backup.customDescription
                    repo.descriptionSource = .manual
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

// MARK: - AI 描述二次确认弹窗
struct AIConfirmSheet: View {
    @State var data: AIConfirmData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private var currentText: String {
        data.repo.customDescription.isEmpty ? "（暂无描述）" : data.repo.customDescription
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundColor(.accentColor)
                Text("确认替换描述").font(.title3).bold()
            }
            
            Text("以下是当前描述与 AI 生成描述的对比，替换后新描述将生效。")
                .font(.callout).foregroundColor(.secondary)
            
            HStack(alignment: .top, spacing: 12) {
                GroupBox("当前描述") {
                    Text(currentText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .lineLimit(10)
                }
                GroupBox("AI 新描述") {
                    Text(data.newText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .lineLimit(10)
                }
            }
            
            Spacer()
            
            HStack {
                Text("AI 描述将替换当前描述（来源标记为 AI）")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("取消") { dismiss() }
                Button("替换描述") {
                    data.repo.customDescription = data.newText
                    data.repo.descriptionSource = .ai
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680, height: 420)
    }
}
