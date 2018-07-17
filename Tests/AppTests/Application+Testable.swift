import Vapor
@testable import App
import Authentication
import FluentPostgreSQL

extension Application {

    static func testable(envArgs: [String]? = nil) throws -> Application {
        var config = Config.default()
        var services = Services.default()
        var env = Environment.testing
        if let environmentArgs = envArgs {
            env.arguments = environmentArgs
        }
        try App.configure(&config, &env, &services)
        let app = try Application(
            config: config,
            environment: env,
            services: services)
        try App.boot(app)
        return app
    }

    static func reset() throws {
        let revertEnvironment = ["vapor", "revert", "--all", "-y"]
        try Application.testable(envArgs: revertEnvironment)
            .asyncRun()
            .wait()
        let migrateEnvironment = ["vapor", "migrate", "-y"]
        try Application.testable(envArgs: migrateEnvironment)
            .asyncRun()
            .wait()
    }

    func sendRequest<T>(
        to path: String,
        method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        body: T? = nil,
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil) throws -> Response where T: Content {

        var headers = headers
        // 1
        if (loggedInRequest || loggedInUser != nil) {
            let username: String
            // 2
            if let user = loggedInUser {
                username = user.username
            } else {
                username = "admin"
            }
            // 3
            let credentials = BasicAuthorization(
                username: username,
                password: "password")

            // 4
            var tokenHeaders = HTTPHeaders()
            tokenHeaders.basicAuthorization = credentials

            // 5
            let tokenResponse = try self.sendRequest(
                to: "/api/users/login",
                method: .POST,
                headers: tokenHeaders)
            // 6
            let token = try tokenResponse.content.syncDecode(Token.self)
            // 7
            headers.add(name: .authorization,
                        value: "Bearer \(token.token)")
        }


        let responder = try self.make(Responder.self)
        // 2
        let request = HTTPRequest(
            method: method,
            url: URL(string: path)!,
            headers: headers)
        let wrappedRequest = Request(http: request, using: self)
        // 3
        if let body = body {
            try wrappedRequest.content.encode(body)
        }
        // 4
        return try responder.respond(to: wrappedRequest).wait()
    }

    func sendRequest(
        to path: String,
        method: HTTPMethod,
        headers: HTTPHeaders = .init(),
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil
        ) throws -> Response {
        let emptyContent: EmptyContent? = nil
        return try sendRequest(
            to: path, method: method,
            headers: headers, body: emptyContent,
            loggedInRequest: loggedInRequest,
            loggedInUser: loggedInUser)
    }

    func getResponse<C, T>(
        to path: String,
        method: HTTPMethod = .GET,
        headers: HTTPHeaders = .init(),
        data: C? = nil, decodeTo type: T.Type,
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil
        ) throws -> T where C: Content, T: Decodable {
        let response = try self.sendRequest(
            to: path, method: method,
            headers: headers, body: data,
            loggedInRequest: loggedInRequest,
            loggedInUser: loggedInUser)
        return try response.content.decode(type).wait()
    }

    func getResponse<T>(
        to path: String,
        method: HTTPMethod = .GET,
        headers: HTTPHeaders = .init(),
        decodeTo type: T.Type,
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil
        ) throws -> T where T: Content {
        let emptyContent: EmptyContent? = nil
        return try self.getResponse(
            to: path, method: method,
            headers: headers, data: emptyContent,
            decodeTo: type,
            loggedInRequest: loggedInRequest,
            loggedInUser: loggedInUser)
    }

    func sendRequest<T>(
        to path: String,
        method: HTTPMethod,
        headers: HTTPHeaders,
        data: T,
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil
        ) throws where T: Content {
        _ = try self.sendRequest(
            to: path, method: method,
            headers: headers, body: data,
            loggedInRequest: loggedInRequest,
            loggedInUser: loggedInUser)
    }
}

struct EmptyContent: Content {}
