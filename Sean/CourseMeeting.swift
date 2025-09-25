//
//  CourseMeeting.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData

@Model
final class CourseMeeting {
    var id: UUID
    /// 1 = Sunday ... 7 = Saturday (Calendar.current.weekday)
    var dayOfWeek: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var meetingType: String
    @Relationship var course: Course?

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        meetingType: String = "Class",
        course: Course? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.meetingType = meetingType
        self.course = course
    }
}
