import Foundation
import Combine

// MARK: - Social Features Service Protocol
protocol SocialFeaturesServiceProtocol: ObservableObject {
    var currentUserFriends: [User] { get }
    var currentUserGroups: [Group] { get }
    var currentUserChallenges: [Challenge] { get }
    var socialFeed: [SocialPost] { get }
    
    func addFriend(_ userId: String) async throws
    func removeFriend(_ userId: String) async throws
    func acceptFriendRequest(_ requestId: String) async throws
    func declineFriendRequest(_ requestId: String) async throws
    func getFriendRequests() async throws -> [FriendRequest]
    func createGroup(_ group: Group) async throws
    func joinGroup(_ groupId: String) async throws
    func leaveGroup(_ groupId: String) async throws
    func inviteToGroup(_ groupId: String, userIds: [String]) async throws
    func createSocialPost(_ post: SocialPost) async throws
    func likePost(_ postId: String) async throws
    func commentOnPost(_ postId: String, comment: String) async throws
    func shareWorkout(_ workout: Workout, message: String?) async throws
    func getSocialFeed(scope: SocialFeedScope, limit: Int) async throws -> [SocialPost]
    func getGroupFeed(_ groupId: String, limit: Int) async throws -> [SocialPost]
    func startGroupWorkout(_ groupId: String, workout: Workout) async throws
    func joinGroupWorkout(_ workoutId: String) async throws
    func sendMotivationalMessage(_ userId: String, message: String) async throws
    func getSocialStats(for userId: String) async throws -> SocialStats
}

// MARK: - Social Features Service
final class SocialFeaturesService: NSObject, SocialFeaturesServiceProtocol {
    @Published var currentUserFriends: [User] = []
    @Published var currentUserGroups: [Group] = []
    @Published var currentUserChallenges: [Challenge] = []
    @Published var socialFeed: [SocialPost] = []
    
    private let userRepository: UserRepositoryProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let gamificationService: GamificationServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    private var friendRequests: [FriendRequest] = []
    private var groupInvitations: [GroupInvitation] = []
    
    init(
        userRepository: UserRepositoryProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        gamificationService: GamificationServiceProtocol,
        notificationService: NotificationServiceProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.userRepository = userRepository
        self.workoutRepository = workoutRepository
        self.gamificationService = gamificationService
        self.notificationService = notificationService
        self.cacheService = cacheService
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    func addFriend(_ userId: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Check if already friends
        guard !currentUserFriends.contains(where: { $0.id == userId }) else {
            throw SocialFeaturesError.alreadyFriends
        }
        
        // Check if request already sent
        guard !friendRequests.contains(where: { $0.fromUserId == currentUser.id && $0.toUserId == userId }) else {
            throw SocialFeaturesError.requestAlreadySent
        }
        
        // Create friend request
        let request = FriendRequest(
            id: UUID().uuidString,
            fromUserId: currentUser.id,
            toUserId: userId,
            status: .pending,
            createdAt: Date()
        )
        
        try await userRepository.createFriendRequest(request)
        friendRequests.append(request)
        
        // Send notification to recipient
        try await notificationService.sendNotification(
            to: userId,
            title: "New Friend Request",
            body: "\(currentUser.profile.firstName) wants to be your friend on Trainerly!",
            type: .friendRequest
        )
    }
    
    func removeFriend(_ userId: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Remove from friends list
        try await userRepository.removeFriend(userId, from: currentUser.id)
        
        // Update local state
        currentUserFriends.removeAll { $0.id == userId }
        
        // Award XP for social interaction
        try await gamificationService.awardXP(10, for: .socialInteraction, userId: currentUser.id)
    }
    
    func acceptFriendRequest(_ requestId: String) async throws {
        let request = try await userRepository.getFriendRequest(id: requestId)
        let currentUser = try await userRepository.getCurrentUser()
        
        guard request.toUserId == currentUser.id else {
            throw SocialFeaturesError.unauthorized
        }
        
        // Accept the request
        try await userRepository.updateFriendRequest(requestId, status: .accepted)
        
        // Add to friends list
        let friend = try await userRepository.getUser(id: request.fromUserId)
        currentUserFriends.append(friend)
        
        // Award XP to both users
        try await gamificationService.awardXP(25, for: .socialInteraction, userId: currentUser.id)
        try await gamificationService.awardXP(25, for: .socialInteraction, userId: friend.id)
        
        // Send notification to requester
        try await notificationService.sendNotification(
            to: request.fromUserId,
            title: "Friend Request Accepted",
            body: "\(currentUser.profile.firstName) accepted your friend request!",
            type: .friendRequestAccepted
        )
        
        // Remove from pending requests
        friendRequests.removeAll { $0.id == requestId }
    }
    
    func declineFriendRequest(_ requestId: String) async throws {
        let request = try await userRepository.getFriendRequest(id: requestId)
        let currentUser = try await userRepository.getCurrentUser()
        
        guard request.toUserId == currentUser.id else {
            throw SocialFeaturesError.unauthorized
        }
        
        // Decline the request
        try await userRepository.updateFriendRequest(requestId, status: .declined)
        
        // Remove from pending requests
        friendRequests.removeAll { $0.id == requestId }
        
        // Send notification to requester
        try await notificationService.sendNotification(
            to: request.fromUserId,
            title: "Friend Request Declined",
            body: "\(currentUser.profile.firstName) declined your friend request.",
            type: .friendRequestDeclined
        )
    }
    
    func getFriendRequests() async throws -> [FriendRequest] {
        let currentUser = try await userRepository.getCurrentUser()
        let requests = try await userRepository.getFriendRequests(for: currentUser.id)
        friendRequests = requests
        return requests
    }
    
    func createGroup(_ group: Group) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Validate group
        guard group.members.count <= group.maxMembers else {
            throw SocialFeaturesError.groupFull
        }
        
        // Create the group
        try await userRepository.createGroup(group)
        
        // Add creator as admin
        try await userRepository.addGroupMember(group.id, userId: currentUser.id, role: .admin)
        
        // Update local state
        currentUserGroups.append(group)
        
        // Award XP for creating a group
        try await gamificationService.awardXP(50, for: .socialInteraction, userId: currentUser.id)
    }
    
    func joinGroup(_ groupId: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        let group = try await userRepository.getGroup(id: groupId)
        
        guard group.members.count < group.maxMembers else {
            throw SocialFeaturesError.groupFull
        }
        
        guard !group.members.contains(currentUser.id) else {
            throw SocialFeaturesError.alreadyInGroup
        }
        
        // Join the group
        try await userRepository.addGroupMember(groupId, userId: currentUser.id, role: .member)
        
        // Update local state
        if let updatedGroup = currentUserGroups.first(where: { $0.id == groupId }) {
            var newGroup = updatedGroup
            newGroup.members.append(currentUser.id)
            if let index = currentUserGroups.firstIndex(where: { $0.id == groupId }) {
                currentUserGroups[index] = newGroup
            }
        }
        
        // Award XP for joining
        try await gamificationService.awardXP(25, for: .socialInteraction, userId: currentUser.id)
        
        // Notify group members
        for memberId in group.members {
            if memberId != currentUser.id {
                try await notificationService.sendNotification(
                    to: memberId,
                    title: "New Group Member",
                    body: "\(currentUser.profile.firstName) joined \(group.name)!",
                    type: .groupUpdate
                )
            }
        }
    }
    
    func leaveGroup(_ groupId: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Leave the group
        try await userRepository.removeGroupMember(groupId, userId: currentUser.id)
        
        // Update local state
        currentUserGroups.removeAll { $0.id == groupId }
        
        // Notify remaining group members
        let group = try await userRepository.getGroup(id: groupId)
        for memberId in group.members {
            if memberId != currentUser.id {
                try await notificationService.sendNotification(
                    to: memberId,
                    title: "Group Member Left",
                    body: "\(currentUser.profile.firstName) left \(group.name).",
                    type: .groupUpdate
                )
            }
        }
    }
    
    func inviteToGroup(_ groupId: String, userIds: [String]) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        let group = try await userRepository.getGroup(id: groupId)
        
        // Check if current user is admin
        guard group.members.contains(currentUser.id) else {
            throw SocialFeaturesError.notGroupMember
        }
        
        for userId in userIds {
            // Create invitation
            let invitation = GroupInvitation(
                id: UUID().uuidString,
                groupId: groupId,
                fromUserId: currentUser.id,
                toUserId: userId,
                status: .pending,
                createdAt: Date()
            )
            
            try await userRepository.createGroupInvitation(invitation)
            groupInvitations.append(invitation)
            
            // Send notification
            try await notificationService.sendNotification(
                to: userId,
                title: "Group Invitation",
                body: "\(currentUser.profile.firstName) invited you to join \(group.name)!",
                type: .groupInvitation
            )
        }
    }
    
    func createSocialPost(_ post: SocialPost) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Create the post
        try await userRepository.createSocialPost(post)
        
        // Update local feed
        socialFeed.insert(post, at: 0)
        
        // Award XP for social interaction
        try await gamificationService.awardXP(15, for: .socialInteraction, userId: currentUser.id)
        
        // Notify friends
        for friend in currentUserFriends {
            try await notificationService.sendNotification(
                to: friend.id,
                title: "New Post from \(currentUser.profile.firstName)",
                body: "Check out their latest update!",
                type: .socialUpdate
            )
        }
    }
    
    func likePost(_ postId: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Add like
        try await userRepository.likePost(postId, userId: currentUser.id)
        
        // Update local state
        if let index = socialFeed.firstIndex(where: { $0.id == postId }) {
            var post = socialFeed[index]
            if !post.likes.contains(currentUser.id) {
                post.likes.append(currentUser.id)
                socialFeed[index] = post
            }
        }
        
        // Award XP for social interaction
        try await gamificationService.awardXP(5, for: .socialInteraction, userId: currentUser.id)
        
        // Notify post author
        let post = try await userRepository.getSocialPost(id: postId)
        if post.authorId != currentUser.id {
            try await notificationService.sendNotification(
                to: post.authorId,
                title: "New Like",
                body: "\(currentUser.profile.firstName) liked your post!",
                type: .socialInteraction
            )
        }
    }
    
    func commentOnPost(_ postId: String, comment: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Create comment
        let socialComment = SocialComment(
            id: UUID().uuidString,
            postId: postId,
            authorId: currentUser.id,
            authorName: currentUser.profile.firstName + " " + currentUser.profile.lastName,
            content: comment,
            createdAt: Date()
        )
        
        try await userRepository.addComment(socialComment, to: postId)
        
        // Update local state
        if let index = socialFeed.firstIndex(where: { $0.id == postId }) {
            var post = socialFeed[index]
            post.comments.append(socialComment)
            socialFeed[index] = post
        }
        
        // Award XP for social interaction
        try await gamificationService.awardXP(10, for: .socialInteraction, userId: currentUser.id)
        
        // Notify post author
        let post = try await userRepository.getSocialPost(id: postId)
        if post.authorId != currentUser.id {
            try await notificationService.sendNotification(
                to: post.authorId,
                title: "New Comment",
                body: "\(currentUser.profile.firstName) commented on your post!",
                type: .socialInteraction
            )
        }
    }
    
    func shareWorkout(_ workout: Workout, message: String?) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Create social post for workout
        let post = SocialPost(
            id: UUID().uuidString,
            authorId: currentUser.id,
            authorName: currentUser.profile.firstName + " " + currentUser.profile.lastName,
            authorAvatar: currentUser.profile.avatarURL,
            type: .workout,
            content: message ?? "Just completed a workout! 💪",
            workout: workout,
            imageURL: nil,
            likes: [],
            comments: [],
            createdAt: Date()
        )
        
        try await createSocialPost(post)
        
        // Award bonus XP for sharing workout
        try await gamificationService.awardXP(25, for: .socialInteraction, userId: currentUser.id)
    }
    
    func getSocialFeed(scope: SocialFeedScope, limit: Int) async throws -> [SocialPost] {
        let cacheKey = "social_feed_\(scope.rawValue)_\(limit)"
        
        // Check cache first
        if let cached = cacheService.get(key: cacheKey) as? [SocialPost] {
            return cached
        }
        
        let posts: [SocialPost]
        
        switch scope {
        case .global:
            posts = try await userRepository.getGlobalSocialFeed(limit: limit)
        case .friends:
            posts = try await userRepository.getFriendsSocialFeed(limit: limit)
        case .group(let groupId):
            posts = try await userRepository.getGroupSocialFeed(groupId: groupId, limit: limit)
        }
        
        // Cache the result
        cacheService.set(posts, for: cacheKey, expiration: 300) // 5 minutes
        
        // Update local state
        if scope == .friends {
            socialFeed = posts
        }
        
        return posts
    }
    
    func getGroupFeed(_ groupId: String, limit: Int) async throws -> [SocialPost] {
        return try await getSocialFeed(scope: .group(groupId), limit: limit)
    }
    
    func startGroupWorkout(_ groupId: String, workout: Workout) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        let group = try await userRepository.getGroup(id: groupId)
        
        // Check if user is group member
        guard group.members.contains(currentUser.id) else {
            throw SocialFeaturesError.notGroupMember
        }
        
        // Create group workout
        let groupWorkout = GroupWorkout(
            id: UUID().uuidString,
            groupId: groupId,
            workout: workout,
            startedBy: currentUser.id,
            participants: [currentUser.id],
            status: .active,
            startTime: Date()
        )
        
        try await userRepository.createGroupWorkout(groupWorkout)
        
        // Notify group members
        for memberId in group.members {
            if memberId != currentUser.id {
                try await notificationService.sendNotification(
                    to: memberId,
                    title: "Group Workout Started",
                    body: "\(currentUser.profile.firstName) started a group workout in \(group.name)!",
                    type: .groupWorkout
                )
            }
        }
        
        // Award XP for starting group workout
        try await gamificationService.awardXP(30, for: .socialInteraction, userId: currentUser.id)
    }
    
    func joinGroupWorkout(_ workoutId: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Join the group workout
        try await userRepository.joinGroupWorkout(workoutId, userId: currentUser.id)
        
        // Award XP for joining
        try await gamificationService.awardXP(20, for: .socialInteraction, userId: currentUser.id)
    }
    
    func sendMotivationalMessage(_ userId: String, message: String) async throws {
        let currentUser = try await userRepository.getCurrentUser()
        
        // Create motivational message
        let motivationalMessage = MotivationalMessage(
            id: UUID().uuidString,
            fromUserId: currentUser.id,
            toUserId: userId,
            message: message,
            createdAt: Date()
        )
        
        try await userRepository.createMotivationalMessage(motivationalMessage)
        
        // Send notification
        try await notificationService.sendNotification(
            to: userId,
            title: "Motivational Message",
            body: "\(currentUser.profile.firstName) sent you a motivational message! 💪",
            type: .motivationalMessage
        )
        
        // Award XP for both users
        try await gamificationService.awardXP(15, for: .socialInteraction, userId: currentUser.id)
        try await gamificationService.awardXP(15, for: .socialInteraction, userId: userId)
    }
    
    func getSocialStats(for userId: String) async throws -> SocialStats {
        let user = try await userRepository.getUser(id: userId)
        let posts = try await userRepository.getSocialPosts(for: userId, limit: 100)
        let groups = try await userRepository.getUserGroups(userId: userId)
        
        let totalLikes = posts.reduce(0) { $0 + $1.likes.count }
        let totalComments = posts.reduce(0) { $0 + $1.comments.count }
        let engagementRate = posts.isEmpty ? 0.0 : Double(totalLikes + totalComments) / Double(posts.count)
        
        return SocialStats(
            userId: userId,
            friendsCount: user.friends.count,
            groupsCount: groups.count,
            postsCount: posts.count,
            totalLikes: totalLikes,
            totalComments: totalComments,
            engagementRate: engagementRate,
            socialScore: calculateSocialScore(
                friendsCount: user.friends.count,
                groupsCount: groups.count,
                postsCount: posts.count,
                engagementRate: engagementRate
            )
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateSocialScore(
        friendsCount: Int,
        groupsCount: Int,
        postsCount: Int,
        engagementRate: Double
    ) -> Int {
        let friendsScore = min(friendsCount * 10, 200) // Max 200 points
        let groupsScore = min(groupsCount * 25, 100) // Max 100 points
        let postsScore = min(postsCount * 5, 150) // Max 150 points
        let engagementScore = Int(engagementRate * 100) // Max 100 points
        
        return friendsScore + groupsScore + postsScore + engagementScore
    }
}

// MARK: - Supporting Types

enum SocialFeedScope: String, Codable {
    case global
    case friends
    case group
}

struct SocialPost: Identifiable, Codable {
    let id: String
    let authorId: String
    let authorName: String
    let authorAvatar: URL?
    let type: PostType
    let content: String
    let workout: Workout?
    let imageURL: URL?
    var likes: [String]
    var comments: [SocialComment]
    let createdAt: Date
}

enum PostType: String, Codable {
    case text
    case workout
    case achievement
    case milestone
    case photo
}

struct SocialComment: Identifiable, Codable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let content: String
    let createdAt: Date
}

struct Group: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let type: GroupType
    let maxMembers: Int
    var members: [String]
    let createdBy: String
    let createdAt: Date
    let isPrivate: Bool
}

enum GroupType: String, Codable {
    case fitness
    case running
    case strength
    case yoga
    case cycling
    case general
}

struct GroupWorkout: Identifiable, Codable {
    let id: String
    let groupId: String
    let workout: Workout
    let startedBy: String
    var participants: [String]
    let status: WorkoutStatus
    let startTime: Date
    let endTime: Date?
}

enum WorkoutStatus: String, Codable {
    case active
    case completed
    case cancelled
}

struct FriendRequest: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: RequestStatus
    let createdAt: Date
}

enum RequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct GroupInvitation: Identifiable, Codable {
    let id: String
    let groupId: String
    let fromUserId: String
    let toUserId: String
    let status: RequestStatus
    let createdAt: Date
}

struct MotivationalMessage: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let message: String
    let createdAt: Date
}

struct SocialStats: Codable {
    let userId: String
    let friendsCount: Int
    let groupsCount: Int
    let postsCount: Int
    let totalLikes: Int
    let totalComments: Int
    let engagementRate: Double
    let socialScore: Int
}

// MARK: - Error Types

enum SocialFeaturesError: LocalizedError {
    case alreadyFriends
    case requestAlreadySent
    case unauthorized
    case groupFull
    case alreadyInGroup
    case notGroupMember
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .alreadyFriends:
            return "Users are already friends"
        case .requestAlreadySent:
            return "Friend request already sent"
        case .unauthorized:
            return "Unauthorized action"
        case .groupFull:
            return "Group has reached maximum capacity"
        case .alreadyInGroup:
            return "User is already a member of this group"
        case .notGroupMember:
            return "User is not a member of this group"
        case .userNotFound:
            return "User not found"
        }
    }
}
