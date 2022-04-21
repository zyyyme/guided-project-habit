//
//  HomeCollectionViewController.swift
//  Habit Tracker
//
//  Created by Владислав Левченко on 20.04.2022.
//

import UIKit

private let reuseIdentifier = "Cell"

class HomeCollectionViewController: UICollectionViewController {
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    enum ViewModel {
        enum Section: Equatable, Hashable {
            case leaderboard
            case followedUsers
        }
        
        enum Item: Equatable, Hashable {
            case leaderboardHabit(name: String, leadingUserRanking: String?, secondaryUserRanking: String?)
            case followedUser(_ user: User, message: String)
        }
    }
    
    struct Model {
        var usersByID = [String: User]()
        var habitsByName = [String: Habit]()
        var habitStatistics = [HabitStatistics]()
        var userStatistsics = [UserStatistics]()
        
        var currentUser: User {
            return Settings.shared.currentUser
        }
        
        var users: [User] {
            return Array(usersByID.values)
        }
        
        var habits: [Habit] {
            return Array(habitsByName.values)
        }
        
        var followedUsers: [User] {
            return Array(usersByID.filter { Settings.shared.followedUserIDs.contains($0.key)}.values)
        }
        
        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }
        
        var nonFavoriteHabits: [Habit] {
            return habits.filter { !favoriteHabits.contains($0)}
        }
    }
    
    var model = Model()
    var dataSource: DataSourceType!
    var updateTimer: Timer?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        update()
    
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.update()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func update() {
        CombinedStatisticsRequest().send { result in
            switch result {
            case .success(let combinedStatistics):
                self.model.userStatistsics = combinedStatistics.userStatistics
                self.model.habitStatistics = combinedStatistics.habitStatistics
            case .failure:
                self.model.userStatistsics = []
                self.model.habitStatistics = []
            }
    
            DispatchQueue.main.async {
                self.updateCollectionView()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        UserRequest().send { result in
            switch result {
            case .success(let users):
                self.model.usersByID = users
            case .failure:
                break;
            }
        
            DispatchQueue.main.async {
                self.updateCollectionView()
            }
        }
        
        HabitRequest().send { result in
            switch result {
            case .success(let habits):
                self.model.habitsByName = habits
            case .failure:
                break;
            }
        
            DispatchQueue.main.async {
                self.updateCollectionView()
            }
        }
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
    }
    
    func updateCollectionView() {
        var sectionIDs = [ViewModel.Section]()
        
        let leaderboardItems = model.habitStatistics.filter { statistic in
            return model.favoriteHabits.contains { $0.name == statistic.habit.name}
            }.sorted {
                $0.habit.name < $1.habit.name }.reduce(into: [ViewModel.Item]()) { partial, statistic in
                    let rankedUserCounts = statistic.userCounts.sorted { $0.count > $1.count }
                    
                    let myCountIndex = rankedUserCounts.firstIndex { $0.user.id == self.model.currentUser.id }
                    
                    func userRankingString(from userCount: UserCount) -> String {
                        var name = userCount.user.name
                        var ranking = ""
                        
                        if userCount.user.id == self.model.currentUser.id {
                            name = "You"
                            ranking = " (\(ordinalString(from: myCountIndex!)))"
                        }
                        return "\(name) \(userCount.count)" + ranking
                    }
                    
                    var leadingRanking: String?
                    var secondaryRanking: String?
                    
                    switch rankedUserCounts.count {
                    case 0:
                        leadingRanking = "Nobody yet."
                    case 1:
                        let onlyCount = rankedUserCounts.first!
                        leadingRanking = userRankingString(from: onlyCount)
                    default:
                        leadingRanking = userRankingString(from: rankedUserCounts[0])
                        if let myCountIndex = myCountIndex, myCountIndex != rankedUserCounts.startIndex {
                            secondaryRanking = userRankingString(from: rankedUserCounts[myCountIndex])
                        } else {
                            secondaryRanking = userRankingString(from: rankedUserCounts[1])
                        }
                    }
                    
                    let leaderboardItem = ViewModel.Item.leaderboardHabit(name: statistic.habit.name, leadingUserRanking: leadingRanking, secondaryUserRanking: secondaryRanking)
                    
                    partial.append(leaderboardItem)
            }
        
        sectionIDs.append(.leaderboard)
        
        var itemsBySection = [ViewModel.Section.leaderboard: leaderboardItems]
        var followedUserItems = [ViewModel.Item]()
        
        func loggedHabitNames(for user: User) -> Set<String> {
            var names = [String]()
            
            if let stats = model.userStatistsics.first(where: {$0.user == user}) {
                names = stats.habitCounts.map {$0.habit.name}
            }
            return Set(names)
        }
        
        let currentUserLoggedHabits = loggedHabitNames(for: model.currentUser)
        let favoriteLoggedHabits = Set(model.favoriteHabits.map {$0.name}).intersection(currentUserLoggedHabits)
        
        for followedUser in model.followedUsers.sorted(by: {$0.name < $1.name}) {
            let message: String
            let followedUserLoggedHabits = loggedHabitNames(for: followedUser)
            
            let commonLoggedHabits = followedUserLoggedHabits.intersection(currentUserLoggedHabits)
            
            if commonLoggedHabits.count > 0 {
                let habitName: String
                let commonFavoriteLoggedHabits = favoriteLoggedHabits.intersection(commonLoggedHabits)
                
                if commonFavoriteLoggedHabits.count > 0 {
                    habitName = commonFavoriteLoggedHabits.sorted().first!
                } else {
                    habitName = commonLoggedHabits.sorted().first!
                }
                
                let habitStats = model.habitStatistics.first { $0.habit.name == habitName }!
                
                let rankedUserCounts = habitStats.userCounts.sorted {$0.count > $1.count}
                let currentUserRanking = rankedUserCounts.firstIndex {$0.user == model.currentUser}!
                let followedUserRanking = rankedUserCounts.firstIndex { $0.user == followedUser}!
                
                if currentUserRanking < followedUserRanking {
                    message = "Currently #\(ordinalString(from:followedUserRanking)), behind you (#\(ordinalString(from:currentUserRanking))) in \(habitName).\nSend them a friendly reminder!"
                } else if currentUserRanking > followedUserRanking {
                    message = "Currently #\(ordinalString(from:followedUserRanking)), ahead of you (#\(ordinalString(from:currentUserRanking))) in \(habitName).\nYou might catch up with a little extra effort!"
                } else {
                    message = "You're tied at \(ordinalString(from:followedUserRanking)) in \(habitName)! Now's your chance to pull ahead."
                }
            } else if followedUserLoggedHabits.count > 0 {
                let habitName = followedUserLoggedHabits.sorted().first!
                
                let habitStats = model.habitStatistics.first {$0.habit.name == habitName}!
                
                let rankedUserCounts = habitStats.userCounts.sorted {$0.count > $1.count}
                let followedUserRanking = rankedUserCounts.firstIndex {$0.user == followedUser}!
                
                message = "Currently #\(ordinalString(from: followedUserRanking)), in \(habitName).\nMaybe you should give this habit a look."
            } else {
                message = "This user doesn't seem to have done much yet. Check in to see if they need any help getting started"
            }
            
            followedUserItems.append(.followedUser(followedUser, message:message))
        }
        sectionIDs.append(.followedUsers)
        itemsBySection[.followedUsers] = followedUserItems
        
        dataSource.applySnapshotUseing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            switch item {
            case .leaderboardHabit(let name, let leadingUserRanking, let secondaryUserRanking):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LeaderboardHabit", for: indexPath) as! LeaderboardHabitCollectionViewCell
                cell.habitNameLabel.text = name
                cell.leaderLabel.text = leadingUserRanking
                cell.secondaryLabel.text = secondaryUserRanking
                return cell
            case .followedUser(let user, let message):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FollowedUser", for: indexPath) as! PrimarySecondaryTextCollectionViewCell
                cell.primaryTextLabel.text = user.name
                cell.secondaryTextLabel.text = message
                return cell                
            }
        }
        
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex,
           environment) -> NSCollectionLayoutSection? in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .leaderboard:
                let leaderboardItemSize =
                   NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                   heightDimension: .fractionalHeight(0.3))
                let leaderboardItem = NSCollectionLayoutItem(layoutSize:
                   leaderboardItemSize)
    
                let verticalTrioSize = NSCollectionLayoutSize(widthDimension:
                   .fractionalWidth(0.75), heightDimension:
                   .fractionalWidth(0.75))
                let leaderboardVerticalTrio =
                   NSCollectionLayoutGroup.vertical(layoutSize:
                   verticalTrioSize, subitem: leaderboardItem, count: 3)
    
                let leaderboardSection = NSCollectionLayoutSection(group:
                   leaderboardVerticalTrio)
                leaderboardSection.interGroupSpacing = 20
                leaderboardSection.contentInsets =
                   NSDirectionalEdgeInsets(top: 20, leading: 0,
                   bottom: 0, trailing: 0)
    
                leaderboardSection.orthogonalScrollingBehavior =
                  .groupPagingCentered
                leaderboardSection.contentInsets =
                   NSDirectionalEdgeInsets(top: 12, leading: 0,
                   bottom: 20, trailing: 0)
                return leaderboardSection
            case .followedUsers:
                let itemSize = NSCollectionLayoutSize(widthDimension:
                   .fractionalWidth(1), heightDimension: .estimated(100))
                let followedUserItem = NSCollectionLayoutItem(layoutSize: itemSize)
            
                let groupSize = NSCollectionLayoutSize(widthDimension:
                   .fractionalWidth(1), heightDimension: .estimated(100))
                let followedUserGroup =
                   NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                   subitem: followedUserItem, count: 1)
            
                let followedUserSection = NSCollectionLayoutSection(group:
                   followedUserGroup)
            
                return followedUserSection
            default:
                return nil
            }
        }
        return layout
    }
    
    static let formatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()
    
    func ordinalString(from number: Int) -> String {
        return Self.formatter.string(from: NSNumber(integerLiteral: number + 1))!
    }
}
