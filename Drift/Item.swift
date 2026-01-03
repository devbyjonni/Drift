//
//  Item.swift
//  Drift
//
//  Created by Jonni Akesson on 2026-01-03.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
