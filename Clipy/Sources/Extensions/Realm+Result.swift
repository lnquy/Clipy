// 
//  Realm+Result.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by LQuy on 11/3/25.
// 
//  Copyright © 2015-2025 Clipy Project.
//

import Foundation
import RealmSwift

extension Results {
    func toArray<T>(type: T.Type, limit: Int = Int.max) -> [T] {
        return self.lazy.compactMap { $0 as? T }
            .prefix(limit)
            .map { $0 }
    }
}
