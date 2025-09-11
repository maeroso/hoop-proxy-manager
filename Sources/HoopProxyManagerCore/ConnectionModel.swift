import Foundation

public enum ConnectionStatus: Equatable {
    case disconnected
    case connecting  
    case connected
    case error(String)
}

public class ConnectionModel: Identifiable {
    public let id = UUID()
    public var name: String
    public var port: Int
    public var status: ConnectionStatus = .disconnected
    public var logs: [String] = []
    
    public init(name: String, port: Int) {
        self.name = name
        self.port = port
    }
}

public class ConnectionManager: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = ConnectionManager()
    
    public var connections: [ConnectionModel] = []
    public var configManager = ConfigManager()
    public var processManager = ProcessManager.shared
    
    private init() {}
    
    public func loadConnections() async throws {
        let connectionDict = try await configManager.readConnectionsFile()
        
        connections = connectionDict.map { (name, port) in
            let connection = ConnectionModel(name: name, port: port)
            connection.status = processManager.connectionStatus[name] ?? .disconnected
            connection.logs = processManager.connectionLogs[name] ?? []
            return connection
        }.sorted { $0.name < $1.name }
    }
    
    public func saveConnections() async throws {
        let connectionDict = Dictionary(uniqueKeysWithValues: connections.map { ($0.name, $0.port) })
        try await configManager.saveConnectionsFile(connectionDict)
    }
    
    public func addConnection(name: String, port: Int) throws {
        // Validate name is unique
        if connections.contains(where: { $0.name == name }) {
            throw RuntimeError("Connection with name '\(name)' already exists")
        }
        
        // Validate port is unique  
        if connections.contains(where: { $0.port == port }) {
            throw RuntimeError("Connection with port \(port) already exists")
        }
        
        let connection = ConnectionModel(name: name, port: port)
        connections.append(connection)
        connections.sort { $0.name < $1.name }
    }
    
    public func removeConnection(_ connection: ConnectionModel) {
        // Disconnect if connected
        if case .connected = connection.status {
            processManager.disconnect(connection: connection.name)
        }
        
        connections.removeAll { $0.id == connection.id }
    }
    
    public func connect(_ connection: ConnectionModel) async {
        do {
            _ = try await processManager.connect(connection: connection.name, port: connection.port)
            connection.status = .connected
        } catch {
            connection.status = .error(error.localizedDescription)
        }
        updateConnectionStatus(connection)
    }
    
    public func disconnect(_ connection: ConnectionModel) {
        processManager.disconnect(connection: connection.name)
        connection.status = .disconnected
        updateConnectionStatus(connection)
    }
    
    private func updateConnectionStatus(_ connection: ConnectionModel) {
        connection.status = processManager.connectionStatus[connection.name] ?? .disconnected
        connection.logs = processManager.connectionLogs[connection.name] ?? []
    }
    
    public func refreshStatus() {
        for connection in connections {
            updateConnectionStatus(connection)
        }
    }
}