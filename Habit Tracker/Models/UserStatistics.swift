//
//  UserStatistics.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 21.04.2022.
//

import Foundation

struct UserStatistics {
    let user: User
    let habitCounts: [HabitCount]
}

extension UserStatistics: Codable { }
