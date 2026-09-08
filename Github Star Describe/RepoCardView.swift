import SwiftUI

struct RepoCardView: View {
    var repo: StarredRepo
    var onEdit: () -> Void
    var onAIDescribe: () -> Void
    var aiRunning: Bool
    
    // 💡 监听全局主题变化
    @AppStorage("appTheme") private var theme: AppTheme = .system
    
    // 💡 性能优化：限制单卡显示字数（AI 生成的描述本身在 50~120 字，不受影响）
    private var displayText: String {
        let text = repo.customDescription.isEmpty ? "（暂无描述）" : repo.customDescription
        guard text.count > 200 else { return text }
        return String(text.prefix(200)) + "…"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name).font(.headline).fontWeight(.bold).foregroundColor(.primary).lineLimit(1)
                    Text(repo.fullName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    // 保持 Star 是金黄色，这是 GitHub 的灵魂
                    Image(systemName: "star.fill").foregroundColor(.yellow).imageScale(.small)
                    Text("\(repo.starCount)").font(.subheadline).foregroundColor(.secondary).monospacedDigit()
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            Divider()
            HStack(alignment: .top, spacing: 6) {
                // 💡 完整显示不折叠；对超长描述限制显示字数，控制单卡排版开销，保证滚动流畅
                Text(displayText)
                    .font(.body).foregroundColor(.primary.opacity(0.8)).lineLimit(nil)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                // 💡 新增：AI 生成来源小标记
                if repo.descriptionSource == .ai {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(theme.accent)
                        .padding(.top, 2)
                        .help("该描述由 AI 生成")
                }
            }
            Spacer()
            HStack {
                if let language = repo.language {
                    HStack(spacing: 4) {
                        // 语言圆点跟随主题强调色
                        Circle().fill(theme.accent).frame(width: 8, height: 8)
                        Text(language).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                // 💡 新增：单个 AI 描述（替换需二次确认）
                Button(action: onAIDescribe) {
                    if aiRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.body)
                            // AI 按钮跟随主题强调色
                            .foregroundColor(theme.accent)
                            .padding(4)
                    }
                }
                .buttonStyle(.plain)
                .disabled(aiRunning)
                .help("AI 生成描述（确认后替换当前描述）")
                
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.body)
                        // 编辑按钮跟随主题强调色
                        .foregroundColor(theme.accent)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("编辑描述")
            }
        }
        .padding()
        .background(
            // 卡片背景色跟随主题
            // 💡 性能优化：阴影只作用于背景形状（简单几何图形，可被渲染层缓存），
            // 不再作用于整张卡片内容，滚动时不需要每帧重新合成文字上的阴影
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.accent.opacity(0.05), radius: 5, x: 0, y: 3)
        )
        .overlay(
            // 卡片边框色跟随主题
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.border, lineWidth: 1)
        )
        // 💡 性能优化：卡片内容合成扁平化为单一图层，降低滚动时的逐帧合成开销
        .compositingGroup()
    }
}
