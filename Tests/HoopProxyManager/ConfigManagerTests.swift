import XCTest
@testable import HoopProxyManagerCore

final class ConfigManagerTests: XCTestCase {
    func testCheckHoop() async throws {
        let configManager = ConfigManager()
        // This test assumes 'hoop' is installed on the system
        do {
            try await configManager.checkHoop()
        } catch {
            XCTFail("checkHoop() threw an unexpected error: \(error)")
        }
    }
    
    func testCheckAuth() async throws {
        let configManager = ConfigManager()
        // This test might need to be adjusted based on your testing environment
        do {
            try await configManager.checkAuth()
        } catch {
            XCTFail("checkAuth() threw an unexpected error: \(error)")
        }
    }
    
    func testReadConnectionsFile() async throws {
        // Create a temporary connections.toml file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let connectionsPath = tempDir.appending(path: "connections.toml")
        let testContent = """
        connection1 = 8080
        connection2 = 8081
        """
        try testContent.write(to: connectionsPath, atomically: true, encoding: .utf8)
        
        // Set the hoopConfigDir to our temp directory for this test
        let configManager = ConfigManager(hoopConfigDir: tempDir)
        
        do {
            let connections = try await configManager.readConnectionsFile()
            XCTAssertEqual(connections.count, 2)
            XCTAssertEqual(connections["connection1"], 8080)
            XCTAssertEqual(connections["connection2"], 8081)
        } catch {
            XCTFail("readConnectionsFile() threw an unexpected error: \(error)")
        }
        
        // Clean up
        try FileManager.default.removeItem(at: connectionsPath)
    }
}
