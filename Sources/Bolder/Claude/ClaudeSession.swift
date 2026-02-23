import Foundation

/// Protocol for Claude session interaction, enabling test mocking.
protocol ClaudeSessionProviding: AnyObject {
    func start()
    func sendPrompt(_ text: String, images: [String]?)
    func terminate()
    var onEvent: (([String: Any]) -> Void)? { get set }
}

/// Manages a long-running `claude` process with bidirectional NDJSON streaming.
final class ClaudeSession: ClaudeSessionProviding {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var lineBuffer = Data()
    private let projectURL: URL
    private var sessionID: String?
    private var autoApprove: Bool
    private var model: String?
    private var allowedTools: [String] = ["Read", "Glob", "Grep", "WebSearch", "WebFetch"]

    // Block tracking for streaming content blocks
    private var blockToolIds: [Int: String] = [:]
    private var pendingToolInput: [Int: String] = [:]
    private var currentParentToolUseId: String?

    /// Called on main thread with each parsed JSON event from stdout.
    var onEvent: (([String: Any]) -> Void)?
    /// Called on main thread when session ID is received from the init event.
    var onSessionID: ((String) -> Void)?

    init(sessionID: String?, autoApprove: Bool, projectURL: URL) {
        self.sessionID = sessionID
        self.autoApprove = autoApprove
        self.projectURL = projectURL
    }

    deinit {
        terminate()
    }

    /// Start the claude process if not already running.
    func start() {
        guard process == nil else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = [
            "claude",
            "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages"
        ]

        if autoApprove {
            args.append("--dangerously-skip-permissions")
        } else if !allowedTools.isEmpty {
            args += ["--allowedTools", allowedTools.joined(separator: ",")]
        }

        if let m = model {
            args += ["--model", m]
        }

        if let sid = sessionID {
            args += ["--resume", sid]
        }

        proc.arguments = args
        proc.currentDirectoryURL = projectURL

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.processStdoutData(data)
        }

        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                print("[claude stderr] \(text)")
            }
        }

        proc.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.handleTermination(exitCode: proc.terminationStatus)
            }
        }

        do {
            try proc.run()
            self.process = proc
            print("[ClaudeSession] process started with pid \(proc.processIdentifier)")
        } catch {
            print("[ClaudeSession] Failed to start: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onEvent?(["type": "error", "message": "Failed to start claude: \(error.localizedDescription)"])
            }
        }
    }

    /// Send a user prompt to the claude process via stdin.
    func sendPrompt(_ text: String, images: [String]? = nil) {
        if process == nil {
            start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendPrompt(text, images: images)
            }
            return
        }

        guard let pipe = stdinPipe else { return }

        var content: [[String: Any]] = [["type": "text", "text": text]]

        if let images = images, !images.isEmpty {
            for base64 in images {
                let tempDir = FileManager.default.temporaryDirectory
                let imageFile = tempDir.appendingPathComponent(UUID().uuidString + ".png")
                if let data = Data(base64Encoded: base64) {
                    try? data.write(to: imageFile)
                    content.append([
                        "type": "image",
                        "source": ["type": "file", "path": imageFile.path]
                    ])
                }
            }
        }

        let message: [String: Any] = [
            "type": "user",
            "message": ["role": "user", "content": content]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              var line = String(data: jsonData, encoding: .utf8) else { return }
        line += "\n"
        print("[ClaudeSession] sending: \(line.prefix(200))")

        if let data = line.data(using: .utf8) {
            pipe.fileHandleForWriting.write(data)
        }
    }

    func cancel() {
        process?.interrupt()
    }

    func terminate() {
        intentionalRestart = false
        tearDownProcess()
    }

    func setAutoApprove(_ enabled: Bool) {
        guard autoApprove != enabled else { return }
        autoApprove = enabled
        intentionalRestart = true
        tearDownProcess()
        start()
    }

    func setModel(_ name: String) {
        model = name
        intentionalRestart = true
        tearDownProcess()
        start()
    }

    func addAllowedTool(_ name: String) {
        guard !autoApprove, !allowedTools.contains(name) else { return }
        allowedTools.append(name)
        intentionalRestart = true
        tearDownProcess()
        start()
    }

    // MARK: - Private

    private var intentionalRestart = false

    private func tearDownProcess() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        lineBuffer = Data()
    }

    /// Extract text from polymorphic content (string | [{text: string}]).
    private func extractText(from value: Any?) -> String {
        if let str = value as? String { return str }
        if let arr = value as? [[String: Any]] {
            return arr.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        return ""
    }

    private func processStdoutData(_ data: Data) {
        lineBuffer.append(data)

        let newline = UInt8(0x0A)
        while let range = lineBuffer.range(of: Data([newline])) {
            let lineData = lineBuffer.subdata(in: lineBuffer.startIndex..<range.lowerBound)
            lineBuffer.removeSubrange(lineBuffer.startIndex...range.lowerBound)

            guard !lineData.isEmpty,
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            DispatchQueue.main.async { [weak self] in
                self?.handleRawEvent(json)
            }
        }
    }

    private func handleRawEvent(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }

        switch type {
        case "system":
            handleSystem(json)

        case "stream_event":
            guard let event = json["event"] as? [String: Any],
                  let eventType = event["type"] as? String else { return }
            currentParentToolUseId = json["parent_tool_use_id"] as? String
            handleStreamEvent(eventType, event: event)

        case "user":
            handleUserMessage(json)

        case "result":
            handleResult(json)

        case "assistant":
            // Content already processed incrementally via stream_event.
            break

        default:
            break
        }
    }

    private func handleSystem(_ json: [String: Any]) {
        guard let subtype = json["subtype"] as? String else { return }

        switch subtype {
        case "init":
            if let sid = json["session_id"] as? String {
                sessionID = sid
                onSessionID?(sid)
            }
            var initEvent: [String: Any] = [
                "type": "init",
                "sessionId": sessionID ?? "",
                "autoApprove": autoApprove,
                "model": json["model"] as? String ?? "unknown"
            ]
            if let tools = json["tools"] as? [String] { initEvent["tools"] = tools }
            if let mcp = json["mcp_servers"] as? [String] { initEvent["mcpServers"] = mcp }
            if let perm = json["permissionMode"] as? String { initEvent["permissionMode"] = perm }
            if let cwd = json["cwd"] as? String { initEvent["cwd"] = cwd }
            onEvent?(initEvent)

        case "compact_boundary":
            onEvent?(["type": "system_message", "text": "Context compacted"])

        default:
            break
        }
    }

    private func handleStreamEvent(_ eventType: String, event: [String: Any]) {
        switch eventType {
        case "message_start":
            blockToolIds.removeAll()
            pendingToolInput.removeAll()

        case "content_block_start":
            guard let block = event["content_block"] as? [String: Any],
                  let blockType = block["type"] as? String else { return }
            let index = event["index"] as? Int ?? 0

            switch blockType {
            case "text":
                var ev: [String: Any] = ["type": "stream_start"]
                if let pid = currentParentToolUseId { ev["parentToolUseId"] = pid }
                onEvent?(ev)

            case "thinking":
                var ev: [String: Any] = ["type": "thinking_start"]
                if let pid = currentParentToolUseId { ev["parentToolUseId"] = pid }
                onEvent?(ev)

            case "tool_use", "server_tool_use":
                let toolId = block["id"] as? String ?? ""
                let toolName = block["name"] as? String ?? ""
                blockToolIds[index] = toolId
                pendingToolInput[index] = ""
                onEvent?([
                    "type": "tool_use",
                    "id": toolId,
                    "name": toolName,
                    "input": block["input"] ?? [:]
                ])

            case "web_search_tool_result":
                onEvent?([
                    "type": "tool_result",
                    "toolUseId": block["tool_use_id"] as? String ?? "",
                    "content": extractText(from: block["content"]),
                    "isError": false
                ])

            default:
                break
            }

        case "content_block_delta":
            guard let delta = event["delta"] as? [String: Any],
                  let deltaType = delta["type"] as? String else { return }

            switch deltaType {
            case "text_delta":
                if let text = delta["text"] as? String {
                    onEvent?(["type": "text_delta", "text": text])
                }

            case "thinking_delta":
                if let text = delta["text"] as? String {
                    onEvent?(["type": "thinking_delta", "text": text])
                }

            case "input_json_delta":
                let index = event["index"] as? Int ?? 0
                if let partial = delta["partial_json"] as? String {
                    pendingToolInput[index, default: ""] += partial
                }

            case "signature_delta":
                break

            default:
                break
            }

        case "content_block_stop":
            let index = event["index"] as? Int ?? 0
            if let toolId = blockToolIds.removeValue(forKey: index),
               let raw = pendingToolInput.removeValue(forKey: index), !raw.isEmpty,
               let data = raw.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                onEvent?(["type": "tool_input", "id": toolId, "input": parsed])
            }

        case "message_delta", "message_stop", "ping":
            break

        case "error":
            let msg = event["message"] as? String
                ?? (event["error"] as? [String: Any])?["message"] as? String
                ?? "Unknown stream error"
            onEvent?(["type": "error", "message": msg])

        default:
            break
        }
    }

    private func handleUserMessage(_ json: [String: Any]) {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return }

        for block in content where block["type"] as? String == "tool_result" {
            let isError = block["is_error"] as? Bool ?? false
            onEvent?([
                "type": "tool_result",
                "toolUseId": block["tool_use_id"] as? String ?? "",
                "content": extractText(from: block["content"]),
                "isError": isError
            ])
        }
    }

    private func handleResult(_ json: [String: Any]) {
        var turnEvent: [String: Any] = ["type": "turn_complete"]
        if let usage = json["usage"] as? [String: Any] { turnEvent["usage"] = usage }
        if let cost = json["total_cost_usd"] as? Double { turnEvent["cost"] = cost }

        if let subtype = json["subtype"] as? String {
            let errorMessages: [String: String] = [
                "error_max_turns": "Reached maximum turn limit",
                "error_max_budget_usd": "Reached budget limit",
                "error_during_execution": "Error during execution",
            ]
            if let msg = errorMessages[subtype] { turnEvent["errorMessage"] = msg }
        }

        onEvent?(turnEvent)

        if let denials = json["permission_denials"] as? [[String: Any]], !denials.isEmpty {
            let tools = denials.map { denial -> [String: Any] in
                [
                    "name": denial["tool_name"] as? String ?? denial["name"] as? String ?? "",
                    "input": denial["input"] ?? [:]
                ]
            }
            onEvent?(["type": "denied_tools", "tools": tools])
        }
    }

    private func handleTermination(exitCode: Int32) {
        guard !intentionalRestart else {
            intentionalRestart = false
            return
        }
        print("[ClaudeSession] process terminated with code \(exitCode)")
        if exitCode != 0 {
            onEvent?(["type": "error", "message": "Claude process exited with code \(exitCode)"])
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
}
