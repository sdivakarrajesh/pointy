import SwiftUI
import Combine

struct DrawingView: View {
    @EnvironmentObject var annotationManager: AnnotationManager
    @State private var annotations: [Annotation] = []
    @State private var currentAnnotation: Annotation
    @State private var isFocused: Bool = false
    @State private var textInput: String = ""
    
    @State private var selectedAnnotation: Annotation?
    @State private var draggingStartPoint: CGPoint?
    @State private var initialAnnotation: Annotation?

    @State private var draggingHandle: Int?
    @State private var startPoint: CGPoint = .zero
    
    var copyAction: ([Annotation]) -> Void
    var actionPublisher: PassthroughSubject<DrawingAction, Never>

    init(copyAction: @escaping ([Annotation]) -> Void, actionPublisher: PassthroughSubject<DrawingAction, Never>) {
        self.copyAction = copyAction
        self.actionPublisher = actionPublisher
        _currentAnnotation = State(initialValue: Annotation(tool: .pencil, color: .red))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    for annotation in annotations {
                        draw(annotation: annotation, in: context, size: size)
                    }
                    draw(annotation: currentAnnotation, in: context, size: size)
                }
                .background(Color.clear)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged({ value in
                            self.startPoint = value.startLocation
                            print("Drag changed: \(value.location)")
                            if annotationManager.selectedTool == .select {
                                if draggingStartPoint == nil {
                                    draggingStartPoint = value.startLocation
                                    
                                    for i in (0..<annotations.count).reversed() {
                                        let boundingBox = getBoundingBox(for: annotations[i])
                                        let handles = getResizeHandles(for: boundingBox)
                                        for j in 0..<handles.count {
                                            let handleRect = CGRect(x: handles[j].x - 5, y: handles[j].y - 5, width: 10, height: 10)
                                            if handleRect.contains(value.startLocation) {
                                                annotations[i].isSelected = true
                                                selectedAnnotation = annotations[i]
                                                draggingHandle = j
                                                initialAnnotation = annotations[i]
                                                return
                                            }
                                        }
                                        
                                        if boundingBox.contains(value.startLocation) {
                                            for i in 0..<annotations.count {
                                                annotations[i].isSelected = false
                                            }
                                            annotations[i].isSelected = true
                                            selectedAnnotation = annotations[i]
                                            initialAnnotation = annotations[i]
                                            annotationManager.selectionPublisher.send(annotations[i])
                                            return
                                        }
                                    }
                                    
                                    for i in 0..<annotations.count {
                                        annotations[i].isSelected = false
                                    }
                                    selectedAnnotation = nil
                                    draggingHandle = nil
                                    initialAnnotation = nil
                                    annotationManager.selectionPublisher.send(nil)
                                }
                                
                                guard let selectedAnnotation = selectedAnnotation, let index = annotations.firstIndex(where: { $0.id == selectedAnnotation.id }), let initialAnnotation = initialAnnotation else { return }
                                
                                let translation = CGPoint(
                                    x: value.location.x - draggingStartPoint!.x,
                                    y: value.location.y - draggingStartPoint!.y
                                )
                                
                                if let draggingHandle = draggingHandle {
                                    var boundingBox = getBoundingBox(for: initialAnnotation)
                                    
                                    switch draggingHandle {
                                    case 0: // Top-left
                                        boundingBox.origin.x += translation.x
                                        boundingBox.origin.y += translation.y
                                        boundingBox.size.width -= translation.x
                                        boundingBox.size.height -= translation.y
                                    case 1: // Top-middle
                                        boundingBox.origin.y += translation.y
                                        boundingBox.size.height -= translation.y
                                    case 2: // Top-right
                                        boundingBox.origin.y += translation.y
                                        boundingBox.size.width += translation.x
                                        boundingBox.size.height -= translation.y
                                    case 3: // Middle-left
                                        boundingBox.origin.x += translation.x
                                        boundingBox.size.width -= translation.x
                                    case 4: // Middle-right
                                        boundingBox.size.width += translation.x
                                    case 5: // Bottom-left
                                        boundingBox.origin.x += translation.x
                                        boundingBox.size.width -= translation.x
                                        boundingBox.size.height += translation.y
                                    case 6: // Bottom-middle
                                        boundingBox.size.height += translation.y
                                    case 7: // Bottom-right
                                        boundingBox.size.width += translation.x
                                        boundingBox.size.height += translation.y
                                    default:
                                        break
                                    }
                                    
                                    if selectedAnnotation.tool == .text {
                                        annotations[index].frame = boundingBox
                                    } else {
                                        annotations[index].points = [boundingBox.origin, CGPoint(x: boundingBox.maxX, y: boundingBox.maxY)]
                                    }
                                    
                                } else {
                                    if selectedAnnotation.tool == .text {
                                        if let initialFrame = initialAnnotation.frame {
                                            annotations[index].frame?.origin = CGPoint(
                                                x: initialFrame.origin.x + translation.x,
                                                y: initialFrame.origin.y + translation.y
                                            )
                                        }
                                    } else {
                                        annotations[index].points = initialAnnotation.points.map {
                                            CGPoint(x: $0.x + translation.x, y: $0.y + translation.y)
                                        }
                                    }
                                }
                                
                            } else {
                                if currentAnnotation.points.isEmpty {
                                    currentAnnotation.tool = annotationManager.selectedTool
                                    currentAnnotation.color = annotationManager.selectedColor
                                    currentAnnotation.points.append(value.startLocation)
                                }
                                
                                if annotationManager.selectedTool == .pencil {
                                    currentAnnotation.points.append(value.location)
                                } else {
                                    if currentAnnotation.points.count > 1 {
                                        currentAnnotation.points[1] = value.location
                                    } else {
                                        currentAnnotation.points.append(value.location)
                                    }
                                }
                            }
                        })
                        .onEnded({ value in
                            print("Drag ended")
                            if annotationManager.selectedTool == .select {
                                draggingStartPoint = nil
                                draggingHandle = nil
                                initialAnnotation = nil
                            } else {
                                if !currentAnnotation.points.isEmpty {
                                    var annotation = currentAnnotation
                                    if annotation.tool != .pencil {
                                        for i in 0..<annotations.count {
                                            annotations[i].isSelected = false
                                        }
                                        annotation.isSelected = true
                                        selectedAnnotation = annotation
                                        annotationManager.selectedTool = .select
                                        annotationManager.selectionPublisher.send(annotation)
                                    }
                                    self.annotations.append(annotation)
                                }
                                self.currentAnnotation = Annotation(tool: annotationManager.selectedTool, color: annotationManager.selectedColor)
                            }
                        })
                )

            }
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        if let annotation = annotations.first(where: { getBoundingBox(for: $0).contains(startPoint) }) {
                            if annotation.tool == .text {
                                self.selectedAnnotation = annotation
                            }
                        }
                    }
            )
            .focusEffectDisabled()
            .focusable()
            .onKeyPress { press in
                if press.key == .delete {
                    if selectedAnnotation != nil {
                        actionPublisher.send(.delete)
                        return .handled
                    }
                }
                return .ignored
            }
            .onAppear {
                // Ensure focus is set after the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("Setting focus to drawing view")
                    isFocused = true
                }
                // Also try to request focus immediately
                isFocused = true
            }
            .onChange(of: isFocused) { oldValue, newValue in
                print("Focus changed from \(oldValue) to \(newValue)")
            }
            .onReceive(actionPublisher) { action in
                switch action {
                case .selectTool(let tool):
                    annotationManager.selectedTool = tool
                case .exit:
                    AnnotationManager.shared.hideWindows()
                case .copy:
                    copyAction(annotations)
                    annotationManager.hideApplication()
                case .delete:
                    if let selectedAnnotation = selectedAnnotation {
                        annotations.removeAll { $0.id == selectedAnnotation.id }
                        self.selectedAnnotation = nil
                        annotationManager.selectionPublisher.send(nil)
                    }
                case .addText(let text):
                    addNewTextAnnotation(at: geometry.size.center, text: text)
                case .selectAnnotation(let annotation):
                    self.selectedAnnotation = annotation
                }
            }
            .onChange(of: annotationManager.selectedTool) { oldTool, newTool in
                if newTool != .select {
                    self.selectedAnnotation = nil
                    annotationManager.selectionPublisher.send(nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func addNewTextAnnotation(at center: CGPoint, text: String) {
        let textAnnotation = Annotation(
            tool: .text,
            color: annotationManager.selectedColor,
            text: text,
            frame: CGRect(x: center.x - 50, y: center.y - 20, width: 100, height: 40)
        )
        
        annotations.append(textAnnotation)
        selectedAnnotation = textAnnotation
        annotationManager.selectionPublisher.send(textAnnotation)
    }

    static func draw(annotations: [Annotation], in context: CGContext, size: CGSize) {
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        for annotation in annotations {
            let color = NSColor(annotation.color).cgColor
            context.setStrokeColor(color)
            context.setLineWidth(annotation.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            guard !annotation.points.isEmpty else { continue }

            switch annotation.tool {
            case .pencil:
                if let firstPoint = annotation.points.first {
                    context.move(to: firstPoint)
                    for point in annotation.points.dropFirst() {
                        context.addLine(to: point)
                    }
                    context.strokePath()
                }
            case .rectangle:
                guard annotation.points.count >= 2 else { continue }
                let start = annotation.points.first!
                let end = annotation.points.last!
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
                context.stroke(rect)
            case .circle:
                guard annotation.points.count >= 2 else { continue }
                let start = annotation.points.first!
                let end = annotation.points.last!
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
                context.strokeEllipse(in: rect)
            case .arrow:
                guard annotation.points.count >= 2 else { continue }
                let start = annotation.points.first!
                let end = annotation.points.last!
                
                context.move(to: start)
                context.addLine(to: end)

                let angle = atan2(start.y - end.y, start.x - end.x)
                let arrowLength: CGFloat = 15
                let arrowAngle = CGFloat.pi / 6

                let p1 = CGPoint(x: end.x + arrowLength * cos(angle - arrowAngle), y: end.y + arrowLength * sin(angle - arrowAngle))
                let p2 = CGPoint(x: end.x + arrowLength * cos(angle + arrowAngle), y: end.y + arrowLength * sin(angle + arrowAngle))

                context.move(to: end)
                context.addLine(to: p1)
                context.move(to: end)
                context.addLine(to: p2)
                
                context.strokePath()
            case .roundedRectangle:
                guard annotation.points.count >= 2 else { continue }
                let start = annotation.points.first!
                let end = annotation.points.last!
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
                let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
                context.addPath(path)
                context.strokePath()
            case .text, .select:
                break
            }
        }
        context.restoreGState()
    }

    private func draw(annotation: Annotation, in context: GraphicsContext, size: CGSize) {
        if annotation.tool != .text && annotation.points.isEmpty {
            return
        }

        var path = Path()
        switch annotation.tool {
        case .select:
            break
        case .pencil:
            path.addLines(annotation.points)
            context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .arrow:
            guard annotation.points.count >= 2 else { return }
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

            context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .rectangle:
            guard annotation.points.count >= 2 else { return }
            let start = annotation.points.first!
            let end = annotation.points.last!
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
            path.addRect(rect)
            context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .roundedRectangle:
            guard annotation.points.count >= 2 else { return }
            let start = annotation.points.first!
            let end = annotation.points.last!
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 10, height: 10))
            context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .circle:
            guard annotation.points.count >= 2 else { return }
            let start = annotation.points.first!
            let end = annotation.points.last!
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
            path.addEllipse(in: rect)
            context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .text:
            if let text = annotation.text, !text.isEmpty, let frame = annotation.frame {
                let textField = Text(text)
                    .font(.system(size: 24))
                    .foregroundColor(annotation.color)
                context.draw(textField, in: frame)
            }
        }
        
        if annotation.isSelected {
            let boundingBox = getBoundingBox(for: annotation)
            context.stroke(Path(boundingBox), with: .color(.gray), lineWidth: 1)
            
            let handleSize: CGFloat = 10
            let handles = getResizeHandles(for: boundingBox)
            for handle in handles {
                let handleRect = CGRect(x: handle.x - handleSize / 2, y: handle.y - handleSize / 2, width: handleSize, height: handleSize)
                context.fill(Path(ellipseIn: handleRect), with: .color(.white))
                context.stroke(Path(ellipseIn: handleRect), with: .color(.gray), lineWidth: 1)
            }
        }
    }

    private func getBoundingBox(for annotation: Annotation) -> CGRect {
        if annotation.tool == .text {
            if let frame = annotation.frame {
                return frame
            }
        }
        
        guard !annotation.points.isEmpty else { return .zero }
        
        if let frame = annotation.frame {
            return frame
        }
        
        var minX = annotation.points[0].x
        var minY = annotation.points[0].y
        var maxX = annotation.points[0].x
        var maxY = annotation.points[0].y
        
        for point in annotation.points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func getResizeHandles(for rect: CGRect) -> [CGPoint] {
        return [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var showColorPicker: Bool
    let presetColors: [Color] = [.red, .green, .blue, .yellow, .orange, .purple]
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            Text("Select a color")
                .font(.headline)
                .padding(.bottom, 10)
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(presetColors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 25, height: 25)
                            .overlay(Circle().stroke(Color.gray, lineWidth: selectedColor == color ? 2 : 0))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding()

            CustomColorPicker(selectedColor: $selectedColor)
        }
        .padding()
    }
}

struct CustomColorPicker: View {
    @Binding var selectedColor: Color
    
    @State private var hue: CGFloat = 0
    @State private var saturation: CGFloat = 1
    @State private var brightness: CGFloat = 1

    var body: some View {
        VStack {
            GeometryReader { geometry in
                ZStack {
                    // Saturation and Brightness Box
                    Rectangle()
                        .fill(Color(hue: hue, saturation: 1, brightness: 1))
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.white, .clear]), startPoint: .leading, endPoint: .trailing))
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .bottom, endPoint: .top))

                    // Draggable circle
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(x: saturation * geometry.size.width, y: (1 - brightness) * geometry.size.height)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    saturation = min(max(0, value.location.x / geometry.size.width), 1)
                                    brightness = 1 - min(max(0, value.location.y / geometry.size.height), 1)
                                    updateColor()
                                }
                        )
                }
                .frame(height: 150)
            }
            .frame(height: 150)

            // Hue Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    LinearGradient(gradient: Gradient(colors: (0...360).map {
                        Color(hue: CGFloat($0) / 360.0, saturation: 1, brightness: 1)
                    }), startPoint: .leading, endPoint: .trailing)
                    .frame(height: 20)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .offset(x: hue * geometry.size.width - 12)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    hue = min(max(0, value.location.x / geometry.size.width), 1)
                                    updateColor()
                                }
                        )
                }
            }
            .frame(height: 24)
        }
        .onChange(of: selectedColor) { oldValue, newValue in
            let hsb = NSColor(newValue).hsb
            if abs(hsb.hue - hue) > 0.001 || abs(hsb.saturation - saturation) > 0.001 || abs(hsb.brightness - brightness) > 0.001 {
                hue = hsb.hue
                saturation = hsb.saturation
                brightness = hsb.brightness
            }
        }
        .onAppear {
            let hsb = NSColor(selectedColor).hsb
            hue = hsb.hue
            saturation = hsb.saturation
            brightness = hsb.brightness
        }
    }

    private func updateColor() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

extension NSColor {
    var hsb: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard let srgbColor = usingColorSpace(.sRGB) else { return (0,0,0,0) }
        srgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness, alpha)
    }
}
