// ColorChipLabel.swift
// Custom view for color selection chips in AddCourseSheet

import SwiftUI

struct ColorChipLabel: View {
    let hex: String
    let color: String
    let selected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: hex) ?? Color.gray)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().stroke(selected ? Color.accentColor : .secondary.opacity(0.15), lineWidth: selected ? 3 : 1)
                )
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(tagName(for: hex))
    }
    
    func tagName(for hex: String) -> String {
        if Color(hex: hex) != nil {
            // Optionally name by color
            return "Color chip"
        }
        return hex
    }
}

