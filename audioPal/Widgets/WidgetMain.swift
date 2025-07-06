import WidgetKit
import SwiftUI

// Widget extension entry point - no @main needed when in same project
struct AudioPalWidgetExtension: WidgetBundle {
    var body: some Widget {
        AudioPalWidget()
    }
} 