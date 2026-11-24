import Foundation
import AttacheCore

struct HDIResult: Sendable {
    var status: Int32
    var stdout: Data
    var log: String
}

@MainActor
final class AttacheService {
    static let binaryPath = "/usr/bin/hdiutil"
    static let diskutilPath = "/usr/sbin/diskutil"

    private let jobs = ProcessRunner(exclusive: true)
    private let probes = ProcessRunner(exclusive: false)

    var isJobRunning: Bool { jobs.isRunning }

    func cancelJob() {
        jobs.cancel()
    }

    func runJob(
        _ request: HDIRequest,
        onProgress: @escaping @MainActor (Double?) -> Void,
        onLog: @escaping @MainActor (String) -> Void
    ) async throws -> HDIResult {
        try await launch(on: jobs, request: request, onProgress: onProgress, onLog: onLog)
    }

    func runProbe(
        _ request: HDIRequest,
        onProgress: @escaping @MainActor (Double?) -> Void = { _ in },
        onLog: @escaping @MainActor (String) -> Void = { _ in }
    ) async throws -> HDIResult {
        try await launch(on: probes, request: request, onProgress: onProgress, onLog: onLog)
    }

    func listDevices() async -> [DiskDevice] {
        guard FileManager.default.isExecutableFile(atPath: Self.diskutilPath) else { return [] }
        do {
            let result = try await probes.launch(
                executable: Self.diskutilPath,
                arguments: ["list", "-plist"],
                password: nil,
                onProgress: { _ in },
                onLog: { _ in }
            )
            return PlistParsing.parseDiskutilDevices(from: result.stdout)
        } catch {
            return []
        }
    }

    private func launch(
        on runner: ProcessRunner,
        request: HDIRequest,
        onProgress: @escaping @MainActor (Double?) -> Void,
        onLog: @escaping @MainActor (String) -> Void
    ) async throws -> HDIResult {
        guard FileManager.default.isExecutableFile(atPath: request.executablePath) else {
            throw AttacheError.missingBinary(path: request.executablePath)
        }
        return try await runner.launch(
            executable: request.executablePath,
            arguments: request.processArguments,
            password: request.password,
            newlinePassphrase: request.newlinePassphrase,
            onProgress: { value in
                DispatchQueue.main.async { onProgress(value) }
            },
            onLog: { line in
                DispatchQueue.main.async { onLog(line) }
            }
        )
    }
}

final class ProcessRunner: @unchecked Sendable {
    private let exclusive: Bool
    private let lock = NSLock()
    private var current: Process?

    init(exclusive: Bool) {
        self.exclusive = exclusive
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return current?.isRunning == true
    }

    func cancel() {
        guard exclusive else { return }
        takeCurrent()?.terminate()
    }

    private func claim(_ process: Process) -> Bool {
        lock.lock()
        let busy = current?.isRunning == true
        if !busy {
            current = process
        }
        lock.unlock()
        return !busy
    }

    private func takeCurrent() -> Process? {
        lock.lock()
        let process = current
        current = nil
        lock.unlock()
        return process
    }

    private func clearIfCurrent(_ process: Process) {
        lock.lock()
        if current === process { current = nil }
        lock.unlock()
    }

    func launch(
        executable: String,
        arguments: [String],
        password: String?,
        newlinePassphrase: Bool = false,
        onProgress: @escaping @Sendable (Double?) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> HDIResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.qualityOfService = exclusive ? .userInitiated : .utility

        if exclusive {
            if !claim(process) {
                throw AttacheError.busy
            }
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        let inPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = inPipe

        let stdoutBox = DataBox()
        let logBox = DataBox()
        let outBuffer = LineBuffer()
        let errBuffer = LineBuffer()
        let lineLock = NSLock()

        let consume: @Sendable (Data, Bool) -> Void = { chunk, isStdout in
            if isStdout { stdoutBox.append(chunk) }
            logBox.append(chunk)
            lineLock.lock()
            let lines = (isStdout ? outBuffer : errBuffer).push(chunk)
            lineLock.unlock()
            for line in lines {
                emit(line: line, onProgress: onProgress, onLog: onLog)
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { consume(data, true) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { consume(data, false) }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let once = ResumeOnce(continuation)
                process.terminationHandler = { [weak self] proc in
                    let leftoverOut = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let leftoverErr = errPipe.fileHandleForReading.readDataToEndOfFile()
                    if !leftoverOut.isEmpty { consume(leftoverOut, true) }
                    if !leftoverErr.isEmpty { consume(leftoverErr, false) }
                    lineLock.lock()
                    let leftoverLines = outBuffer.flush() + errBuffer.flush()
                    lineLock.unlock()
                    for line in leftoverLines {
                        emit(line: line, onProgress: onProgress, onLog: onLog)
                    }
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    if let self, self.exclusive {
                        self.clearIfCurrent(proc)
                    }
                    let result = HDIResult(
                        status: proc.terminationStatus,
                        stdout: stdoutBox.data,
                        log: logBox.string
                    )
                    once.resume(.success(result))
                }

                do {
                    try process.run()
                    if let password, !password.isEmpty {
                        var payload = Data(password.utf8)
                        payload.append(newlinePassphrase ? 0x0A : 0x00)
                        try inPipe.fileHandleForWriting.write(contentsOf: payload)
                    }
                    try inPipe.fileHandleForWriting.close()
                } catch {
                    if exclusive {
                        clearIfCurrent(process)
                    }
                    once.resume(.failure(error))
                }
            }
        } onCancel: { [weak self] in
            if self?.exclusive == true {
                self?.cancel()
            }
        }
    }
}

private func emit(
    line: String,
    onProgress: @escaping @Sendable (Double?) -> Void,
    onLog: @escaping @Sendable (String) -> Void
) {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    if ConsoleText.isHdiutilDeprecation(trimmed) { return }
    if let percent = CommandBuilder.parsePercentLine(trimmed) {
        onProgress(percent < 0 ? nil : percent / 100.0)
        return
    }
    onLog(trimmed)
}

private final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(with: result)
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var string: String {
        String(data: data, encoding: .utf8) ?? ""
    }
}

private final class LineBuffer: @unchecked Sendable {
    private var pending = Data()

    func push(_ chunk: Data) -> [String] {
        pending.append(chunk)
        var lines: [String] = []
        while let range = pending.firstRange(of: Data([0x0A])) {
            let lineData = pending.subdata(in: pending.startIndex..<range.lowerBound)
            pending.removeSubrange(pending.startIndex...range.lowerBound)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
            }
        }
        return lines
    }

    func flush() -> [String] {
        guard !pending.isEmpty else { return [] }
        let line = String(data: pending, encoding: .utf8)
        pending.removeAll()
        return line.map { [$0] } ?? []
    }
}
