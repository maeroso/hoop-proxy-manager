# Hoop Proxy Manager

Hoop Proxy Manager is a Swift CLI application that manages Hoop proxy connections using the Hoop CLI. It targets macOS 13+ and Linux, built with Swift Package Manager and Swift 6.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Essential Requirements
- Install Swift 6+ (Swift 6.1.2 recommended)
- Install Hoop CLI from https://hoop.dev/docs/getting-started/cli before running the application
- Ensure `hoop` binary is in PATH
- Application requires prior hoop authentication via `hoop login` 
- User must create `~/.hoop/connections.toml` file with connection mappings

### Building and Testing
- **NEVER CANCEL BUILDS**: Build commands take significant time, especially first builds
- Build debug version: `swift build` -- takes 90 seconds on first build (downloading dependencies). NEVER CANCEL. Set timeout to 180+ seconds.
- Build release version: `swift build -c release` -- takes 3 minutes. NEVER CANCEL. Set timeout to 300+ seconds.  
- **KNOWN ISSUE**: `swift test` fails due to Swift 6 strict concurrency issues in test code. Do NOT try to fix unrelated concurrency issues in tests unless specifically tasked.
- Application builds successfully and runs correctly despite test failures

### Running the Application
- **Recommended**: Use `swift run HoopProxyManager` to run debug version (handles paths automatically)
- Direct paths: `.build/x86_64-unknown-linux-gnu/debug/HoopProxyManager` (Linux) or `.build/arm64-apple-macosx/debug/HoopProxyManager` (macOS)
- Usage: `swift run HoopProxyManager connect [--verbose]` 
- Help: `swift run HoopProxyManager --help` or `swift run HoopProxyManager connect --help`
- Without proper hoop setup, application will fail gracefully with informative error messages

### Required Configuration Files
- `~/.hoop/config.toml` - Created by `hoop login`, contains authentication token
- `~/.hoop/connections.toml` - User-created file with format:
  ```toml
  # connection-name = port-number  
  my-database = 5432
  api-server = 8080
  ```

## Validation Scenarios

After making changes to the codebase:
1. **ALWAYS** run `swift build` to ensure the code compiles - NEVER CANCEL, wait full 3+ minutes for completion
2. **CRITICAL**: Test the CLI interface with `swift run HoopProxyManager --help` and `swift run HoopProxyManager connect --help` 
3. **FUNCTIONAL TEST**: Run `swift run HoopProxyManager connect --verbose` to verify the application detects missing hoop CLI or configuration issues gracefully
4. **INTEGRATION TEST**: If hoop CLI is available and configured, test with real connections to verify proxy startup
5. Do NOT run `swift test` unless specifically working on test fixes - tests currently fail due to Swift 6 concurrency issues

## Common Tasks

### Repository Structure
```
Sources/HoopProxyManager/
├── HoopProxyManager.swift      # Main entry point with ArgumentParser
├── ConnectCommand.swift        # Main connect command implementation  
├── ConfigManager.swift         # Config reading, auth verification, connections parsing
├── ProcessManager.swift        # Hoop process management and connection handling
└── RuntimeError.swift          # Custom error types

Tests/HoopProxyManager/
├── ConfigManagerTests.swift    # Config management tests (currently broken)
└── ProcessManagerTests.swift   # Process management tests (currently broken)

.github/workflows/
└── build-and-release.yml      # CI/CD pipeline for macOS + Linux builds
```

### Key Dependencies (Package.swift)
- **ArgumentParser** - CLI interface and command parsing
- **TOMLKit** - Reading .toml configuration files
- **JWTKit** - JWT token verification for hoop authentication
- **Platform**: macOS 13+ only (despite Linux CI, primary target is macOS)

### Understanding the Application Flow
1. **Configuration Check**: Verifies hoop CLI installation (`hoop version`)
2. **Authentication Check**: Reads `~/.hoop/config.toml`, verifies JWT token validity  
3. **Connection Loading**: Parses `~/.hoop/connections.toml` for connection->port mappings
4. **Process Management**: Spawns `hoop connect` processes for each configured connection
5. **Signal Handling**: Graceful shutdown on SIGINT/SIGTERM

### CI/CD Pipeline (.github/workflows/build-and-release.yml)
- Builds universal macOS binaries (arm64 + x86_64)  
- Builds Linux x86_64 binaries
- Creates GitHub releases on tag push
- Uses Swift package caching for faster builds
- **Build Times in CI**: macOS build ~5 minutes, Linux build ~3 minutes

## Critical Development Notes

### Swift 6 Concurrency Issues
- Tests fail due to strict concurrency checking in Swift 6
- Specifically: `ProcessManagerTests.swift` line 42 has Task closure sending parameter issue
- Main application code works correctly, only test code affected
- Do NOT attempt to fix test concurrency issues unless specifically assigned that task

### Hoop CLI Integration Points  
- Application shells out to `hoop` binary - no direct SDK integration
- Commands used: `hoop version`, `hoop login`, `hoop connect <name> -p <port>`
- Config file locations are hardcoded to `~/.hoop/` directory
- JWT token verification uses JWTKit but no signature verification (mock payload)

### Error Handling Strategy
- ConfigManager throws specific ConfigManagerError types
- RuntimeError used for general application errors  
- Process failures detected via exit status codes
- Graceful degradation with informative error messages

## Build Optimization Settings
Release builds use:
- `-cross-module-optimization` for better performance
- `-Osize` for smaller binary size  
- `SWIFT_DETERMINISTIC_HASHING=1` for reproducible builds

## Important: Never Cancel Long-Running Operations
- **NEVER CANCEL**: `swift build` commands can take 3+ minutes
- **NEVER CANCEL**: `swift build -c release` can take 5+ minutes  
- **NEVER CANCEL**: CI builds can take 10+ minutes
- Always set timeouts to 300+ seconds for build commands
- Wait for complete builds rather than cancelling and retrying