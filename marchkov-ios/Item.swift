//
//  Item.swift
//  marchkov-ios
//
//  Created by 夏一飞 on 2024/7/15.
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
