//
//  audioPalWidgetLiveActivity.swift
//  audioPalWidget
//
//  Created by Devin Studdard on 7/5/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct audioPalWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

// Temporarily disabled to fix main symbol conflict
struct audioPalWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: audioPalWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension audioPalWidgetAttributes {
    fileprivate static var preview: audioPalWidgetAttributes {
        audioPalWidgetAttributes(name: "World")
    }
}

extension audioPalWidgetAttributes.ContentState {
    fileprivate static var smiley: audioPalWidgetAttributes.ContentState {
        audioPalWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: audioPalWidgetAttributes.ContentState {
         audioPalWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: audioPalWidgetAttributes.preview) {
   audioPalWidgetLiveActivity()
} contentStates: {
    audioPalWidgetAttributes.ContentState.smiley
    audioPalWidgetAttributes.ContentState.starEyes
}
