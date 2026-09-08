import Foundation

struct GitHubRepoResponse: Codable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let language: String?
    let stargazersCount: Int
}

// 💡 新增：匹配带有时间戳的 GitHub 新 JSON 结构
struct GitHubStarredItemResponse: Codable {
    let starredAt: String
    let repo: GitHubRepoResponse
}

class GitHubService {
    var personalAccessToken: String = ""
    
    enum APIError: Error {
        case invalidURL, networkError(Error), invalidResponse, rateLimited, decodingError(Error)
    }
    
    // 💡 注意返回类型的改变：现在返回的是包含“仓库”和“时间”的元组数组
    func fetchStarredRepos(for username: String) async throws -> [(repo: GitHubRepoResponse, starredAt: Date)] {
        var allItems: [(GitHubRepoResponse, Date)] = []
        var page = 1
        let perPage = 100
        var hasMorePages = true
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dateFormatter = ISO8601DateFormatter()
        
        while hasMorePages {
            let urlString = "https://api.github.com/users/\(username)/starred?per_page=\(perPage)&page=\(page)"
            guard let url = URL(string: urlString) else { throw APIError.invalidURL }
            
            var request = URLRequest(url: url)
            // 💡 核心改动：必须指定这个特殊的 Header，GitHub 才会返回标星时间
            request.setValue("application/vnd.github.star+json", forHTTPHeaderField: "Accept")
            if !personalAccessToken.isEmpty {
                request.setValue("Bearer \(personalAccessToken)", forHTTPHeaderField: "Authorization")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                if httpResponse.statusCode == 403 { throw APIError.rateLimited }
                guard httpResponse.statusCode == 200 else { throw APIError.invalidResponse }
                
                // 💡 解析新结构的 JSON
                let fetchedItems = try decoder.decode([GitHubStarredItemResponse].self, from: data)
                
                for item in fetchedItems {
                    let date = dateFormatter.date(from: item.starredAt) ?? Date()
                    allItems.append((item.repo, date))
                }
                
                if fetchedItems.count < perPage {
                    hasMorePages = false
                } else {
                    page += 1
                }
            } catch let error as DecodingError {
                throw APIError.decodingError(error)
            } catch {
                throw APIError.networkError(error)
            }
        }
        return allItems
    }
}
