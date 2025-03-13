//
//  CustomMenuItem.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by LQuy on 10/3/25.
//
//  Copyright © 2015-2025 Clipy Project.
//

import Cocoa

class CPYMenuItemView: NSMenuItem {
    var searchTextField: NSTextField!

    override init(
        title string: String, action selector: Selector?,
        keyEquivalent charCode: String
    ) {
        super.init(title: string, action: selector, keyEquivalent: charCode)
        self.setupMenuItem()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.setupMenuItem()
    }

    private func setupMenuItem() {
    }
}
