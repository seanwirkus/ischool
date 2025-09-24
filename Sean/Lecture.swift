//
//  Lecture.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData

@Model
final class Lecture {
    var id: UUID
    var title: String
    var date: Date
    var notes: String?
    @Relationship(deleteRule: .cascade, inverse: \LectureNote.lecture) var lectureNotes: [LectureNote] = []
    @Relationship(deleteRule: .cascade, inverse: \LectureFile.lecture) var lectureFiles: [LectureFile] = []
    @Relationship var course: Course?

    init(id: UUID = UUID(), title: String, date: Date, notes: String? = nil, course: Course? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.notes = notes
        self.course = course
    }
}