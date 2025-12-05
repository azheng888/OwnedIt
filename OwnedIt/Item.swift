//
//  Item.swift
//  OwnedIt
//
//  Created by Allan Zheng on 12/4/25.
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
