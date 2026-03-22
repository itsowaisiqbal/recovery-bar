import Foundation

enum WhoopEndpoint {
    case profile
    case cycles(start: Date?, end: Date?, limit: Int?)
    case recovery(start: Date?, end: Date?, limit: Int?)
    case sleep(start: Date?, end: Date?, limit: Int?)

    var path: String {
        switch self {
        case .profile:
            return "/user/profile/basic"
        case .cycles:
            return "/cycle"
        case .recovery:
            return "/recovery"
        case .sleep:
            return "/activity/sleep"
        }
    }

    var queryItems: [URLQueryItem] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        switch self {
        case .profile:
            return []

        case .cycles(let start, let end, let limit),
             .recovery(let start, let end, let limit),
             .sleep(let start, let end, let limit):

            var items: [URLQueryItem] = []

            if let start = start {
                items.append(URLQueryItem(name: "start", value: formatter.string(from: start)))
            }
            if let end = end {
                items.append(URLQueryItem(name: "end", value: formatter.string(from: end)))
            }
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }

            return items
        }
    }

    var url: URL {
        var components = URLComponents(string: Constants.API.baseURL + path)!
        let items = queryItems
        if !items.isEmpty {
            components.queryItems = items
        }
        return components.url!
    }
}
