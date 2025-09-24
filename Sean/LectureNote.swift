//
//  LectureNote.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData

@Model
final class LectureNote {
    var id: UUID
    var content: String
    var timestamp: Date
    @Relationship var lecture: Lecture?

    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), lecture: Lecture? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.lecture = lecture
    }
}