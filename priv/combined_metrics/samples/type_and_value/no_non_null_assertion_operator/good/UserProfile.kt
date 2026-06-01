package com.example.users

data class UserProfile(
    val id: String,
    val email: String,
    val displayName: String?,
    val avatarUrl: String?,
    val bio: String?
)

class UserProfileService(
    private val repository: UserProfileRepository,
    private val storage: AvatarStorage
) {

    fun getDisplayName(profile: UserProfile): String {
        // Elvis operator instead of !! — provides a safe fallback
        return profile.displayName ?: profile.email
    }

    fun getAvatarOrDefault(profile: UserProfile): String {
        // Safe call with Elvis instead of !! — no risk of NPE
        return profile.avatarUrl ?: storage.defaultAvatarUrl()
    }

    fun buildProfileSummary(userId: String): ProfileSummary? {
        // Safe call chain — returns null rather than crashing if profile is absent
        val profile = repository.findById(userId) ?: return null

        return ProfileSummary(
            name = profile.displayName ?: profile.email,
            avatar = profile.avatarUrl ?: storage.defaultAvatarUrl(),
            bio = profile.bio ?: "No bio provided"
        )
    }

    fun updateBio(userId: String, newBio: String): Boolean {
        val profile = repository.findById(userId) ?: return false
        val updated = profile.copy(bio = newBio)
        repository.save(updated)
        return true
    }

    fun searchProfiles(query: String): List<UserProfile> {
        return repository.search(query)
            .filter { it.displayName?.contains(query, ignoreCase = true) == true
                    || it.email.contains(query, ignoreCase = true) }
    }
}
