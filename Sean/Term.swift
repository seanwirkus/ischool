//  Term.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import Foundation
import SwiftData

@Model
final class Term {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    @Relationship(deleteRule: .cascade, inverse: \Course.term) var courses: [Course] = []

    init(id: UUID = UUID(), name: String, startDate: Date, endDate: Date) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
}
