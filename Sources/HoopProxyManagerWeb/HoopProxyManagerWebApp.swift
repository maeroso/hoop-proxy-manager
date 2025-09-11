import Vapor
import HoopProxyManagerCore

@main
struct HoopProxyManagerWebApp {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
            
            // Set port from environment variable or default to 8080
            let port = Environment.get("PORT").flatMap(Int.init) ?? 8080
            app.http.server.configuration.port = port
            
            print("🌐 Web interface starting on http://localhost:\(port)/ui")
            try await app.execute()
        } catch {
            try await app.asyncShutdown()
            throw error
        }
    }
}

func configure(_ app: Application) async throws {
    let connectionManager = ConnectionManager.shared
    
    // Enable CORS for web interface
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration), at: .beginning)
    
    // API Routes
    app.get { req async -> Response in
        return req.redirect(to: "/ui")
    }
    
    app.get("api", "connections") { req async throws -> ConnectionsResponse in
        try await connectionManager.loadConnections()
        
        let connections = connectionManager.connections.map { connection in
            APIConnection(
                id: connection.id.uuidString,
                name: connection.name,
                port: connection.port,
                status: connection.status.statusString,
                logs: connection.logs
            )
        }
        
        return ConnectionsResponse(connections: connections)
    }
    
    app.post("api", "connections") { req async throws -> HTTPStatus in
        let newConnection = try req.content.decode(NewConnection.self)
        
        try connectionManager.addConnection(name: newConnection.name, port: newConnection.port)
        try await connectionManager.saveConnections()
        
        return .created
    }
    
    app.delete("api", "connections", ":id") { req async throws -> HTTPStatus in
        guard let connectionId = req.parameters.get("id"),
              let uuid = UUID(uuidString: connectionId) else {
            throw Abort(.badRequest)
        }
        
        if let connection = connectionManager.connections.first(where: { $0.id == uuid }) {
            connectionManager.removeConnection(connection)
            try await connectionManager.saveConnections()
        }
        
        return .ok
    }
    
    app.post("api", "connections", ":id", "connect") { req async throws -> HTTPStatus in
        guard let connectionId = req.parameters.get("id"),
              let uuid = UUID(uuidString: connectionId) else {
            throw Abort(.badRequest)
        }
        
        if let connection = connectionManager.connections.first(where: { $0.id == uuid }) {
            await connectionManager.connect(connection)
        }
        
        return .ok
    }
    
    app.post("api", "connections", ":id", "disconnect") { req async throws -> HTTPStatus in
        guard let connectionId = req.parameters.get("id"),
              let uuid = UUID(uuidString: connectionId) else {
            throw Abort(.badRequest)
        }
        
        if let connection = connectionManager.connections.first(where: { $0.id == uuid }) {
            connectionManager.disconnect(connection)
        }
        
        return .ok
    }
    
    app.get("api", "status") { req async throws -> StatusResponse in
        try await connectionManager.configManager.checkAuth()
        
        return StatusResponse(
            authenticated: connectionManager.configManager.isAuthenticated,
            authStatus: connectionManager.configManager.authStatus
        )
    }
    
    // Static file serving for UI
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // UI Route (serves HTML)
    app.get("ui") { req -> Response in
        let html = generateWebUI()
        return Response(
            status: .ok,
            headers: HTTPHeaders([("content-type", "text/html")]),
            body: .init(string: html)
        )
    }
}

// Data structures
struct ConnectionsResponse: Content {
    let connections: [APIConnection]
}

struct APIConnection: Content {
    let id: String
    let name: String
    let port: Int
    let status: String
    let logs: [String]
}

struct NewConnection: Content {
    let name: String
    let port: Int
}

struct StatusResponse: Content {
    let authenticated: Bool
    let authStatus: String
}

extension ConnectionStatus {
    var statusString: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .error(let message): return "error: \(message)"
        }
    }
}

func generateWebUI() -> String {
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hoop Proxy Manager</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background-color: #f5f5f5;
                color: #333;
            }
            
            .container {
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
            }
            
            header {
                background: white;
                padding: 20px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                margin-bottom: 20px;
            }
            
            h1 {
                color: #2c3e50;
                margin-bottom: 10px;
            }
            
            .status {
                display: inline-block;
                padding: 5px 15px;
                border-radius: 20px;
                font-size: 14px;
                font-weight: bold;
            }
            
            .status.authenticated {
                background-color: #d4edda;
                color: #155724;
            }
            
            .status.not-authenticated {
                background-color: #f8d7da;
                color: #721c24;
            }
            
            .actions {
                margin: 20px 0;
            }
            
            .btn {
                background-color: #007bff;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 5px;
                cursor: pointer;
                font-size: 14px;
                margin-right: 10px;
                transition: background-color 0.2s;
            }
            
            .btn:hover {
                background-color: #0056b3;
            }
            
            .btn.success {
                background-color: #28a745;
            }
            
            .btn.success:hover {
                background-color: #1e7e34;
            }
            
            .btn.danger {
                background-color: #dc3545;
            }
            
            .btn.danger:hover {
                background-color: #c82333;
            }
            
            .connections-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
                gap: 20px;
            }
            
            .connection-card {
                background: white;
                border-radius: 10px;
                padding: 20px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            
            .connection-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            
            .connection-name {
                font-size: 18px;
                font-weight: bold;
                color: #2c3e50;
            }
            
            .connection-port {
                color: #6c757d;
                font-size: 14px;
            }
            
            .connection-status {
                padding: 4px 12px;
                border-radius: 15px;
                font-size: 12px;
                font-weight: bold;
                text-transform: uppercase;
            }
            
            .connection-status.connected {
                background-color: #d4edda;
                color: #155724;
            }
            
            .connection-status.connecting {
                background-color: #fff3cd;
                color: #856404;
            }
            
            .connection-status.disconnected {
                background-color: #e2e3e5;
                color: #383d41;
            }
            
            .connection-status.error {
                background-color: #f8d7da;
                color: #721c24;
            }
            
            .connection-actions {
                margin-top: 15px;
            }
            
            .modal {
                display: none;
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background-color: rgba(0,0,0,0.5);
                z-index: 1000;
            }
            
            .modal-content {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: white;
                padding: 30px;
                border-radius: 10px;
                width: 90%;
                max-width: 400px;
            }
            
            .form-group {
                margin-bottom: 20px;
            }
            
            label {
                display: block;
                margin-bottom: 5px;
                font-weight: bold;
                color: #2c3e50;
            }
            
            input[type="text"], input[type="number"] {
                width: 100%;
                padding: 10px;
                border: 2px solid #e9ecef;
                border-radius: 5px;
                font-size: 14px;
                transition: border-color 0.2s;
            }
            
            input[type="text"]:focus, input[type="number"]:focus {
                outline: none;
                border-color: #007bff;
            }
            
            .form-actions {
                display: flex;
                justify-content: flex-end;
                gap: 10px;
            }
            
            .loading {
                display: none;
                text-align: center;
                padding: 20px;
                color: #6c757d;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <header>
                <h1>🔗 Hoop Proxy Manager</h1>
                <p>Manage your Hoop proxy connections with a simple web interface</p>
                <div id="authStatus" class="status">Loading...</div>
            </header>
            
            <div class="actions">
                <button class="btn" onclick="showAddConnectionModal()">Add Connection</button>
                <button class="btn" onclick="refreshConnections()">Refresh</button>
                <button class="btn danger" onclick="disconnectAll()">Disconnect All</button>
            </div>
            
            <div class="loading" id="loading">Loading connections...</div>
            <div class="connections-grid" id="connectionsGrid"></div>
        </div>
        
        <!-- Add Connection Modal -->
        <div id="addConnectionModal" class="modal">
            <div class="modal-content">
                <h3>Add New Connection</h3>
                <form id="addConnectionForm">
                    <div class="form-group">
                        <label for="connectionName">Connection Name:</label>
                        <input type="text" id="connectionName" required>
                    </div>
                    <div class="form-group">
                        <label for="connectionPort">Port:</label>
                        <input type="number" id="connectionPort" min="1" max="65535" required>
                    </div>
                    <div class="form-actions">
                        <button type="button" class="btn" onclick="hideAddConnectionModal()">Cancel</button>
                        <button type="submit" class="btn success">Add Connection</button>
                    </div>
                </form>
            </div>
        </div>
        
        <script>
            let connections = [];
            
            async function loadStatus() {
                try {
                    const response = await fetch('/api/status');
                    const status = await response.json();
                    const authStatusEl = document.getElementById('authStatus');
                    
                    if (status.authenticated) {
                        authStatusEl.textContent = `✅ ${status.authStatus}`;
                        authStatusEl.className = 'status authenticated';
                    } else {
                        authStatusEl.textContent = `❌ ${status.authStatus}`;
                        authStatusEl.className = 'status not-authenticated';
                    }
                } catch (error) {
                    console.error('Failed to load status:', error);
                    const authStatusEl = document.getElementById('authStatus');
                    authStatusEl.textContent = '❌ Connection Error';
                    authStatusEl.className = 'status not-authenticated';
                }
            }
            
            async function loadConnections() {
                const loading = document.getElementById('loading');
                const grid = document.getElementById('connectionsGrid');
                
                loading.style.display = 'block';
                grid.innerHTML = '';
                
                try {
                    const response = await fetch('/api/connections');
                    const data = await response.json();
                    connections = data.connections;
                    
                    renderConnections();
                } catch (error) {
                    console.error('Failed to load connections:', error);
                    grid.innerHTML = '<p style="text-align: center; color: #dc3545;">Failed to load connections</p>';
                } finally {
                    loading.style.display = 'none';
                }
            }
            
            function renderConnections() {
                const grid = document.getElementById('connectionsGrid');
                
                if (connections.length === 0) {
                    grid.innerHTML = '<p style="text-align: center; color: #6c757d; grid-column: 1 / -1;">No connections configured. Add your first connection!</p>';
                    return;
                }
                
                grid.innerHTML = connections.map(conn => `
                    <div class="connection-card">
                        <div class="connection-header">
                            <div>
                                <div class="connection-name">${conn.name}</div>
                                <div class="connection-port">localhost:${conn.port}</div>
                            </div>
                            <div class="connection-status ${conn.status.split(':')[0]}">${conn.status}</div>
                        </div>
                        <div class="connection-actions">
                            ${conn.status === 'connected' 
                                ? `<button class="btn danger" onclick="disconnect('${conn.id}')">Disconnect</button>` 
                                : `<button class="btn success" onclick="connect('${conn.id}')">Connect</button>`
                            }
                            <button class="btn" onclick="viewLogs('${conn.id}')">Logs</button>
                            <button class="btn danger" onclick="deleteConnection('${conn.id}')">Delete</button>
                        </div>
                    </div>
                `).join('');
            }
            
            async function connect(connectionId) {
                try {
                    await fetch(`/api/connections/${connectionId}/connect`, { method: 'POST' });
                    setTimeout(loadConnections, 1000); // Refresh after 1 second
                } catch (error) {
                    console.error('Failed to connect:', error);
                    alert('Failed to connect');
                }
            }
            
            async function disconnect(connectionId) {
                try {
                    await fetch(`/api/connections/${connectionId}/disconnect`, { method: 'POST' });
                    setTimeout(loadConnections, 500); // Refresh after 0.5 seconds
                } catch (error) {
                    console.error('Failed to disconnect:', error);
                    alert('Failed to disconnect');
                }
            }
            
            async function deleteConnection(connectionId) {
                if (!confirm('Are you sure you want to delete this connection?')) return;
                
                try {
                    await fetch(`/api/connections/${connectionId}`, { method: 'DELETE' });
                    loadConnections();
                } catch (error) {
                    console.error('Failed to delete connection:', error);
                    alert('Failed to delete connection');
                }
            }
            
            function viewLogs(connectionId) {
                const connection = connections.find(c => c.id === connectionId);
                if (connection && connection.logs.length > 0) {
                    alert('Logs for ' + connection.name + ':\\n\\n' + connection.logs.join('\\n'));
                } else {
                    alert('No logs available for ' + connection.name);
                }
            }
            
            function showAddConnectionModal() {
                document.getElementById('addConnectionModal').style.display = 'block';
            }
            
            function hideAddConnectionModal() {
                document.getElementById('addConnectionModal').style.display = 'none';
                document.getElementById('addConnectionForm').reset();
            }
            
            async function disconnectAll() {
                if (!confirm('Are you sure you want to disconnect all connections?')) return;
                
                const connectedConnections = connections.filter(c => c.status === 'connected');
                for (const conn of connectedConnections) {
                    await disconnect(conn.id);
                }
            }
            
            function refreshConnections() {
                loadStatus();
                loadConnections();
            }
            
            document.getElementById('addConnectionForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                
                const name = document.getElementById('connectionName').value;
                const port = parseInt(document.getElementById('connectionPort').value);
                
                try {
                    const response = await fetch('/api/connections', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ name, port })
                    });
                    
                    if (response.ok) {
                        hideAddConnectionModal();
                        loadConnections();
                    } else {
                        const errorText = await response.text();
                        alert('Failed to add connection: ' + errorText);
                    }
                } catch (error) {
                    console.error('Failed to add connection:', error);
                    alert('Failed to add connection');
                }
            });
            
            // Close modal when clicking outside
            window.addEventListener('click', (e) => {
                if (e.target.classList.contains('modal')) {
                    e.target.style.display = 'none';
                }
            });
            
            // Load initial data
            loadStatus();
            loadConnections();
            
            // Auto-refresh every 5 seconds
            setInterval(() => {
                loadStatus();
                loadConnections();
            }, 5000);
        </script>
    </body>
    </html>
    """
}