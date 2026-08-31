//  Platform.swift
//  Cross-platform shims so the shared layer compiles on both macOS (AppKit)
//  and iPadOS (UIKit). Each typealias resolves to the native type, so on macOS
//  behaviour is byte-identical to the original AppKit code.

import SwiftUI

#if canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformImage = UIImage
#endif

// MARK: - Find actions

/// Platform-neutral find/replace verbs. The macOS editor maps these to
/// `NSTextFinder.Action`; the iPad editor maps them to `UIFindInteraction`.
enum FindAction {
    case find
    case replace
    case next
    case previous
    case useSelection
}

// MARK: - Small platform helpers

enum Platform {
    /// An audible/haptic "that didn't work" cue.
    static func beep() {
        #if canImport(AppKit)
        NSSound.beep()
        #elseif canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// Put plain text on the system clipboard.
    static func copy(_ text: String) {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    /// Delete a file or folder. macOS moves it to the Trash; iOS (no Trash)
    /// removes it outright — callers confirm first.
    static func delete(at url: URL) {
        #if canImport(AppKit)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        #else
        try? FileManager.default.removeItem(at: url)
        #endif
    }
}

// MARK: - Color helpers shared by the highlighter

/// The handful of semantic colors the Markdown highlighter needs, resolved
/// per platform (UIKit lacks some of AppKit's named colors).
extension PlatformColor {
    static var editorPrimaryText: PlatformColor {
        #if canImport(AppKit)
        return .textColor
        #else
        return .label
        #endif
    }
    static var editorSecondaryText: PlatformColor {
        #if canImport(AppKit)
        return .secondaryLabelColor
        #else
        return .secondaryLabel
        #endif
    }
    static var editorTertiaryText: PlatformColor {
        #if canImport(AppKit)
        return .tertiaryLabelColor
        #else
        return .tertiaryLabel
        #endif
    }
    static var editorLink: PlatformColor {
        #if canImport(AppKit)
        return .linkColor
        #else
        return .link
        #endif
    }
    static var editorSeparator: PlatformColor {
        #if canImport(AppKit)
        return .separatorColor
        #else
        return .separator
        #endif
    }
}

// MARK: - Italic font

extension PlatformFont {
    /// Returns an italic variant of the receiver, cross-platform.
    func italicized() -> PlatformFont {
        #if canImport(AppKit)
        return NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
        #else
        if let descriptor = fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
        #endif
    }
}
