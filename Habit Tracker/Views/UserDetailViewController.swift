//
//  UserDetailViewController.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 20.04.2022.
//

import UIKit

class UserDetailViewController: UIViewController {

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    
    var user: User!
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case leading
            case category(_ category: Category)
            
            static func < (lhs: Section, rhs: Section) -> Bool {
                switch (lhs, rhs) {
                case (.leading, .category) , (.leading, .leading):
                    return true
                case (.category, .leading):
                    return false
                case (.category(let category1), .category(let category2)):
                    return category1.name > category2.name
                }
            }
        }
        
        typealias Item = HabitCount
    }
    
    struct Model {
        var userStats: UserStatistics?
        var leadingStats: UserStatistics?
    }
    
    var dataSource: DataSourceType!
    var model = Model()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userNameLabel.text = user.name
        bioLabel.text = user.bio
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: "header", withReuseIdentifier: "HeaderView")
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        update()
        
        ImageRequest(imageID: user.id).send { result in
            switch result {
            case .success(let image):
                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            default:
                break
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("!!!")
    }
    
    init? (coder: NSCoder, user: User) {
        self.user = user
        super.init(coder: coder)
    }
    
    
    func update() {
        UserStatisticsRequest(userIDs: [user.id]).send { result in
            switch result {
            case .success(let userStats):
                self.model.userStats = userStats[0]
            case .failure:
                self.model.userStats = nil
            }
            
            DispatchQueue.main.async {
                self.updateCollectionView()
            }
        }
        
        HabitLeadStatisticsRequest(userID: user.id).send { result in
            switch result {
            case .success(let userStats):
                self.model.leadingStats = userStats
            case .failure:
                self.model.leadingStats = nil
            }
            
            DispatchQueue.main.async {
                self.updateCollectionView()
            }
        }
    }
    
    func updateCollectionView() {
        guard let userStatistics = model.userStats, let leadingStatistics = model.leadingStats else { return }
        
        var itemsBySection = userStatistics.habitCounts.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, habitCount in
            let section: ViewModel.Section
            
            if leadingStatistics.habitCounts.contains(habitCount) {
                section = .leading
            } else {
                section = .category(habitCount.habit.category)
            }
            
            partial[section, default: []].append(habitCount)
        }
        
        itemsBySection = itemsBySection.mapValues { $0.sorted()}
        
        let sectionIDs = itemsBySection.keys.sorted()
        
        dataSource.applySnapshotUseing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { (collectionView, indexPath, habitStat) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HabitCount", for: indexPath) as! PrimarySecondaryTextCollectionViewCell
            
            cell.primaryTextLabel.text = habitStat.habit.name
            cell.secondaryTextLabel.text = "\(habitStat.count)"
            
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, category, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: "header", withReuseIdentifier: "HeaderView", for: indexPath) as! NamedSectionHeaderView
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            
            switch section {
            case .leading:
                header.nameLabel.text = "Leading"
            case .category(let category):
                header.nameLabel.text = category.name
            }
            
            return header
        }
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize =
           NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
           heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    
        let groupSize = NSCollectionLayoutSize(widthDimension:
           .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize:
           groupSize, subitem: item, count: 1)
    
        let headerSize = NSCollectionLayoutSize(widthDimension:
           .fractionalWidth(1), heightDimension: .absolute(36))
        let sectionHeader =
           NSCollectionLayoutBoundarySupplementaryItem(layoutSize:
           headerSize, elementKind: "header", alignment: .top)
        sectionHeader.pinToVisibleBounds = true

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20,
           leading: 0, bottom: 20, trailing: 0)
        section.boundarySupplementaryItems = [sectionHeader]
        return UICollectionViewCompositionalLayout(section: section)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
