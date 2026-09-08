import Foundation
import SwiftData

@Model
class StarredRepo {
    @Attribute(.unique) var id: Int = 0
    var name: String = ""
    var fullName: String = ""
    var originalDescription: String?
    var customDescription: String = ""
    var htmlUrl: String = ""
    var language: String?
    var starCount: Int = 0
    // 💡 新增：标星时间字段。给定一个默认值以确保旧数据库能平滑升级
    var starredAt: Date = Date()
    // 💡 新增：描述来源（持久化原始值，默认 0 保证旧数据库平滑升级）
    var descriptionSourceRaw: Int = 0
    var descriptionSource: DescriptionSource {
        get { DescriptionSource(rawValue: descriptionSourceRaw) ?? .initial }
        set { descriptionSourceRaw = newValue.rawValue }
    }
    
    init(id: Int, name: String, fullName: String, originalDescription: String?, htmlUrl: String, language: String?, starCount: Int, starredAt: Date = Date()) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.originalDescription = originalDescription
        self.customDescription = originalDescription ?? "暂无描述"
        self.htmlUrl = htmlUrl
        self.language = language
        self.starCount = starCount
        self.starredAt = starredAt
    }
}

// MARK: - 描述来源枚举
// 手动编辑的描述优先级最高：AI 批量描述只填充“未被手动编辑过”的仓库
enum DescriptionSource: Int {
    /// 初始值（同步时带入的原作者描述）
    case initial = 0
    /// 用户手动编辑（批量 AI 描述不会覆盖）
    case manual = 1
    /// AI 生成（可被批量 AI 覆盖）
    case ai = 2
}
