//
//  LoggedHabit.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 21.04.2022.
//

import Foundation

struct LoggedHabit {
    let userID: String
    let habitName: String
    let timestamp: Date
}

extension LoggedHabit: Codable { }
