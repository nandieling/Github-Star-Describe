import SwiftUI

struct RepoListViewRow: View {
    var repo: StarredRepo
    var onEdit: () -> Void
    
    // 💡 监听全局主题变化
    @AppStorage("appTheme") private var theme: AppTheme = .system
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(repo.name).font(.headline).lineLimit(1)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption)
                        Text("\(repo.starCount)").font(.caption).foregroundColor(.secondary).monospacedDigit()
                    }
                }
                
                Text(repo.customDescription.isEmpty ? "（暂无描述）" : repo.customDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(2)
                
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
