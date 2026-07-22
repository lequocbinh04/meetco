import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    public var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    public static func encode<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONCoding.encoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

public struct MCPRequest: Codable, Equatable, Sendable {
    public var jsonrpc: String
    public var id: JSONValue?
    public var method: String
    public var params: JSONValue?

    public init(jsonrpc: String = "2.0", id: JSONValue?, method: String, params: JSONValue? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct MCPErrorPayload: Codable, Equatable, Sendable {
    public var code: Int
    public var message: String
}

public struct MCPResponse: Codable, Equatable, Sendable {
    public var jsonrpc = "2.0"
    public var id: JSONValue
    public var result: JSONValue?
    public var error: MCPErrorPayload?

    public static func success(id: JSONValue, result: JSONValue) -> MCPResponse {
        MCPResponse(id: id, result: result, error: nil)
    }

    public static func failure(id: JSONValue, code: Int, message: String) -> MCPResponse {
        MCPResponse(id: id, result: nil, error: MCPErrorPayload(code: code, message: message))
    }
}
