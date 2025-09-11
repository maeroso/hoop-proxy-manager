import Foundation
import ArgumentParser
import HoopProxyManagerCore

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

struct ConnectCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "connect",
        abstract: "Connect to all configured Hoop instances"
    )
    
    @Flag(name: .shortAndLong, help: "Run in verbose mode")
    var verbose = false
    
    func run() async throws {
        let configManager = ConfigManager()
        
        if verbose { print("Starting Hoop CLI...") }
        
        // Register signal handlers for Linux/macOS
        signal(SIGINT) { signal in
            print("Caught SIGINT (Ctrl+C), exiting gracefully...")
            ProcessManager.shared.killAll()
            ConnectCommand.exit()
        }
        signal(SIGTERM) { signal in
            print("Caught SIGTERM (Termination), exiting gracefully...")
            ProcessManager.shared.killAll()
            ConnectCommand.exit()
        }
        
        do {
            try await configManager.checkHoop()
            try await configManager.checkAuth()
            let connections = try await configManager.readConnectionsFile()
            
            let processes = try await ProcessManager.shared.connectToAll(connections: connections)

            if verbose { print("All connections established. Press Ctrl+D to exit.") }
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await ProcessManager.shared.waitForEOF()
                }
                
                for process in processes {
                    group.addTask {
                        try process.run()
                    }
                }
                
                try await group.waitForAll()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
