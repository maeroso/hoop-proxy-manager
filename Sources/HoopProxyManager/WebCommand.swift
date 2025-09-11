import Foundation
import ArgumentParser
import HoopProxyManagerCore

struct WebCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "web",
        abstract: "Start the web interface for managing connections"
    )
    
    @Option(name: .shortAndLong, help: "Port for the web interface")
    var port: Int = 8080
    
    @Flag(name: .shortAndLong, help: "Run in verbose mode")
    var verbose = false
    
    func run() async throws {
        if verbose { print("Starting web interface on port \(port)...") }
        
        let configManager = ConfigManager()
        
        do {
            try await configManager.checkHoop()
            
            // Start the web server process
            let process = Process()
            process.executableURL = URL(filePath: "./.build/debug/HoopProxyManagerWeb")
            
            // Set environment variable for port
            var environment = ProcessInfo.processInfo.environment
            environment["PORT"] = String(port)
            process.environment = environment
            
            if verbose {
                print("Web interface will be available at: http://localhost:\(port)/ui")
                print("Press Ctrl+C to stop the web interface")
            }
            
            try process.run()
            process.waitUntilExit()
            
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}