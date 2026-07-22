import Foundation
import Testing
@testable import MeetcoCore

@Suite("Agent process runner")
struct ProcessRunnerTests {
    @Test
    func passesStdinUsesCleanCWDAndTimesOut() async throws {
        let runner = ProcessRunner()
        let cwd = try ProcessRunner.makeCleanWorkingDirectory()
        defer { try? FileManager.default.removeItem(at: cwd) }

        let echoed = try await runner.run(.init(
            executableURL: URL(fileURLWithPath: "/bin/cat"),
            arguments: [],
            standardInput: Data("meeting context".utf8),
            workingDirectory: cwd
        ))
        #expect(String(decoding: echoed.standardOutput, as: UTF8.self) == "meeting context")

        let pwd = try await runner.run(.init(
            executableURL: URL(fileURLWithPath: "/bin/pwd"),
            arguments: [],
            workingDirectory: cwd
        ))
        let reportedCWD = URL(fileURLWithPath: String(decoding: pwd.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)).resolvingSymlinksInPath()
        #expect(reportedCWD == cwd.resolvingSymlinksInPath())

        await #expect(throws: AgentProviderError.self) {
            _ = try await runner.run(.init(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["2"],
                workingDirectory: cwd,
                timeoutSeconds: 0.1
            ))
        }
    }

    @Test
    func buffersSplitJSONLines() {
        let lines = IncrementalLineBuffer()
        #expect(lines.append(Data("{\"type\":\"item".utf8)).isEmpty)
        let completed = lines.append(Data(".completed\"}\nnext".utf8))
        #expect(completed.count == 1)
        #expect(String(decoding: completed[0], as: UTF8.self).contains("item.completed"))
        #expect(String(decoding: lines.finish() ?? Data(), as: UTF8.self) == "next")
    }
}
