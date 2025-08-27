import Foundation
import Combine

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data) async throws -> T
    func download(_ url: URL) async throws -> Data
}

// MARK: - Network Service
final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    private let session: URLSession
    private let baseURL: URL
    private var authToken: String?
    private var refreshToken: String?
    
    // MARK: - Initialization
    init() {
        self.session = URLSession.shared
        self.baseURL = URL(string: "https://api.trainerly.com")! // Will be configurable
        
        // Load stored tokens
        loadStoredTokens()
    }
    
    // MARK: - Public Methods
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Validate response
            try validateResponse(response)
            
            // Decode response
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
            
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }
    
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data) async throws -> T {
        var request = try buildRequest(for: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        do {
            let (responseData, response) = try await session.data(for: request)
            
            // Validate response
            try validateResponse(response)
            
            // Decode response
            let decodedResponse = try JSONDecoder().decode(T.self, from: responseData)
            return decodedResponse
            
        } catch {
            throw NetworkError.uploadFailed(error)
        }
    }
    
    func download(_ url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Validate response
            try validateResponse(response)
            
            return data
            
        } catch {
            throw NetworkError.downloadFailed(error)
        }
    }
    
    // MARK: - Authentication
    func setAuthToken(_ token: String) {
        self.authToken = token
        saveStoredTokens()
    }
    
    func setRefreshToken(_ token: String) {
        self.refreshToken = token
        saveStoredTokens()
    }
    
    func clearTokens() {
        self.authToken = nil
        self.refreshToken = nil
        clearStoredTokens()
    }
    
    // MARK: - Private Methods
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        
        // Add query parameters
        if !endpoint.queryParameters.isEmpty {
            components?.queryItems = endpoint.queryParameters.map { key, value in
                URLQueryItem(name: key, value: String(describing: value))
            }
        }
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30
        
        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Trainerly-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body for POST/PUT requests
        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Token Storage
    private func loadStoredTokens() {
        // Load from Keychain or UserDefaults
        // This is a simplified implementation
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            self.authToken = token
        }
        
        if let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") {
            self.refreshToken = refreshToken
        }
    }
    
    private func saveStoredTokens() {
        // Save to Keychain or UserDefaults
        // This is a simplified implementation
        if let token = authToken {
            UserDefaults.standard.set(token, forKey: "authToken")
        }
        
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        }
    }
    
    private func clearStoredTokens() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
    }
}

// MARK: - API Endpoint
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let queryParameters: [String: Any]
    let headers: [String: String]
    let body: [String: Any]?
    
    init(
        path: String,
        method: HTTPMethod = .GET,
        queryParameters: [String: Any] = [:],
        headers: [String: String] = [:],
        body: [String: Any]? = nil
    ) {
        self.path = path
        self.method = method
        self.queryParameters = queryParameters
        self.headers = headers
        self.body = body
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case requestFailed(Error)
    case uploadFailed(Error)
    case downloadFailed(Error)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests"
        case .serverError(let code):
            return "Server error: \(code)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Endpoints
extension APIEndpoint {
    // Authentication
    static func login(email: String, password: String) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/login",
            method: .POST,
            body: [
                "email": email,
                "password": password
            ]
        )
    }
    
    static func register(userData: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/register",
            method: .POST,
            body: userData
        )
    }
    
    static func refreshToken(_ token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/refresh",
            method: .POST,
            body: ["refresh_token": token]
        )
    }
    
    // Workouts
    static func getWorkouts(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        APIEndpoint(
            path: "/workouts",
            queryParameters: [
                "page": page,
                "limit": limit
            ]
        )
    }
    
    static func getWorkout(id: String) -> APIEndpoint {
        APIEndpoint(path: "/workouts/\(id)")
    }
    
    static func createWorkout(workoutData: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/workouts",
            method: .POST,
            body: workoutData
        )
    }
    
    static func updateWorkout(id: String, workoutData: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/workouts/\(id)",
            method: .PUT,
            body: workoutData
        )
    }
    
    static func deleteWorkout(id: String) -> APIEndpoint {
        APIEndpoint(
            path: "/workouts/\(id)",
            method: .DELETE
        )
    }
    
    // User Profile
    static func getUserProfile() -> APIEndpoint {
        APIEndpoint(path: "/user/profile")
    }
    
    static func updateUserProfile(profileData: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/user/profile",
            method: .PUT,
            body: profileData
        )
    }
    
    // AI Coach
    static func getAICoachMessage(context: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/coach/message",
            method: .POST,
            body: context
        )
    }
    
    static func generateWorkout(parameters: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/workout/generate",
            method: .POST,
            body: parameters
        )
    }
    
    // Form Analysis
    static func analyzeForm(imageData: Data) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/form/analyze",
            method: .POST,
            body: ["image": imageData.base64EncodedString()]
        )
    }
    
    // Health Data
    static func syncHealthData(healthData: [String: Any]) -> APIEndpoint {
        APIEndpoint(
            path: "/health/sync",
            method: .POST,
            body: healthData
        )
    }
    
    // Analytics
    static func getAnalytics(period: String, metrics: [String]) -> APIEndpoint {
        APIEndpoint(
            path: "/analytics",
            queryParameters: [
                "period": period,
                "metrics": metrics.joined(separator: ",")
            ]
        )
    }
}
