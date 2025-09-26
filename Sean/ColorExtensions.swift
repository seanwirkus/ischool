//
//  ColorExtensions.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

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
    
    func toHexString() -> String? {
        #if canImport(AppKit)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #elseif canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return nil
        #endif
    }

    static var platformCardBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.15)
        #endif
    }

    static var platformChipBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray5)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.25)
        #endif
    }

    static var platformElevatedBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.tertiarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    func mixed(with color: Color, amount: CGFloat) -> Color {
        let amount = min(max(amount, 0), 1)

        #if canImport(UIKit)
        let base = UIColor(self)
        let target = UIColor(color)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        guard base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              target.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return self
        }

        let r = r1 + (r2 - r1) * amount
        let g = g1 + (g2 - g1) * amount
        let b = b1 + (b2 - b1) * amount
        let a = a1 + (a2 - a1) * amount

        return Color(red: r, green: g, blue: b, opacity: a)
        #elseif canImport(AppKit)
        guard let base = NSColor(self).usingColorSpace(.deviceRGB),
              let target = NSColor(color).usingColorSpace(.deviceRGB) else {
            return self
        }

        let r = base.redComponent + (target.redComponent - base.redComponent) * amount
        let g = base.greenComponent + (target.greenComponent - base.greenComponent) * amount
        let b = base.blueComponent + (target.blueComponent - base.blueComponent) * amount
        let a = base.alphaComponent + (target.alphaComponent - base.alphaComponent) * amount

        return Color(red: r, green: g, blue: b, opacity: a)
        #else
        return self
        #endif
    }

    func lighten(by amount: CGFloat) -> Color {
        mixed(with: .white, amount: amount)
    }

    func darken(by amount: CGFloat) -> Color {
        mixed(with: .black, amount: amount)
    }
}