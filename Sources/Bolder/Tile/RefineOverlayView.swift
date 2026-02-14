import AppKit

/// Semi-transparent dark overlay on a notes tile for the refine Q&A flow.
/// Three states: asking questions, refining (streaming), complete (accept/reject).
final class RefineOverlayView: NSView {
    enum Phase {
        case questions(String)
        case refining(String)
        case complete(String)
    }

    var onSubmitAnswers: ((String) -> Void)?
    var onAccept: ((String) -> Void)?
    var onReject: (() -> Void)?
    var onCancel: (() -> Void)?

    private let backgroundLayer = CALayer()
    private let containerView = NSView()

    // Questions phase
    private let questionsLabel = NSTextField(wrappingLabelWithString: "")
    private let answerScrollView = NSScrollView()
    private let answerTextView = NSTextView()
    private let submitButton = NSButton(title: "Submit", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    // Refining phase
    private let progressLabel = NSTextField(labelWithString: "Refining...")
    private let previewScrollView = NSScrollView()
    private let previewTextView = NSTextView()

    // Complete phase
    private let acceptButton = NSButton(title: "Accept", target: nil, action: nil)
    private let rejectButton = NSButton(title: "Reject", target: nil, action: nil)

    private var currentPhase: Phase?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupViews() {
        // Semi-transparent background
        backgroundLayer.backgroundColor = NSColor(white: 0.05, alpha: 0.92).cgColor
        layer?.addSublayer(backgroundLayer)

        containerView.wantsLayer = true
        addSubview(containerView)

        // Questions label
        questionsLabel.font = FontLoader.jetBrainsMono(size: 14)
        questionsLabel.textColor = NSColor(white: 0.8, alpha: 1.0)
        questionsLabel.maximumNumberOfLines = 0
        questionsLabel.isHidden = true
        containerView.addSubview(questionsLabel)

        // Answer text view
        answerScrollView.hasVerticalScroller = true
        answerScrollView.hasHorizontalScroller = false
        answerScrollView.drawsBackground = true
        answerScrollView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        answerScrollView.borderType = .noBorder
        answerScrollView.isHidden = true

        answerTextView.isEditable = true
        answerTextView.isSelectable = true
        answerTextView.isRichText = false
        answerTextView.font = FontLoader.jetBrainsMono(size: 14)
        answerTextView.textColor = NSColor(white: 0.85, alpha: 1.0)
        answerTextView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        answerTextView.insertionPointColor = NSColor(white: 0.8, alpha: 1.0)
        answerTextView.textContainerInset = NSSize(width: 8, height: 8)
        answerTextView.isVerticallyResizable = true
        answerTextView.isHorizontallyResizable = false
        answerTextView.autoresizingMask = [.width]
        answerTextView.textContainer?.widthTracksTextView = true
        answerScrollView.documentView = answerTextView
        containerView.addSubview(answerScrollView)

        // Buttons
        configureButton(submitButton, action: #selector(submitTapped))
        configureButton(cancelButton, action: #selector(cancelTapped))
        configureButton(acceptButton, action: #selector(acceptTapped))
        configureButton(rejectButton, action: #selector(rejectTapped))

        submitButton.isHidden = true
        cancelButton.isHidden = true
        acceptButton.isHidden = true
        rejectButton.isHidden = true

        containerView.addSubview(submitButton)
        containerView.addSubview(cancelButton)
        containerView.addSubview(acceptButton)
        containerView.addSubview(rejectButton)

        // Progress label
        progressLabel.font = FontLoader.jetBrainsMono(size: 14, weight: .medium)
        progressLabel.textColor = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        progressLabel.isHidden = true
        containerView.addSubview(progressLabel)

        // Preview text view
        previewScrollView.hasVerticalScroller = true
        previewScrollView.hasHorizontalScroller = false
        previewScrollView.drawsBackground = true
        previewScrollView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        previewScrollView.borderType = .noBorder
        previewScrollView.isHidden = true

        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.isRichText = false
        previewTextView.font = FontLoader.jetBrainsMono(size: 14)
        previewTextView.textColor = NSColor(white: 0.8, alpha: 1.0)
        previewTextView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        previewTextView.textContainerInset = NSSize(width: 8, height: 8)
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.autoresizingMask = [.width]
        previewTextView.textContainer?.widthTracksTextView = true
        previewScrollView.documentView = previewTextView
        containerView.addSubview(previewScrollView)
    }

    private func configureButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.font = FontLoader.jetBrainsMono(size: 13)
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        backgroundLayer.frame = bounds

        // Container covers bottom ~60% of the view
        let containerHeight = bounds.height * 0.6
        containerView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: containerHeight
        )

        layoutCurrentPhase()
    }

    private func layoutCurrentPhase() {
        let pad: CGFloat = 20
        let containerBounds = containerView.bounds
        let contentWidth = containerBounds.width - pad * 2
        let buttonHeight: CGFloat = 28
        let buttonWidth: CGFloat = 80

        switch currentPhase {
        case .questions:
            // Questions at top, answer area in middle, buttons at bottom
            let buttonsY: CGFloat = pad
            cancelButton.frame = NSRect(x: pad, y: buttonsY, width: buttonWidth, height: buttonHeight)
            submitButton.frame = NSRect(x: pad + buttonWidth + 8, y: buttonsY, width: buttonWidth, height: buttonHeight)

            let answerTop = buttonsY + buttonHeight + 12
            let questionsHeight = min(containerBounds.height * 0.4, 200.0)
            let answerHeight = containerBounds.height - answerTop - questionsHeight - pad - 12

            answerScrollView.frame = NSRect(x: pad, y: answerTop, width: contentWidth, height: max(answerHeight, 60))

            let questionsY = answerTop + max(answerHeight, 60) + 12
            questionsLabel.frame = NSRect(x: pad, y: questionsY, width: contentWidth, height: questionsHeight)

        case .refining:
            progressLabel.sizeToFit()
            let progressY = containerBounds.height - pad - progressLabel.frame.height
            progressLabel.frame.origin = NSPoint(x: pad, y: progressY)

            let buttonsY: CGFloat = pad
            cancelButton.frame = NSRect(x: pad, y: buttonsY, width: buttonWidth, height: buttonHeight)

            let previewTop = buttonsY + buttonHeight + 12
            let previewHeight = progressY - previewTop - 12
            previewScrollView.frame = NSRect(x: pad, y: previewTop, width: contentWidth, height: max(previewHeight, 60))

        case .complete:
            let buttonsY: CGFloat = pad
            rejectButton.frame = NSRect(x: pad, y: buttonsY, width: buttonWidth, height: buttonHeight)
            acceptButton.frame = NSRect(x: pad + buttonWidth + 8, y: buttonsY, width: buttonWidth, height: buttonHeight)

            let previewTop = buttonsY + buttonHeight + 12
            let previewHeight = containerBounds.height - previewTop - pad
            previewScrollView.frame = NSRect(x: pad, y: previewTop, width: contentWidth, height: max(previewHeight, 60))

        case .none:
            break
        }
    }

    // MARK: - Phase transitions

    func showQuestions(_ questions: String) {
        currentPhase = .questions(questions)
        hideAll()

        questionsLabel.stringValue = questions
        questionsLabel.isHidden = false
        answerScrollView.isHidden = false
        answerTextView.string = ""
        submitButton.isHidden = false
        cancelButton.isHidden = false

        layoutCurrentPhase()

        // Focus the answer field
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self.answerTextView)
        }
    }

    func showRefining(streamingText: String) {
        if case .refining = currentPhase {
            // Just update preview text
            previewTextView.string = streamingText
            return
        }

        currentPhase = .refining(streamingText)
        hideAll()

        progressLabel.isHidden = false
        previewScrollView.isHidden = false
        previewTextView.string = streamingText
        cancelButton.isHidden = false

        layoutCurrentPhase()
    }

    func showComplete(refinedText: String) {
        currentPhase = .complete(refinedText)
        hideAll()

        previewScrollView.isHidden = false
        previewTextView.string = refinedText
        acceptButton.isHidden = false
        rejectButton.isHidden = false

        layoutCurrentPhase()
    }

    private func hideAll() {
        questionsLabel.isHidden = true
        answerScrollView.isHidden = true
        submitButton.isHidden = true
        cancelButton.isHidden = true
        progressLabel.isHidden = true
        previewScrollView.isHidden = true
        acceptButton.isHidden = true
        rejectButton.isHidden = true
    }

    // MARK: - Actions

    @objc private func submitTapped() {
        let answers = answerTextView.string
        guard !answers.isEmpty else { return }
        onSubmitAnswers?(answers)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func acceptTapped() {
        if case .complete(let text) = currentPhase {
            onAccept?(text)
        }
    }

    @objc private func rejectTapped() {
        onReject?()
    }

    // MARK: - First responder routing

    /// The answer text view, for first-responder routing during Q&A phase.
    var answerField: NSTextView { answerTextView }

    /// Whether the overlay is in the questions phase (needs focus for answer field).
    var isWaitingForInput: Bool {
        if case .questions = currentPhase { return true }
        return false
    }
}
