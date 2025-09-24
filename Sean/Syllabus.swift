//
//  Syllabus.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData

@Model
final class Syllabus {
    var id: UUID
    var title: String
    var content: String
    var lastModified: Date
    @Relationship var course: Course?

    init(id: UUID = UUID(), title: String, content: String, lastModified: Date = Date(), course: Course? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.lastModified = lastModified
        self.course = course
    }
}