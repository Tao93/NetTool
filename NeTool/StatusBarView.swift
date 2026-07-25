//
//  StatusBarView.swift
//  NeTool
//

import AppKit

/// Manages the menu bar status item display and menu interaction.
/// Renders two-line speed text into an NSImage for the status bar button.
class StatusBarView: NSObject {
    static let initialRateText = "- - B/S"

    private let statusItem: NSStatusItem
    private(set) var isMenuOpen = false
    var speedMonitor: NetSpeedMonitor?

    init(statusItem: NSStatusItem, menu: NSMenu) {
        self.statusItem = statusItem
        super.init()
        statusItem.menu = menu
        menu.delegate = self
        updateButtonImage(up: Self.initialRateText, down: Self.initialRateText)
    }

    func updateData(up: String, down: String) {
        DispatchQueue.main.async {
            self.updateButtonImage(up: up, down: down)
        }
    }

    /// Render ▲up and ▼down as a two-line NSImage for the status bar button.
    private func updateButtonImage(up: String, down: String) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

        // Pick high-contrast text color based on menu bar appearance.
        // isTemplate gives a washed-out look on some macOS versions, so we
        // draw with explicit black/white instead.
        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor: NSColor = isDark ? .white : .black

        let upAttr = NSAttributedString(string: "\(up) ▲", attributes: [.font: font, .foregroundColor: textColor])
        let downAttr = NSAttributedString(string: "\(down) ▼", attributes: [.font: font, .foregroundColor: textColor])

        let upSize = upAttr.size()
        let downSize = downAttr.size()

        // Use a reference string to establish a stable minimum width so that
        // changing digits don't make the menu bar icon jump horizontally.
        let refAttr = NSAttributedString(string: "888.8 M/S ▲", attributes: [.font: font])
        let minWidth = refAttr.size().width

        let width = max(minWidth, upSize.width, downSize.width)
        let height = upSize.height + downSize.height

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        // Right-align: draw from the right edge so number changes only expand leftward.
        upAttr.draw(at: NSPoint(x: width - upSize.width, y: downSize.height))
        downAttr.draw(at: NSPoint(x: width - downSize.width, y: 0))
        image.unlockFocus()

        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
    }
}

// MARK: - NSMenuDelegate
extension StatusBarView: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        // Fetch latest top-speed data so the dropdown is populated immediately
        DispatchQueue.global().async {
            self.speedMonitor?.updateTopSpeedItems()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }
}

