import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }

    // 1
    router.post("api", "acronyms") { req -> Future<Acronym> in
        // 2
        return try req.content.decode(Acronym.self)
            .flatMap(to: Acronym.self) { acronym in
                // 3
                return acronym.save(on: req)
        }
    }

    router.get("api", "acronyms") { req -> Future<[Acronym]> in
        // 2
        return Acronym.query(on: req).all()
    }

    router.get("api", "acronyms", Acronym.parameter) {
        req -> Future<Acronym> in
        // 2
        return try req.parameters.next(Acronym.self)
    }

    router.put("api", "acronyms", Acronym.parameter) {
        req -> Future<Acronym> in
        // 2
        return try flatMap(to: Acronym.self,
                           req.parameters.next(Acronym.self),
                           req.content.decode(Acronym.self)) {
                            acronym, updatedAcronym in
                            // 3
                            acronym.short = updatedAcronym.short
                            acronym.long = updatedAcronym.long
                            // 4
                            return acronym.save(on: req)
        }
    }

    router.delete("api", "acronyms", Acronym.parameter) {
        req -> Future<HTTPStatus> in
        // 2
        return try req.parameters.next(Acronym.self)
            // 3
            .delete(on: req)
            // 4
            .transform(to: HTTPStatus.noContent)
    }

    router.get("api", "acronyms", "search") {
        req -> Future<[Acronym]> in
        // 2
        guard
            let searchTerm = req.query[String.self, at: "term"] else {
                throw Abort(.badRequest)
        }
        // 3
        return Acronym.query(on: req).group(.or) { or in
            // 2
            or.filter(\.short == searchTerm)
            // 3
            or.filter(\.long == searchTerm)
            // 4
            }.all()
    }

    router.get("api", "acronyms", "first") {
        req -> Future<Acronym> in
        // 2
        return Acronym.query(on: req)
            .first()
            .map(to: Acronym.self) { acronym in
                // 3
                guard let acronym = acronym else {
                    throw Abort(.notFound)
                }
                // 4
                return acronym
        }
    }

    router.get("api", "acronyms", "sorted") {
        req -> Future<[Acronym]> in
        // 2
        return Acronym.query(on: req)
            .sort(\.short, .ascending)
            .all()
    }
}
