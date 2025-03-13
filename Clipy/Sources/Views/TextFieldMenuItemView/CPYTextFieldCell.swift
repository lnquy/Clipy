// 
//  CPYTextFieldCell.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by LQuy on 13/3/25.
// 
//  Copyright © 2015-2025 Clipy Project.
//

import Cocoa

class CPYTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        // Adjust the rect to remove padding/margin
        var newRect = super.drawingRect(forBounds: rect)
        let padding: CGFloat = 0 // Adjust this value as needed
        newRect.origin.x += padding
        newRect.size.width -= 2 * padding
        return newRect
    }
}
