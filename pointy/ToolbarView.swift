import SwiftUI
import Combine

struct ToolbarView: View {
    @EnvironmentObject var annotationManager: AnnotationManager
    @State private var textInput: String = ""
    @State private var showTextPopover = false
    @State private var isAnnotationSelected = false

    var body: some View {
        HStack {
            ForEach(DrawingTool.allCases.filter { $0 != .select }, id: \.self) { tool in
                if tool == .text {
                    TextToolButton(showTextPopover: $showTextPopover, textInput: $textInput)
                } else {
                    Button(action: { annotationManager.selectedTool = tool }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(annotationManager.selectedTool == tool ? Color.blue.opacity(0.3) : Color.white)
                            Image(systemName: tool.imageName)
                                .font(.body)
                                .padding(2)
                            Text("\(tool.rawValue)")
                                .font(.caption2)
                                .offset(x: 8, y: -8)
                        }
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            Button(action: { annotationManager.showColorPicker.toggle() }) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(annotationManager.selectedColor)
                    .frame(width: 30, height: 30)
                    .padding(5)
            }
            .buttonStyle(BorderlessButtonStyle())
            .popover(isPresented: $annotationManager.showColorPicker, arrowEdge: .bottom) {
                ColorPickerView(selectedColor: $annotationManager.selectedColor, showColorPicker: $annotationManager.showColorPicker)
            }

            Button(action: {
                self.annotationManager.actionPublisher.send(.delete)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isAnnotationSelected ? Color.red.opacity(0.3) : Color.white)
                    Image(systemName: "trash")
                        .font(.body)
                        .padding(2)
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(!isAnnotationSelected)

            Button(action: {
                self.annotationManager.actionPublisher.send(.copy)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                        .padding(2)
                        
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(BorderlessButtonStyle())

            Button(action: {
                annotationManager.hideApplication()
            }) {
                ZStack {
                    Image(systemName: "xmark.circle")
                        .font(.body)
                        .padding(2)
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding()
        .background(
            Color.white.opacity(0.9)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if let window = NSApp.keyWindow {
                                let newOrigin = CGPoint(
                                    x: window.frame.origin.x + value.translation.width,
                                    y: window.frame.origin.y - value.translation.height
                                )
                                window.setFrameOrigin(newOrigin)
                            }
                        }
                )
        )
        .cornerRadius(10)
        .shadow(radius: 5)
        .onReceive(annotationManager.selectionPublisher) { annotation in
            isAnnotationSelected = annotation != nil
        }
    }
}
