//
//  AddSyllabusSheet.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI

struct AddSyllabusSheet: View {
    let course: Course
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Syllabus Item") {
                    TextField("Title", text: $title)
                    TextField("Content", text: $content, axis: .vertical)
                        .lineLimit(5...20)
                }
            }
            .navigationTitle("Add Syllabus")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, content)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}