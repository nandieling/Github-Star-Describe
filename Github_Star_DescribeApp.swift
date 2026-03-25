import SwiftUI
import SwiftData

@main
struct Github_Star_DescribeApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        // 恢复为最简单的本地容器
        .modelContainer(for: StarredRepo.self)
    }
}
