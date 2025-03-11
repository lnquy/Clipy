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

class CPYTextFieldMenuItem: NSMenuItem {
    var searchTextField: NSTextField!

    override init(
        title string: String, action selector: Selector?,
        keyEquivalent charCode: String
    ) {
        super.init(title: string, action: selector, keyEquivalent: charCode)
        setupSearchTextField()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupSearchTextField()
    }

    private func setupSearchTextField() {
        searchTextField = NSTextField()
        //        searchTextField.isSelectable = true
        //        searchTextField.isEditable = true
        searchTextField.placeholderString = "Type to search..."
        searchTextField.target = self
        searchTextField.delegate = self
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        //        searchTextField.refusesFirstResponder = true
        //        searchTextField.resignFirstResponder()
        // searchTextField.becomeFirstResponder() // Force caret blinker
        self.view = searchTextField

        // Add constraints to make the text field full width and line height
        if let view = self.view {
            NSLayoutConstraint.activate([
                searchTextField.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor),
                searchTextField.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor),
                searchTextField.topAnchor.constraint(equalTo: view.topAnchor),
                searchTextField.bottomAnchor.constraint(
                    equalTo: view.bottomAnchor),
                searchTextField.heightAnchor
                    .constraint(greaterThanOrEqualToConstant: 35),
            ])
            searchTextField.usesSingleLineMode = false
            searchTextField.maximumNumberOfLines = 5
        }
    }
}

extension CPYTextFieldMenuItem: NSTextFieldDelegate {
    func control(
        _ control: NSControl, textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            // Try to loose focus on search bar, may remove later
            searchTextField.resignFirstResponder()
            searchTextField.refusesFirstResponder = true
            searchTextField.setAccessibilityFocused(false)

            if let menu = self.menu, menu.numberOfItems > 2 {
                let menuItem = menu.item(at: 2)
                menuItem?.isEnabled = true
                menuItem?.setAccessibilityFocused(true)
                return true
            }
        case #selector(NSResponder.moveUp(_:)):
            // TODO[q]: No effect. Improve or remove this later
            // print("UP")
            if let menu = self.menu, menu.numberOfItems > 2 {
                let menuItem = menu.item(at: 2)
                if let highligted = menuItem?.isHighlighted {
                    // print("CHANGE FOCUS")
                    menuItem?.setAccessibilityFocused(false)
                    searchTextField.refusesFirstResponder = false
                    searchTextField.setAccessibilityFocused(true)
                    return true
                }
            }
        default:
            return false
        }

        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let searchText = textField.stringValue
        NotificationCenter.default.post(
            Notification(
                name:
                    Notification.Name(
                        rawValue: Constants.Notification.searchTextUpdated),
                object: searchText
            )
        )
    }
}
