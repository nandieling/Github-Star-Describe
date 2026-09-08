import Foundation

// MARK: - API 密钥存储（Keychain）
enum KeychainStore {
    private static let service = "nan.Github-Star-Describe"
    static let aiKeyAccount = "ai_api_key"

    static func set(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var attrs = query
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        attrs[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func get(_ account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - AI 配置
struct AIConfig {
    static let defaultGateway = "ai.nandielinghai.de"
    static let defaultModel = "gpt-5.6-luna"

    var gateway: String
    var apiKey: String
    var model: String

    /// 规范化网关地址：补全 https、去掉尾部 /v1 与斜杠
    var baseURL: URL? {
        var g = gateway.trimmingCharacters(in: .whitespacesAndNewlines)
        if g.isEmpty { return nil }
        if !g.contains("://") { g = "https://" + g }
        while g.hasSuffix("/") { g.removeLast() }
        if g.hasSuffix("/v1") { g = String(g.dropLast(3)) }
        return URL(string: g)
    }
}

// MARK: - 错误定义
enum AIError: LocalizedError {
    case missingKey
    case invalidURL
    case http(Int, String)
    case emptyContent
    case decode

    var errorDescription: String? {
        switch self {
        case .missingKey: return "尚未配置 API 密钥，请先在设置（调色板图标）中填写并检测验证。"
        case .invalidURL: return "网关地址格式不正确，请检查后重试。"
        case .http(let code, let detail):
            if code == 401 || code == 403 { return "密钥验证失败（HTTP \(code)），请检查 API 密钥。" }
            return "请求失败（HTTP \(code)）：\(detail)"
        case .emptyContent: return "AI 返回内容为空，请重试。"
        case .decode: return "解析 AI 返回内容失败，请重试。"
        }
    }
}

// MARK: - OpenAI 协议网关服务
class AIService {
    private let config: AIConfig

    init(config: AIConfig) {
        self.config = config
    }

    /// 检测验证密钥：调用 /v1/models，成功返回可用模型数量
    @discardableResult
    func verifyKey() async throws -> Int {
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw AIError.missingKey }
        guard let base = config.baseURL else { throw AIError.invalidURL }

        var request = URLRequest(url: base.appendingPathComponent("v1/models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.decode }
        guard http.statusCode == 200 else {
            throw AIError.http(http.statusCode, Self.detail(from: data))
        }

        struct ModelsResponse: Decodable { let data: [ModelItem] }
        struct ModelItem: Decodable { let id: String }
        if let decoded = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
            return decoded.data.count
        }
        return 0
    }

    /// 为单个仓库生成中文功能描述
    func describe(repo: StarredRepo) async throws -> String {
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { throw AIError.missingKey }
        guard let base = config.baseURL else { throw AIError.invalidURL }
        let url = base.appendingPathComponent("v1/chat/completions")

        let prompt = """
        你是一位资深开源项目分析助手。请根据下面的 GitHub 仓库信息，用中文写一段简洁的功能描述。
        要求：
        1. 用 50~120 个汉字概括这个项目是做什么的、核心功能以及适用场景；
        2. 如果原作者描述是英文，请翻译并改写为通顺的中文；
        3. 只输出描述正文本身，不要任何前缀、标题、引号或额外解释。

        仓库名称：\(repo.fullName)
        仓库地址：\(repo.htmlUrl)
        主要语言：\(repo.language ?? "未知")
        原作者描述：\(repo.originalDescription?.isEmpty == false ? repo.originalDescription! : "（无）")
        """

        struct ChatRequest: Encodable {
            let model: String
            let messages: [Message]
            let temperature: Double
            let max_tokens: Int
            struct Message: Encodable { let role: String; let content: String }
        }

        let body = ChatRequest(
            model: config.model,
            messages: [
                .init(role: "user", content: prompt)
            ],
            temperature: 0.3,
            max_tokens: 500
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.decode }
        guard http.statusCode == 200 else {
            throw AIError.http(http.statusCode, Self.detail(from: data))
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }

        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = chat.choices.first?.message.content,
              let text = Self.cleanText(content) else {
            throw AIError.emptyContent
        }
        return text
    }

    // MARK: - 工具方法
    /// 提取网关返回的错误信息摘要
    private static func detail(from data: Data) -> String {
        struct ErrorBody: Decodable {
            struct Err: Decodable { let message: String? }
            let error: Err?
            let message: String?
        }
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data),
           let msg = body.error?.message ?? body.message {
            return String(msg.prefix(120))
        }
        let rawText = String(data: data, encoding: .utf8) ?? ""
        return String(rawText.prefix(120))
    }

    /// 清理 AI 输出：去引号、去首尾空白与多余空行
    static func cleanText(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\n", with: " ")
        // 去掉包裹的整体引号
        let quotePairs: [(String, String)] = [("“", "”"), ("「", "」"), ("\"", "\""), ("‘", "’")]
        for (open, close) in quotePairs where text.count >= 2 && text.hasPrefix(open) && text.hasSuffix(close) {
            text = String(text.dropFirst(open.count).dropLast(close.count))
            break
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
