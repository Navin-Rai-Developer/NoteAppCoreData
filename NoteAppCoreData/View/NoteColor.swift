//
//  NoteColor.swift
//  NoteAppCoreData
//
//  Created by Navin Rai on 25/02/26.
//

import Foundation
import SwiftUI
// ─── Note Colors ─────────────────────────────────────────────
enum NoteColor: String, CaseIterable {
    case yellow = "#FEF08A"
    case green  = "#BBF7D0"
    case blue   = "#BAE6FD"
    case pink   = "#FBCFE8"
    case purple = "#E9D5FF"
    case orange = "#FED7AA"
    case white  = "#FFFFFF"
    case gray   = "#E5E7EB"

    var color: Color { Color(hex: self.rawValue) ?? .white }

    var label: String {
        switch self {
        case .yellow: return "Yellow"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .pink:   return "Pink"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .white:  return "White"
        case .gray:   return "Gray"
        }
    }
}

// ─── Hex Color Extension ─────────────────────────────────────
extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                   .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8)  / 255.0,
            blue:  Double( rgb & 0x0000FF)         / 255.0
        )
    }
}
