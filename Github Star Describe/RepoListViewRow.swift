import SwiftUI

struct RepoListViewRow: View {
    var repo: StarredRepo
    var onEdit: () -> Void
    var onAIDescribe: () -> Void
    var aiRunning: Bool
    
    // 💡 监听全局主题变化
    @AppStorage("appTheme") private var theme: AppTheme = .system
    
    // 💡 性能优化：限制单行显示字数
    private var displayText: String {
        let text = repo.customDescription.isEmpty ? "（暂无描述）" : repo.customDescription
        guard text.count > 200 else { return text }
        return String(text.prefix(200)) + "…"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(repo.name).font(.headline).lineLimit(1)
                    // 💡 新增：AI 生成来源小标记
                    if repo.descriptionSource == .ai {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(theme.accent)
                            .help("该描述由 AI 生成")
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption)
                        Text("\(repo.starCount)").font(.caption).foregroundColor(.secondary).monospacedDigit()
                    }
                }
                
                // 💡 完整显示不折叠；对超长描述限制显示字数，控制排版开销
                Text(displayText)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    let author = repo.fullName.components(separatedBy: "/").first ?? repo.fullName
                    Text(author).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                    if let language = repo.language {
                        HStack(spacing: 4) {
                            // 语言圆点跟随主题强调色
                            Circle().fill(theme.accent.opacity(0.8)).frame(width: 6, height: 6)
                            Text(language).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, 8)
                .frame(height: 40)
            
            // 💡 新增：列表右侧的 AI 描述按钮
            Button(action: onAIDescribe) {
                if aiRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(theme.accent)
                }
            }
            .buttonStyle(.plain)
            .disabled(aiRunning)
            .help("AI 生成描述（确认后替换当前描述）")
            
            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    // 列表右侧的编辑图标跟随主题强调色
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
            .help("编辑")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
