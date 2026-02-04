import AppKit

final class SettingsWindow: NSWindow {
    private let settingsView: SettingsContentView

    init(projectURL: URL) {
        self.settingsView = SettingsContentView(projectURL: projectURL)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "Settings"
        contentView = settingsView
        isReleasedWhenClosed = false
        center()
        minSize = NSSize(width: 400, height: 300)
    }
}

// MARK: - Content view

private final class SettingsContentView: NSView {
    private let projectURL: URL
    private let scopeControl = NSSegmentedControl()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var recorderButtons: [ShortcutAction: ShortcutRecorderButton] = [:]

    init(projectURL: URL) {
        self.projectURL = projectURL
        super.init(frame: .zero)
        setupUI()
        reloadShortcuts()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupUI() {
        // Scope selector
        scopeControl.segmentCount = 2
        scopeControl.setLabel("Global", forSegment: 0)
        scopeControl.setLabel("Project", forSegment: 1)
        scopeControl.selectedSegment = SettingsManager.shared.activeScope.rawValue
        scopeControl.target = self
        scopeControl.action = #selector(scopeChanged)
        scopeControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scopeControl)

        // Scroll view with stack of shortcut rows
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        addSubview(scrollView)

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        let clipView = NSClipView()
        clipView.documentView = stackView
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        // Reset button
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(resetButton)

        NSLayoutConstraint.activate([
            scopeControl.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            scopeControl.centerXAnchor.constraint(equalTo: centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: scopeControl.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -12),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),

            resetButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            resetButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])

        buildRows()
    }

    private func buildRows() {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        recorderButtons.removeAll()

        for action in ShortcutAction.allCases {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 12
            row.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: action.displayName)
            label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

            let binding = SettingsManager.shared.shortcuts[action] ?? ShortcutAction.defaults[action]!
            let recorder = ShortcutRecorderButton(binding: binding) { [weak self] newBinding in
                self?.shortcutChanged(action: action, binding: newBinding)
            }
            recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
            recorderButtons[action] = recorder

            row.addArrangedSubview(label)
            row.addArrangedSubview(recorder)
            stackView.addArrangedSubview(row)
        }
    }

    private func reloadShortcuts() {
        for action in ShortcutAction.allCases {
            if let binding = SettingsManager.shared.shortcuts[action],
               let recorder = recorderButtons[action] {
                recorder.update(binding: binding)
            }
        }
        scopeControl.selectedSegment = SettingsManager.shared.activeScope.rawValue
    }

    private func shortcutChanged(action: ShortcutAction, binding: KeyBinding) {
        var current = SettingsManager.shared.shortcuts
        current[action] = binding
        let scope = SettingsManager.Scope(rawValue: scopeControl.selectedSegment) ?? .global
        SettingsManager.shared.save(current, scope: scope, projectURL: projectURL)
    }

    @objc private func scopeChanged() {
        // Reload from the selected scope — switching scope re-loads settings
        SettingsManager.shared.load(projectURL: projectURL)
        reloadShortcuts()
    }

    @objc private func resetDefaults() {
        let scope = SettingsManager.Scope(rawValue: scopeControl.selectedSegment) ?? .global
        SettingsManager.shared.resetToDefaults(scope: scope, projectURL: projectURL)
        reloadShortcuts()
    }
}

// MARK: - Shortcut recorder button

private final class ShortcutRecorderButton: NSButton {
    private var binding: KeyBinding
    private var isRecording = false
    private let onChange: (KeyBinding) -> Void

    init(binding: KeyBinding, onChange: @escaping (KeyBinding) -> Void) {
        self.binding = binding
        self.onChange = onChange
        super.init(frame: .zero)
        title = binding.displayString
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func update(binding: KeyBinding) {
        self.binding = binding
        title = binding.displayString
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func startRecording() {
        isRecording = true
        title = "Press shortcut\u{2026}"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Escape cancels
        if event.keyCode == 53 {
            cancelRecording()
            return
        }

        // Ignore bare modifier key presses
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            return
        }

        let newBinding = KeyBinding.from(event)
        binding = newBinding
        title = newBinding.displayString
        isRecording = false
        onChange(newBinding)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            cancelRecording()
        }
        return super.resignFirstResponder()
    }

    private func cancelRecording() {
        isRecording = false
        title = binding.displayString
    }
}
