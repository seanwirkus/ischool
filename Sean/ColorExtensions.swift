//
//  ColorExtensions.swift
//  Sean
//
//  Created by Assistant on 9/24/25.
//

import SwiftUI

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
}