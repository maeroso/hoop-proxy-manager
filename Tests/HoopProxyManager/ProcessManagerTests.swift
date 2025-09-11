import XCTest
@testable import HoopProxyManagerCore

final class ProcessManagerTests: XCTestCase {
    var processManager: ProcessManager!
    
    override func setUp() async throws {
        processManager = ProcessManager()
    }
    
    func testConnectToAll() async throws {
        let testConnections = ["test1": 8080, "test2": 8081]
        
        do {
            let processes = try await processManager.connectToAll(connections: testConnections)
            XCTAssertEqual(processes.count, 2)
            
            for process in processes {
                XCTAssertEqual(process.executableURL, URL(filePath: "/usr/bin/env"))
                XCTAssertTrue(process.arguments?.contains("hoop") ?? false)
                XCTAssertTrue(process.arguments?.contains("connect") ?? false)
            }
        } catch {
            XCTFail("connectToAll() threw an unexpected error: \(error)")
        }
    }
    
    func testWaitForEOF() async throws {
        // This test simulates user input and checks if waitForEOF completes
        let testInput = "Test input\n"
        let pipe = Pipe()
        
        let expectation = XCTestExpectation(description: "Wait for EOF")
        
        Task {
            do {
                try await processManager.waitForEOF(input: pipe.fileHandleForReading)
                expectation.fulfill()
            } catch {
                XCTFail("waitForEOF() threw an unexpected error: \(error)")
            }
        }
        
        pipe.fileHandleForWriting.write(testInput.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
