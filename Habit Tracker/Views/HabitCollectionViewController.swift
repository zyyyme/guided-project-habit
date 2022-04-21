//
//  HabitCollectionViewController.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 20.04.2022.
//

import UIKit

private let reuseIdentifier = "Cell"
private let sectionHeaderKind = "SectionHeader"
private let sectionHeaderIdentifier = "HeaderView"

class HabitCollectionViewController: UICollectionViewController {
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    enum ViewModel {
        enum Section: Hashable, Equatable, Comparable {
            case favorites
            case category (_ category: Category)
            
            static func < (lhs: Section, rhs: Section) -> Bool {
                switch (lhs, rhs) {
                case (.category(let l), .category(let r)):
                    return l.name < r.name
                case (.favorites, _):
                    return true
                case (_, .favorites):
                    return false
                }
            }
        }
        
        struct Item: Hashable, Equatable, Comparable {
            let habit: Habit
            let isFavorite: Bool
            
            static func < (lhs: Item, rhs: Item) -> Bool {
                return lhs.habit < rhs.habit
            }
        }
    }
    
    struct Model {
        var habitsByName = [String: Habit]()
        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }
    }
    
    var dataSource: DataSourceType!
    var model = Model()
    
    
    override func viewDidLoad() {
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: sectionHeaderKind, withReuseIdentifier: sectionHeaderIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        update()
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let item = self.dataSource.itemIdentifier(for: indexPath)!
            
            let favoriteToggle = UIAction(title: item.isFavorite ? "Unfavorite" : "Favorite") { (action) in
                Settings.shared.toggleFavorite(item.habit)
                self.updateCollectionView()
            }
            return UIMenu(title: "", image: nil, identifier: nil, options: [], children: [favoriteToggle])
        }
        return config
    }
    
    func update() {
        HabitRequest().send { result in
            switch result {
            case .success(let habits):
                self.model.habitsByName = habits
            case .failure:
                self.model.habitsByName = [:]
            }
            
            DispatchQueue.main.async {
                self.updateCollectionView()
            }
        }
    }
    
    func updateCollectionView() {
        var itemsBySection = model.habitsByName.values.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, habit in
            let section: ViewModel.Section
            let item: ViewModel.Item
            
            if model.favoriteHabits.contains(habit) {
                section = .favorites
                item = ViewModel.Item(habit: habit, isFavorite: true)
            } else {
                section = .category(habit.category)
                item = ViewModel.Item(habit: habit, isFavorite: false)
            }
            
            partial[section, default: []].append(item)
        }
        
        itemsBySection = itemsBySection.mapValues { $0.sorted() }
        let sectionIDs = itemsBySection.keys.sorted()
        dataSource.applySnapshotUseing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { (collectionView, indexPath, item) in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Habit", for: indexPath) as! PrimarySecondaryTextCollectionViewCell
            
            cell.primaryTextLabel.text = item.habit.name
            
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, kind, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: sectionHeaderKind, withReuseIdentifier: sectionHeaderIdentifier, for: indexPath) as! NamedSectionHeaderView
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            
            switch section {
            case .favorites:
                header.nameLabel.text = "Favorites"
            case .category(let category):
                header.nameLabel.text = category.name
            }
            return header
        }
        
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: sectionHeaderKind, alignment: .top)
        sectionHeader.pinToVisibleBounds = true
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        section.boundarySupplementaryItems = [sectionHeader]
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    
    @IBSegueAction func showHabitDetail(_ coder: NSCoder, sender: UICollectionViewCell?) -> HabitDetailViewController? {
        guard let cell = sender, let indexPath = collectionView.indexPath(for: cell), let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        
        return HabitDetailViewController(coder: coder, habit: item.habit)
    }
}
