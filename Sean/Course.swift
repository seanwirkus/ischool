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
    @Relationship(deleteRule: .cascade, inverse: \Lecture.course) var lectures: [Lecture] = []

    init(id: UUID = UUID(), name: String, detail: String? = nil, color: String = "#4ECDC4", createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.detail = detail
        self.color = color
        self.createdDate = createdDate
    }

    var colorValue: Color {
        Color(hex: color) ?? .blue
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

