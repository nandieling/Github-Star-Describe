import SwiftUI
import SwiftData

struct EditRepoView: View {
    @Bindable var repo: StarredRepo
    // 用于控制弹窗关闭的环境变量
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 弹窗头部：标题和跳转链接
            HStack {
                Text(repo.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let url = URL(string: repo.htmlUrl) {
                    Link(destination: url) {
                        Image(systemName: "safari")
                        Text("在 GitHub 打开")
                    }
                    .buttonStyle(.link)
                }
            }
            
            Divider()
            
            // 核心编辑区
            VStack(alignment: .leading, spacing: 8) {
                Text("我的功能描述：")
                    .font(.headline)
                
                TextEditor(text: $repo.customDescription)
                    .font(.body)
                    // 弹窗里的输入框不用太高
                    .frame(height: 120)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
            
            // 原描述参考区
            VStack(alignment: .leading, spacing: 8) {
                Text("原作者描述：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                GroupBox {
                    Text(repo.originalDescription ?? "无")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3) // 限制行数，防止弹窗被撑得太大
                }
            }
            
            Spacer()
            
            // 弹窗底部的操作按钮
            HStack {
                Spacer()
                Button("完成") {
                    dismiss() // 点击关闭弹窗
                }
                // 把这个按钮设为默认操作，用户改完按一下回车键(Enter)就能关闭弹窗
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent) // 设为高亮的蓝色主按钮
            }
        }
        .padding(24)
        // 💡 锁定弹窗的固定尺寸，保证 Mac 上的弹出体验最佳
        .frame(width: 500, height: 450)
    }
}
