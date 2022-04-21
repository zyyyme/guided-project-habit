//
//  UserCount.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 21.04.2022.
//

import Foundation


struct UserCount {
    let user: User
    let count: Int
}

extension UserCount: Codable { }

extension UserCount: Hashable { }
