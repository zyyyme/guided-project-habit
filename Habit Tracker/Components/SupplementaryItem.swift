//
//  SupplementaryItem.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 21.04.2022.
//

import Foundation
import UIKit

enum SupplementaryItemType {
    case collectionSupplementaryItem
    case layoutDecorationView
}

protocol SupplementaryView {
    associatedtype ViewClass: UICollectionReusableView
    
    var itemType: SupplementaryItemType { get }
    
//    var reuseIdentifier: String
}
