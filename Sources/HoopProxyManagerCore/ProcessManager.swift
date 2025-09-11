import Foundation

public class ProcessManager: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = ProcessManager()
    
    public var processes: [String: Process] = [:]
    public var connectionStatus: [String: ConnectionStatus] = [:]
    public var connectionLogs: [String: [String]] = [:]
    
    private init() {}
    
    public func connectToAll(connections: [String: Int]) async throws -> [Process] {
        print("Connecting...")
        var allProcesses: [Process] = []
        
        for (connection, port) in connections {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/env")
            process.arguments = ["hoop", "connect", connection, "-p", String(port)]
            
            processes[connection] = process
            connectionStatus[connection] = .connecting
            connectionLogs[connection] = []
            allProcesses.append(process)
        }

        return allProcesses
    }
    
    public func connect(connection: String, port: Int) async throws -> Process {
        connectionStatus[connection] = .connecting
        connectionLogs[connection] = []
        
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["hoop", "connect", connection, "-p", String(port)]
        
        // Set up output handling for GUI
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Monitor output in background
        Task { [weak self] in
            await self?.monitorProcessOutput(for: connection, outputPipe: outputPipe, errorPipe: errorPipe)
        }
        
        processes[connection] = process
        
        do {
            try process.run()
            connectionStatus[connection] = .connected
            addLog(for: connection, message: "Connected to \(connection) on port \(port)")
        } catch {
            connectionStatus[connection] = .error(error.localizedDescription)
            addLog(for: connection, message: "Failed to connect: \(error.localizedDescription)")
            throw error
        }
        
        return process
    }
    
    public func disconnect(connection: String) {
        if let process = processes[connection] {
            process.terminate()
            processes.removeValue(forKey: connection)
            connectionStatus[connection] = .disconnected
            addLog(for: connection, message: "Disconnected from \(connection)")
        }
    }
    
    public func killAll() {
        processes.forEach { (connection, process) in
            process.terminate()
            connectionStatus[connection] = .disconnected
            addLog(for: connection, message: "Force disconnected from \(connection)")
        }
        processes.removeAll()
    }
    
    private func monitorProcessOutput(for connection: String, outputPipe: Pipe, errorPipe: Pipe) async {
        let outputData = outputPipe.fileHandleForReading
        let errorData = errorPipe.fileHandleForReading
        
        // Monitor output
        Task { [weak self] in
            while true {
                let data = outputData.availableData
                if data.isEmpty { break }
                if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                    self?.addLog(for: connection, message: "OUT: \(line)")
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }
        
        // Monitor error
        Task { [weak self] in
            while true {
                let data = errorData.availableData
                if data.isEmpty { break }
                if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                    self?.addLog(for: connection, message: "ERR: \(line)")
                    // If we see an error, update status
                    if let currentStatus = self?.connectionStatus[connection],
                       currentStatus != .error("Process terminated") {
                        self?.connectionStatus[connection] = .error(line)
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }
    }
    
    private func addLog(for connection: String, message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        if connectionLogs[connection] == nil {
            connectionLogs[connection] = []
        }
        
        connectionLogs[connection]?.append(logMessage)
        
        // Keep only last 100 log entries per connection
        if let count = connectionLogs[connection]?.count, count > 100 {
            connectionLogs[connection]?.removeFirst(count - 100)
        }
        
        print(logMessage)
    }
    
    public func waitForEOF(input: FileHandle = FileHandle.standardInput) async throws {
        await withTaskCancellationHandler(operation: {
            var data: Data
            repeat {
                data = input.availableData  // Fetch available data continuously
                if !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                    print("Received line: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            } while !data.isEmpty  // Stop when no more data is available (EOF)
        }, onCancel: {
            print("EOF or cancellation received")
        })
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}