import Darwin
import Foundation

public struct ProcessRequest: Equatable, Sendable {
    public var executableURL: URL
    public var arguments: [String]
    public var standardInput: Data
    public var workingDirectory: URL
    public var environment: [String: String]
    public var timeoutSeconds: Double

    public init(
        executableURL: URL,
        arguments: [String],
        standardInput: Data = Data(),
        workingDirectory: URL,
        environment: [String: String] = [:],
        timeoutSeconds: Double = 90
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.standardInput = standardInput
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct ProcessResult: Equatable, Sendable {
    public var standardOutput: Data
    public var standardError: Data
    public var exitCode: Int32

    public init(standardOutput: Data, standardError: Data, exitCode: Int32) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitCode = exitCode
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process: Process
    private let lock = NSLock()
    private var terminationRequested = false

    init(_ process: Process) {
        self.process = process
    }

    func terminate() {
        let shouldTerminate = lock.withLock {
            guard !terminationRequested else { return false }
            terminationRequested = true
            return true
        }
        guard shouldTerminate, process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            if self.process.isRunning { Darwin.kill(pid, SIGKILL) }
        }
    }

    var isRunning: Bool { process.isRunning }
    var terminationStatus: Int32 { process.terminationStatus }
}

public struct ProcessRunner: Sendable {
    public init() {}

    public func run(
        _ request: ProcessRequest,
        onStandardOutput: @escaping @Sendable (Data) -> Void = { _ in }
    ) async throws -> ProcessResult {
        let process = Process()
        let box = ProcessBox(process)
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectory
        process.environment = Self.environment(overrides: request.environment)
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        do {
            try process.run()
        } catch {
            throw AgentProviderError.unavailable("Could not launch \(request.executableURL.lastPathComponent).")
        }

        let outputTask = Task.detached(priority: .userInitiated) {
            Self.drain(outputPipe.fileHandleForReading, onChunk: onStandardOutput)
        }
        let errorTask = Task.detached(priority: .utility) {
            Self.drain(errorPipe.fileHandleForReading, onChunk: { _ in })
        }
        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: request.standardInput)
            try inputPipe.fileHandleForWriting.close()
        } catch {
            box.terminate()
        }

        do {
            let exitCode = try await withTaskCancellationHandler {
                try await Self.waitForExit(
                    timeoutSeconds: request.timeoutSeconds,
                    process: box
                )
            } onCancel: {
                box.terminate()
            }
            let standardOutput = await outputTask.value
            let standardError = await errorTask.value
            return ProcessResult(
                standardOutput: standardOutput,
                standardError: standardError,
                exitCode: exitCode
            )
        } catch {
            box.terminate()
            await Self.waitUntilStopped(box)
            _ = await outputTask.value
            _ = await errorTask.value
            if error is CancellationError { throw AgentProviderError.cancelled }
            throw error
        }
    }

    public static func findExecutable(named name: String, explicitPath: String? = nil) -> URL? {
        if let explicitPath, FileManager.default.isExecutableFile(atPath: explicitPath) {
            return URL(fileURLWithPath: explicitPath)
        }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        return path.split(separator: ":").lazy
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public static func makeCleanWorkingDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoAgent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func waitForExit(
        timeoutSeconds: Double,
        process: ProcessBox
    ) async throws -> Int32 {
        let deadline = Date().addingTimeInterval(max(0.1, timeoutSeconds))
        while process.isRunning {
            try Task.checkCancellation()
            if Date() >= deadline {
                process.terminate()
                await waitUntilStopped(process)
                throw AgentProviderError.timedOut
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        return process.terminationStatus
    }

    private static func waitUntilStopped(_ process: ProcessBox) async {
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func drain(
        _ handle: FileHandle,
        onChunk: @Sendable (Data) -> Void
    ) -> Data {
        var result = Data()
        while true {
            let chunk = handle.availableData
            guard !chunk.isEmpty else { break }
            result.append(chunk)
            onChunk(chunk)
        }
        return result
    }

    private static func environment(overrides: [String: String]) -> [String: String] {
        let current = ProcessInfo.processInfo.environment
        let allowed = ["PATH", "HOME", "TMPDIR", "LANG", "LC_ALL", "USER", "LOGNAME", "SHELL"]
        var clean = Dictionary(uniqueKeysWithValues: allowed.compactMap { key in
            current[key].map { (key, $0) }
        })
        clean.merge(overrides) { _, replacement in replacement }
        clean["NO_COLOR"] = "1"
        return clean
    }
}
