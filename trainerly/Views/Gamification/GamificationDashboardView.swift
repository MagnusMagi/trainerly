import SwiftUI
import Combine

// MARK: - Gamification Dashboard View
struct GamificationDashboardView: View {
    @StateObject private var viewModel = GamificationDashboardViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with XP and Level
                headerSection
                
                // Tab Selection
                tabSelection
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    // Progress Tab
                    progressTab
                        .tag(0)
                    
                    // Achievements Tab
                    achievementsTab
                        .tag(1)
                    
                    // Leaderboard Tab
                    leaderboardTab
                        .tag(2)
                    
                    // Social Tab
                    socialTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Gamification")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: refreshButton)
            .onAppear {
                viewModel.loadData()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // XP Progress Bar
            VStack(spacing: 12) {
                HStack {
                    Text("Level \(viewModel.currentLevel.rawValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(viewModel.currentXP) XP")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: viewModel.levelProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text("\(viewModel.xpToNextLevel) XP to next level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            // Quick Stats
            HStack(spacing: 20) {
                StatCard(
                    title: "Streak",
                    value: "\(viewModel.currentStreak)",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Rank",
                    value: viewModel.currentRank.rawValue,
                    icon: "trophy.fill",
                    color: .yellow
                )
                
                StatCard(
                    title: "Achievements",
                    value: "\(viewModel.achievementsCount)",
                    icon: "star.fill",
                    color: .purple
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Tab Selection
    private var tabSelection: some View {
        HStack(spacing: 0) {
            ForEach(["Progress", "Achievements", "Leaderboard", "Social"], id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = ["Progress", "Achievements", "Leaderboard", "Social"].firstIndex(of: tab) ?? 0
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == ["Progress", "Achievements", "Leaderboard", "Social"].firstIndex(of: tab) ? .blue : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == ["Progress", "Achievements", "Leaderboard", "Social"].firstIndex(of: tab) ? Color.blue : Color.clear)
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Progress Tab
    private var progressTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Weekly Goals
                weeklyGoalsSection
                
                // Recent Activity
                recentActivitySection
                
                // Milestones
                milestonesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Achievements Tab
    private var achievementsTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Achievement Categories
                achievementCategoriesSection
                
                // Recent Achievements
                recentAchievementsSection
                
                // Upcoming Achievements
                upcomingAchievementsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Leaderboard Tab
    private var leaderboardTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Leaderboard Scope Selector
                leaderboardScopeSelector
                
                // Leaderboard Entries
                leaderboardEntriesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Social Tab
    private var socialTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Friends
                friendsSection
                
                // Groups
                groupsSection
                
                // Challenges
                challengesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Weekly Goals Section
    private var weeklyGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Goals")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Add Goal") {
                    viewModel.addWeeklyGoal()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.weeklyGoals) { goal in
                    WeeklyGoalCard(goal: goal) { updatedGoal in
                        viewModel.updateWeeklyGoal(updatedGoal)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.recentActivities) { activity in
                    ActivityCard(activity: activity)
                }
            }
        }
    }
    
    // MARK: - Milestones Section
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Milestones")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.milestones) { milestone in
                    MilestoneCard(milestone: milestone)
                }
            }
        }
    }
    
    // MARK: - Achievement Categories Section
    private var achievementCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievement Categories")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    AchievementCategoryCard(
                        category: category,
                        progress: viewModel.achievementProgress(for: category)
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Achievements Section
    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Achievements")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.recentAchievements) { achievement in
                    AchievementCard(achievement: achievement)
                }
            }
        }
    }
    
    // MARK: - Upcoming Achievements Section
    private var upcomingAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Achievements")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.upcomingAchievements) { achievement in
                    UpcomingAchievementCard(achievement: achievement)
                }
            }
        }
    }
    
    // MARK: - Leaderboard Scope Selector
    private var leaderboardScopeSelector: some View {
        HStack(spacing: 12) {
            ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                Button(action: {
                    viewModel.selectedLeaderboardScope = scope
                }) {
                    Text(scope.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedLeaderboardScope == scope ? Color.blue : Color(.systemGray6))
                        .foregroundColor(viewModel.selectedLeaderboardScope == scope ? .white : .primary)
                        .cornerRadius(20)
                }
            }
        }
    }
    
    // MARK: - Leaderboard Entries Section
    private var leaderboardEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Leaderboard")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.leaderboardEntries) { entry in
                    LeaderboardEntryCard(entry: entry)
                }
            }
        }
    }
    
    // MARK: - Friends Section
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Add Friend") {
                    viewModel.addFriend()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.friends) { friend in
                    FriendCard(friend: friend)
                }
            }
        }
    }
    
    // MARK: - Groups Section
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Groups")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Create Group") {
                    viewModel.createGroup()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groups) { group in
                    GroupCard(group: group)
                }
            }
        }
    }
    
    // MARK: - Challenges Section
    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Challenges")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Join Challenge") {
                    viewModel.joinChallenge()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.challenges) { challenge in
                    ChallengeCard(challenge: challenge)
                }
            }
        }
    }
    
    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button(action: {
            viewModel.loadData()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title2)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Weekly Goal Card
struct WeeklyGoalCard: View {
    let goal: WeeklyGoal
    let onUpdate: (WeeklyGoal) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(goal.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: Double(goal.current), total: Double(goal.target))
                    .progressViewStyle(LinearProgressViewStyle(tint: goal.isCompleted ? .green : .blue))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text("\(goal.current)/\(goal.target)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(goal.isCompleted ? .green : .primary)
                
                Text(goal.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Activity Card
struct ActivityCard: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: activity.icon)
                .font(.system(size: 24))
                .foregroundColor(activity.color)
                .frame(width: 40, height: 40)
                .background(activity.color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("+\(activity.xpGained) XP")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Milestone Card
struct MilestoneCard: View {
    let milestone: Milestone
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(milestone.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(milestone.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: milestone.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(milestone.progress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                Text("\(milestone.xpNeeded) XP needed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Achievement Category Card
struct AchievementCategoryCard: View {
    let category: AchievementCategory
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundColor(category.color)
            
            Text(category.rawValue.capitalized)
                .font(.headline)
                .fontWeight(.semibold)
            
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: category.color))
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 16) {
            Text(achievement.icon)
                .font(.system(size: 32))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(achievement.unlockedDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(achievement.xpReward)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Upcoming Achievement Card
struct UpcomingAchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 16) {
            Text(achievement.icon)
                .font(.system(size: 32))
                .frame(width: 40, height: 40)
                .opacity(0.5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Locked")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(achievement.xpReward)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(0.7)
    }
}

// MARK: - Leaderboard Entry Card
struct LeaderboardEntryCard: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("#\(entry.rank)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            // Avatar
            if let avatar = entry.avatar {
                AsyncImage(url: avatar) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(entry.level.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // XP
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.xp)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
}

// MARK: - Friend Card
struct FriendCard: View {
    let friend: User
    
    var body: some View {
        HStack(spacing: 16) {
            if let avatar = friend.profile.avatarURL {
                AsyncImage(url: avatar) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(friend.profile.firstName) \(friend.profile.lastName)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(friend.level.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // Send motivational message
            }) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Group Card
struct GroupCard: View {
    let group: Group
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(group.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(group.members.count)/\(group.maxMembers) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(group.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                if group.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Challenge Card
struct ChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(challenge.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(challenge.participants.count)/\(challenge.maxParticipants) participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(challenge.xpReward)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(challenge.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Types
enum AchievementCategory: String, CaseIterable {
    case workout = "Workout"
    case streak = "Streak"
    case social = "Social"
    case form = "Form"
    
    var icon: String {
        switch self {
        case .workout: return "dumbbell.fill"
        case .streak: return "flame.fill"
        case .social: return "person.2.fill"
        case .form: return "camera.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .workout: return .blue
        case .streak: return .orange
        case .social: return .green
        case .form: return .purple
        }
    }
}

struct Activity: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let xpGained: Int
    let timestamp: Date
}

// MARK: - Preview
struct GamificationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        GamificationDashboardView()
    }
}
