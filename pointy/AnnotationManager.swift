
import SwiftUI
import Combine
import ScreenCaptureKit

@MainActor
class AnnotationManager: ObservableObject {
    static let shared = AnnotationManager()
    private var windowControllers: [NSWindowController] = []
    private var toolbarController: NSWindowController?
    private var activeScreenshotters: [UUID: Screenshotter] = [:]

    @Published var selectedTool: DrawingTool = .select
    @Published var selectedColor: Color = .red
    @Published var showColorPicker = false
    let actionPublisher = PassthroughSubject<DrawingAction, Never>()
    let selectionPublisher = PassthroughSubject<Annotation?, Never>()

    func showWindows(on targetScreen: NSScreen? = nil) {
        Task {
            let screens = targetScreen.map { [$0] } ?? NSScreen.screens
            for screen in screens {
                let nsImage = await captureScreenshot(screen: screen)
                guard let nsImage = nsImage else {
                    print("Failed to capture screenshot.")
                    continue
                }
                
                print("Screenshot captured for screen: \(screen.localizedName)")
                
                let window = AnnotationWindow(
                    contentRect: screen.frame,
                    screen: screen,
                    screenshot: nsImage
                )
                window.level = .screenSaver
                
                let controller = NSWindowController(window: window)
                controller.showWindow(nil)
                self.windowControllers.append(controller)
                
                // Ensure the annotation window is key and front
                window.makeKeyAndOrderFront(nil)
            }
            
            // Show the toolbar only after the annotation windows are created
            self.showToolbar()
        }
    }

    func hideWindows() {
        for controller in windowControllers {
            controller.close()
        }
        windowControllers.removeAll()
        toolbarController?.close()
        toolbarController = nil
    }

    func hideApplication() {
        hideWindows()
        NSApp.hide(nil)
    }
    
    private func showToolbar() {
        if toolbarController == nil {
            print("Creating toolbar...")
            let toolbarView = ToolbarView()
            let toolbarWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 50),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = toolbarWindow.frame
                let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
                let y = screenFrame.origin.y + screenFrame.height - windowFrame.height
                toolbarWindow.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                toolbarWindow.center()
            }

            toolbarWindow.isOpaque = false
            toolbarWindow.backgroundColor = .clear
            toolbarWindow.level = .screenSaver + 1
            toolbarWindow.isMovableByWindowBackground = true
            toolbarWindow.hasShadow = false
            toolbarWindow.contentView = NSHostingView(rootView: toolbarView.environmentObject(self))
            toolbarController = NSWindowController(window: toolbarWindow)
        }
        toolbarController?.showWindow(nil)
        toolbarController?.window?.makeKeyAndOrderFront(nil)
        print("Windows shown.")
    }

    func copyScreenToClipboard(screen: NSScreen, annotations: [Annotation]) {
        guard let windowController = windowControllers.first(where: { ($0.window as? AnnotationWindow)?.currentScreen == screen }),
              let annotationWindow = windowController.window as? AnnotationWindow else {
            print("Error: Annotation window not found for screen.")
            return
        }
        
        let nsScreenImage = annotationWindow.screenshot

        guard let tiffData = nsScreenImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else {
            return
        }

        let image = NSImage(size: screen.frame.size)
        image.lockFocus()
        
        rep.draw(in: NSRect(origin: .zero, size: screen.frame.size))

        // Draw annotations on top of the screenshot
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return
        }
        
        context.saveGState()
        context.translateBy(x: 0, y: screen.frame.height)
        context.scaleBy(x: 1, y: -1)

        for annotation in annotations {
            if annotation.tool == .text {
                if let text = annotation.text, let frame = annotation.frame {
                    context.saveGState()
                    context.scaleBy(x: 1, y: -1)
                    context.translateBy(x: 0, y: -screen.frame.height)
                    
                    let newY = screen.frame.height - frame.origin.y - frame.height
                    let newFrame = CGRect(x: frame.origin.x, y: newY, width: frame.width, height: frame.height)
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 24),
                        .foregroundColor: NSColor(annotation.color)
                    ]
                    let attributedString = NSAttributedString(string: text, attributes: attributes)
                    attributedString.draw(in: newFrame)
                    context.restoreGState()
                }
            } else {
                let path = createPath(for: annotation)
                context.addPath(path.cgPath)
                context.setStrokeColor(NSColor(annotation.color).cgColor)
                context.setLineWidth(annotation.lineWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.strokePath()
            }
        }
        
        context.restoreGState()
        
        image.unlockFocus()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    private func createPath(for annotation: Annotation) -> Path {
        var path = Path()
        
        guard !annotation.points.isEmpty else { return path }

        switch annotation.tool {
        case .pencil:
            path.addLines(annotation.points)
        case .rectangle:
            guard annotation.points.count >= 2 else { return path }
            let start = annotation.points.first!
            let end = annotation.points.last!
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
            path.addRect(rect)
        case .circle:
            guard annotation.points.count >= 2 else { return path }
            let start = annotation.points.first!
            let end = annotation.points.last!
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
            path.addEllipse(in: rect)
        case .arrow:
            guard annotation.points.count >= 2 else { return path }
            let start = annotation.points.first!
            let end = annotation.points.last!
            path.move(to: start)
            path.addLine(to: end)

            let angle = atan2(start.y - end.y, start.x - end.x)
            let arrowLength: CGFloat = 15
            let arrowAngle = CGFloat.pi / 6

            let p1 = CGPoint(x: end.x + arrowLength * cos(angle - arrowAngle), y: end.y + arrowLength * sin(angle - arrowAngle))
            let p2 = CGPoint(x: end.x + arrowLength * cos(angle + arrowAngle), y: end.y + arrowLength * sin(angle + arrowAngle))

            path.move(to: end)
            path.addLine(to: p1)
            path.move(to: end)
            path.addLine(to: p2)
        case .roundedRectangle:
            guard annotation.points.count >= 2 else { return path }
            let start = annotation.points.first!
            let end = annotation.points.last!
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 10, height: 10))
        case .text, .select:
            break
        }
        
        return path
    }

    private func captureScreenshot(screen: NSScreen) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let content = try await SCShareableContent.current
                    guard let display = (content.displays.first { $0.displayID == screen.displayID }) else {
                        print("Could not find display for screen")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    config.width = Int(screen.frame.width)
                    config.height = Int(screen.frame.height)
                    config.minimumFrameInterval = CMTime(value: 1, timescale: 2) // Capture at 2 FPS
                    config.pixelFormat = kCVPixelFormatType_32BGRA
                    config.showsCursor = false
                    
                    let id = UUID()
                    let screenshotter = Screenshotter(id: id, completion: { [weak self] image in
                        continuation.resume(returning: image)
                        self?.activeScreenshotters.removeValue(forKey: id)
                    }, filter: filter, configuration: config)
                    
                    self.activeScreenshotters[id] = screenshotter
                    try screenshotter.start()

                } catch {
                    print("Error capturing screenshot: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

class Screenshotter: NSObject, SCStreamOutput, SCStreamDelegate {
    let id: UUID
    let completion: (NSImage?) -> Void
    var stream: SCStream?
    let filter: SCContentFilter
    let configuration: SCStreamConfiguration
    
    init(id: UUID, completion: @escaping (NSImage?) -> Void, filter: SCContentFilter, configuration: SCStreamConfiguration) {
        self.id = id
        self.completion = completion
        self.filter = filter
        self.configuration = configuration
    }
    
    func start() throws {
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        stream?.startCapture()
    }
    
    func stop() {
        stream?.stopCapture()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            completion(nil)
            stop()
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            completion(nil)
            stop()
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: ciImage.extent.size)
        completion(nsImage)
        stop()
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error.localizedDescription)")
        completion(nil)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

