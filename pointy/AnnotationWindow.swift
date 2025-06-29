import SwiftUI
import Combine

class AnnotationWindow: NSWindow {
    var currentScreen: NSScreen
    let screenshot: NSImage
    private var actionPublisher = PassthroughSubject<DrawingAction, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(contentRect: NSRect, screen: NSScreen, screenshot: NSImage) {
        self.currentScreen = screen
        self.screenshot = screenshot
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        
        self.level = .screenSaver
        self.collectionBehavior = .canJoinAllSpaces
        self.isMovableByWindowBackground = false
        self.isOpaque = false
        self.backgroundColor = .clear

        let drawingView = DrawingView(
            copyAction: { [weak self] annotations in
                guard let self = self else { return }
                AnnotationManager.shared.copyScreenToClipboard(screen: self.currentScreen, annotations: annotations)
            },
            actionPublisher: AnnotationManager.shared.actionPublisher
        )
        .environmentObject(AnnotationManager.shared)
        
        let hostingView = NSHostingView(rootView: drawingView)
        hostingView.focusRingType = .none

        let screenshotView = NSImageView(image: screenshot)
        
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        containerView.layer?.borderWidth = 2.0
        
        containerView.addSubview(screenshotView)
        containerView.addSubview(hostingView)
        
        screenshotView.frame = containerView.bounds
        screenshotView.autoresizingMask = [.width, .height]
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        self.contentView = containerView
        
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.makeKeyAndOrderFront(nil)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
