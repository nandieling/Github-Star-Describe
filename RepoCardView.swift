import SwiftUI

struct RepoCardView: View {
    var repo: StarredRepo
    var onEdit: () -> Void
    
    // 💡 监听全局主题变化
    @AppStorage("appTheme") private var theme: AppTheme = .system
    
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
            Text(repo.customDescription.isEmpty ? "（暂无描述）" : repo.customDescription)
                .font(.body).foregroundColor(.primary.opacity(0.8)).lineLimit(3)
                .frame(minHeight: 60, alignment: .topLeading)
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
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
        .overlay(
            // 卡片边框色跟随主题
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.border, lineWidth: 1)
        )
        .shadow(color: theme.accent.opacity(0.05), radius: 5, x: 0, y: 3)
    }
}
