import Foundation
import Combine

/// Represents HTTP methods for RESTful services.
public enum RequestMethod: String {
    case get = "GET"
    case post = "POST"
}

/// An error type representing failure cases in the `NetworkService`.
public enum NetworkError: Error {
    // Error cases with a brief explanation
    case invalidRequest // The request was not valid.
    case encodingError // There was an error encoding the parameters.
    case decodingError // There was an error decoding the response.
    case serverError(Int) // There was a server error. The associated value is the HTTP status code.
    case unexpectedResponse // The server's response was unexpected.
    case noInternet // There is no Internet connection.
    case unknownError // An unknown error occurred.

    /// A localized message describing what error occurred.
    var localizedDescription: String {
        switch self {
        case .invalidRequest:
            return "Invalid request"
        case .encodingError:
            return "Failed to encode the parameters"
        case .decodingError:
            return "Failed to decode the response"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .unexpectedResponse:
            return "Unexpected response from the server"
        case .noInternet:
            return "No internet connection"
        case .unknownError:
            return "Unknown network error"
        }
    }
}

/// Represents a network request.
public protocol NetworkRequest {
    associatedtype Response: Decodable

    /// The endpoint for the request.
    var endpoint: String { get }
    
    /// The HTTP method for the request.
    var method: RequestMethod { get }
    
    /// The HTTP headers to include with the request.
    var headers: [String : String]? { get }
    
    /// The parameters to include with the request.
    var parameters: [String: Any]? { get }
}

/// A service that can perform network requests.
public protocol NetworkServiceProtocol {
    /// Performs the given network request and returns a publisher that emits either the decoded response or an error.
    ///
    /// - Parameter request: The network request to perform.
    func perform<T: NetworkRequest>(_ request: T) -> AnyPublisher<T.Response, NetworkError>
}

/// Protocol defining necessary URLSession functionality for the `NetworkService`.
public protocol URLSessionProtocol {
    /// Returns a publisher that wraps a URL session data task for a given URL request.
    ///
    /// - Parameter request: The URL request to perform.
    /// - Returns: A publisher that emits a tuple of the data and URL response, or an error.
    func sessionDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError>
}

/// Extension to make `URLSession` conform to `URLSessionProtocol`.
extension URLSession: URLSessionProtocol {
    public func sessionDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        return self.dataTaskPublisher(for: request)
            .map { ($0.data, $0.response) }
            .eraseToAnyPublisher()
    }
}

/// A service that handles network requests.
public final class NetworkService: NetworkServiceProtocol {

    private let urlSession: URLSessionProtocol

    /// Creates a new instance of `NetworkService`.
    ///
    /// - Parameter urlSession: The URL session to use for the network requests. Defaults to `URLSession.shared`.
    public init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
    }

    /// Performs the given network request and returns a publisher that emits either the decoded response or an error.
    ///
    /// - Parameter request: The network request to perform.
    public func perform<T>(_ request: T) -> AnyPublisher<T.Response, NetworkError> where T : NetworkRequest {
        guard let url = URL(string: request.endpoint) else {
            return Fail(error: NetworkError.invalidRequest).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        if let headers = request.headers {
            for (key, value) in headers {
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let parameters = request.parameters {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: parameters)
                urlRequest.httpBody = jsonData
            } catch {
                return Fail(error: NetworkError.encodingError).eraseToAnyPublisher()
            }
        }
        
        return urlSession.sessionDataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
                }
                return data
            }
            .decode(type: T.Response.self, decoder: JSONDecoder())
            .mapError { error in
                if let urlError = error as? URLError, urlError.code == URLError.notConnectedToInternet {
                    return NetworkError.noInternet
                } else if error is DecodingError {
                    return NetworkError.decodingError
                } else {
                    return NetworkError.unknownError
                }
            }
            .eraseToAnyPublisher()
    }
}
