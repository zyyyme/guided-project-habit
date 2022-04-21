//
//  Category.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 20.04.2022.
//

import Foundation

struct Category {
    let name: String
    let color: Color 
}

extension Category: Codable { }


extension Category: Hashable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        return lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
