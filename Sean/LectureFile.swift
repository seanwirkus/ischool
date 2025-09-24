//
//  LectureFile.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData

@Model
final class LectureFile {
    var id: UUID
    var filename: String
    var fileData: Data
    var timestamp: Date
    @Relationship var lecture: Lecture?

    init(id: UUID = UUID(), filename: String, fileData: Data, timestamp: Date = Date(), lecture: Lecture? = nil) {
        self.id = id
        self.filename = filename
        self.fileData = fileData
        self.timestamp = timestamp
        self.lecture = lecture
    }
}