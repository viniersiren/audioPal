//
//  audioPalWidgetBundle.swift
//  audioPalWidget
//
//  Created by Devin Studdard on 7/5/25.
//

import WidgetKit
import SwiftUI

@main
struct audioPalWidgetBundle: WidgetBundle {
    var body: some Widget {
        audioPalWidget()
        audioPalWidgetControl()
        audioPalWidgetLiveActivity()
    }
}
