//
//  LectureTask.swift
//  Sean
//
//  Created by Assistant on 9/25/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class LectureTask {
    var id: UUID
    var title: String
    var details: String?
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Lecture.lectureTasks) var lecture: Lecture?
    @Relationship(deleteRule: .nullify, inverse: \Assignment.linkedLectureTasks) var assignment: Assignment?

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        lecture: Lecture? = nil,
        assignment: Assignment? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.lecture = lecture
        self.assignment = assignment
    }

    var accentColor: Color {
        if let courseColor = lecture?.course?.colorValue {
            return courseColor
        }
        return .accentColor
    }
}
