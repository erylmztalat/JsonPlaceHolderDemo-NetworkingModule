# Network Module Documentation
The network module is a framework designed to facilitate HTTP-based network communication in your Swift application. It's built around the concept of making requests to a server and handling responses. Here's a summary of the key components:

## Components

### NetworkRequest
NetworkRequest is a protocol that represents a network request. This includes the endpoint for the request, the HTTP method, headers, and parameters. Each specific network request should conform to this protocol, and specify the expected response type.

### NetworkServiceProtocol
NetworkServiceProtocol is a protocol that represents a service which can perform network requests. The main function perform(_:) takes an instance of a NetworkRequest and returns a publisher that emits either the decoded response or an error.

### URLSessionProtocol
URLSessionProtocol is a protocol that wraps the URLSession functionality needed by NetworkService. The main function sessionDataTaskPublisher(for:) takes a URLRequest and returns a publisher that emits a tuple of the data and URL response, or an error.

### NetworkService
NetworkService is the class that handles network requests. It has an initializer that accepts an instance conforming to URLSessionProtocol (default is URLSession.shared), and it implements NetworkServiceProtocol.

### NetworkError
NetworkError is an enum that represents the possible failure cases when performing a network request. It includes cases such as invalid request, encoding error, decoding error, server errors (with HTTP status code), unexpected response, no internet, and an unknown error.

### Testing
The module includes a set of unit tests to ensure its correctness. This includes tests for success and failure scenarios. The tests use a mock URLSessionProtocol to simulate responses from the server.

### Future Work
This module provides a basic implementation for network communication. Future improvements might include adding support for other HTTP methods (like PUT, DELETE, etc.), improved error handling, caching, and more.
