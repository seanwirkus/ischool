//
//  Assignment.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Assignment {
    var id: UUID
    var title: String
    var assignmentDescription: String?
    var dueDate: Date?
    var isCompleted: Bool
    var priority: String // "Low", "Medium", "High"
    var createdDate: Date
    @Relationship var course: Course?
    @Relationship(deleteRule: .nullify, inverse: \LectureTask.assignment) var linkedLectureTasks: [LectureTask] = []

    init(id: UUID = UUID(), title: String, assignmentDescription: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false, priority: String = "Medium", createdDate: Date = Date(), course: Course? = nil) {
        self.id = id
        self.title = title
        self.assignmentDescription = assignmentDescription
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.createdDate = createdDate
        self.course = course
    }

    var priorityColor: Color {
        switch priority {
        case "High": return .red
        case "Medium": return .orange
        case "Low": return .green
        default: return .gray
        }
    }
}