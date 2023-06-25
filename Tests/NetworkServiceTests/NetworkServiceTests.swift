import XCTest
import Combine
@testable import NetworkService

/// `NetworkServiceTests` is a test case class designed to test `NetworkService` operations.
final class NetworkServiceTests: XCTestCase {
    
    var mockURLSession: MockURLSession!
    var networkService: NetworkService!
    var mockRequest: MockRequest!
    var cancellables = Set<AnyCancellable>()
    
    /// Sets up the required objects before each test is run.
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        networkService = NetworkService(urlSession: mockURLSession)
        mockRequest = MockRequest()
    }
    
    /// Clean up after each test run.
    override func tearDown() {
        networkService = nil
        mockURLSession = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    /// This helper function is to simulate network request and to verify the responses.
    func performTest(data: Data?, response: URLResponse?, error: URLError?, expectedMessage: String?) {
        mockURLSession.data = data
        mockURLSession.response = response
        mockURLSession.error = error
        var result: Result<MockData, NetworkError>?
        let expect = expectation(description: "Network Service Expectation")
        
        networkService.perform(mockRequest)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    break
                }
                expect.fulfill()
            }, receiveValue: { response in
                result = .success(response)
            })
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1, handler: nil)
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.message, expectedMessage)
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, NetworkError.noInternet.localizedDescription)
        case .none:
            XCTFail("No response received")
        }
    }
    
    /// Test the case where the request is successful.
    func testPerform_WithSuccessfulResponse() {
        let mockData = "{\"message\":\"Success\"}".data(using: .utf8)!
        let mockURLResponse = HTTPURLResponse(url: URL(string: "https://test.com")!,
                                              statusCode: 200,
                                              httpVersion: nil,
                                              headerFields: nil)!
        
        performTest(data: mockData, response: mockURLResponse, error: nil, expectedMessage: "Success")
    }
    
    /// Test the case where the request results in an error.
    func testPerform_WithErrorResponse() {
        let error = URLError(.notConnectedToInternet)
        performTest(data: nil, response: nil, error: error, expectedMessage: nil)
    }

}

/// A mock data structure for testing.
struct MockData: Decodable {
    let message: String
}

/// `MockURLSession` is a mock implementation of `URLSessionProtocol` for testing.
class MockURLSession: URLSessionProtocol {
    var data: Data?
    var response: URLResponse?
    var error: URLError?
    
    func sessionDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        if let error = error {
            return Fail(error: error).eraseToAnyPublisher()
        } else if let data = data, let response = response {
            return Just((data: data, response: response))
                .setFailureType(to: URLError.self)
                .eraseToAnyPublisher()
        } else {
            fatalError("Didn't set data or error in MockURLSession")
        }
    }
}

/// A mock request for testing.
struct MockRequest: NetworkRequest {
    typealias Response = MockData

    var endpoint: URL? {
        return URL(string: "https://test.com")!
    }

    var method: RequestMethod {
        return .get
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }

    var parameters: [String: Any]? {
        return nil
    }
}






