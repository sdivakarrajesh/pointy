import SwiftUI
import Combine

enum DrawingAction {
    case selectTool(DrawingTool)
    case exit
    case copy
    case delete
    case addText(String)
    case selectAnnotation(Annotation?)
}

enum DrawingTool: Int, CaseIterable {
    case select = 0
    case pencil = 1
    case arrow = 2
    case rectangle = 3
    case roundedRectangle = 4
    case circle = 5
    case text = 6
}

struct Annotation: Identifiable {
    let id = UUID()
    var points: [CGPoint] = []
    var tool: DrawingTool
    var color: Color
    var lineWidth: CGFloat = 5
    var text: String?
    var frame: CGRect?
    var isSelected: Bool = false
}

extension DrawingTool {
    var imageName: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .pencil: return "pencil"
        case .arrow: return "arrow.right"
        case .rectangle: return "rectangle"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .circle: return "circle"
        case .text: return "textformat"
        }
    }
}
