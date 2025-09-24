//
//  Course.swift
//  Sean
//
//  Created by Sean Wirkus on 9/21/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Course {
    var id: UUID
    var name: String
    var detail: String?
    var color: String // hex color
    var createdDate: Date
    var termType: String? // "Semester" or "Quarter"
    var units: Int?
    var termStartDate: Date?
    var termEndDate: Date?
    @Relationship var term: Term?
    @Relationship(deleteRule: .cascade, inverse: \Lecture.course) var lectures: [Lecture] = []
    @Relationship(deleteRule: .cascade, inverse: \CourseMeeting.course) var meetings: [CourseMeeting] = []
    @Relationship(deleteRule: .cascade, inverse: \Syllabus.course) var syllabi: [Syllabus] = []
    @Relationship(deleteRule: .cascade, inverse: \Assignment.course) var assignments: [Assignment] = []

    init(id: UUID = UUID(), name: String, detail: String? = nil, color: String = "#4ECDC4", createdDate: Date = Date(), termType: String? = nil, units: Int? = nil, termStartDate: Date? = nil, termEndDate: Date? = nil, term: Term? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.color = color
        self.createdDate = createdDate
        self.termType = termType
        self.units = units
        self.termStartDate = termStartDate
        self.termEndDate = termEndDate
        self.term = term
    }

    var colorValue: Color {
        Color(hex: color) ?? .blue
    }
}

