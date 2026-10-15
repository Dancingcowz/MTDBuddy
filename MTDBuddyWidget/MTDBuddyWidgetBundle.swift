import WidgetKit
import SwiftUI

@main
struct MTDBuddyWidgetBundle: WidgetBundle {
    var body: some Widget {
        MTDWidget()
        BusLiveActivityWidget()
    }
}
