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
