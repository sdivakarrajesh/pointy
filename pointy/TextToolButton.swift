import SwiftUI

struct TextToolButton: View {
    @EnvironmentObject var annotationManager: AnnotationManager
    @Binding var showTextPopover: Bool
    @Binding var textInput: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        Button(action: {
            annotationManager.selectedTool = .text
            showTextPopover = true
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(annotationManager.selectedTool == .text ? Color.blue.opacity(0.3) : Color.white)
                Image(systemName: "textformat")
                    .font(.body)
                    .padding(2)
                Text("\(DrawingTool.text.rawValue)")
                    .font(.caption2)
                    .offset(x: 8, y: -8)
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(BorderlessButtonStyle())
        .popover(isPresented: $showTextPopover) {
            TextField("Enter text", text: $textInput, onCommit: {
                if !textInput.isEmpty {
                    annotationManager.actionPublisher.send(.addText(textInput))
                }
                textInput = ""
                showTextPopover = false
                annotationManager.selectedTool = .select
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
            .focused($isTextFieldFocused)
        }
        .onChange(of: showTextPopover) {
            if showTextPopover {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isTextFieldFocused = true
                }
            } else {
                if annotationManager.selectedTool == .text {
                    annotationManager.selectedTool = .select
                }
            }
        }
    }
}
