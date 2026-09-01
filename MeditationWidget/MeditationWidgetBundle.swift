import WidgetKit
import SwiftUI

/// The entry point of the widget extension. A bundle can host several widgets;
/// for now it's just the one.
@main
struct MeditationWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeditationWidget()
    }
}
