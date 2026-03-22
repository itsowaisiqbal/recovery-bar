import Foundation
import Network

enum LocalAuthServerError: LocalizedError {
    case failedToStart(Error)
    case timeout
    case cancelled
    case invalidCallback
    case stateMismatch

    var errorDescription: String? {
        switch self {
        case .failedToStart(let error):
            return "Failed to start local auth server: \(error.localizedDescription)"
        case .timeout:
            return "OAuth callback timed out"
        case .cancelled:
            return "OAuth flow was cancelled"
        case .invalidCallback:
            return "Invalid OAuth callback received"
        case .stateMismatch:
            return "OAuth state mismatch — possible CSRF attack"
        }
    }
}

/// Lightweight local HTTP server that listens for the OAuth callback on localhost
actor LocalAuthServer {
    private var listener: NWListener?
    private let port: UInt16
    private let expectedState: String?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(port: UInt16 = Constants.OAuth.callbackPort, expectedState: String? = nil) {
        self.port = port
        self.expectedState = expectedState
    }

    /// Start listening and wait for the OAuth callback code
    func waitForCallback(timeout: TimeInterval = 300) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            do {
                let params = NWParameters.tcp
                let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: self.port)!)
                self.listener = listener

                listener.stateUpdateHandler = { [weak self] state in
                    if case .failed(let error) = state {
                        Task { await self?.fail(with: LocalAuthServerError.failedToStart(error)) }
                    }
                }

                listener.newConnectionHandler = { [weak self] connection in
                    Task { await self?.handleConnection(connection) }
                }

                listener.start(queue: .global(qos: .userInitiated))

                // Timeout (cancel on success/failure)
                self.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    await self?.fail(with: LocalAuthServerError.timeout)
                }
            } catch {
                continuation.resume(throwing: LocalAuthServerError.failedToStart(error))
                self.continuation = nil
            }
        }
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            Task {
                guard let self = self else { return }

                if let error = error {
                    await self.sendResponse(connection: connection, statusCode: 500, body: "Server error")
                    await self.fail(with: error)
                    return
                }

                guard let data = data,
                      let requestString = String(data: data, encoding: .utf8) else {
                    await self.sendResponse(connection: connection, statusCode: 400, body: "Bad request")
                    return
                }

                await self.processRequest(requestString, connection: connection)
            }
        }
    }

    private func processRequest(_ request: String, connection: NWConnection) {
        // Parse GET /callback?code=xxx&state=yyy HTTP/1.1
        guard let firstLine = request.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad request")
            return
        }

        let pathString = String(pathPart)

        guard pathString.hasPrefix("/callback"),
              let components = URLComponents(string: "http://localhost\(pathString)"),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {

            // Check for error parameter
            if let components = URLComponents(string: "http://localhost\(pathString)"),
               let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                let description = components.queryItems?.first(where: { $0.name == "error_description" })?.value ?? error
                sendResponse(
                    connection: connection,
                    statusCode: 200,
                    body: authErrorHTML(description)
                )
                fail(with: AuthProxyError.httpError(statusCode: 400, message: description))
            } else {
                sendResponse(connection: connection, statusCode: 400, body: "Missing authorization code")
            }
            return
        }

        // CSRF: Validate state parameter matches what we sent
        if let expectedState = expectedState {
            let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
            guard returnedState == expectedState else {
                sendResponse(
                    connection: connection,
                    statusCode: 400,
                    body: authErrorHTML("State mismatch — please try again")
                )
                fail(with: LocalAuthServerError.stateMismatch)
                return
            }
        }

        sendResponse(
            connection: connection,
            statusCode: 200,
            body: authSuccessHTML
        )

        succeed(with: code)
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText = statusCode == 200 ? "OK" : "Error"
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func succeed(with code: String) {
        continuation?.resume(returning: code)
        continuation = nil
        stop()
    }

    private func fail(with error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        stop()
    }

    // MARK: - HTML Templates

    private var authSuccessHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>WHOOP Menubar</title></head>
        <body style="font-family: -apple-system, system-ui; text-align: center; padding: 60px;">
            <h1>Signed in successfully</h1>
            <p>You can close this tab and return to the app.</p>
        </body>
        </html>
        """
    }

    private func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func authErrorHTML(_ message: String) -> String {
        let safeMessage = htmlEscape(message)
        return """
        <!DOCTYPE html>
        <html>
        <head><title>Recovery Hub</title></head>
        <body style="font-family: -apple-system, system-ui; text-align: center; padding: 60px;">
            <h1>Authentication Failed</h1>
            <p>\(safeMessage)</p>
            <p>Please close this tab and try again.</p>
        </body>
        </html>
        """
    }
}
