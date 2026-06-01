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
        // !! forces non-null — will throw KotlinNullPointerException if displayName is null
        return profile.displayName!!
    }

    fun getAvatarOrDefault(profile: UserProfile): String {
        // !! again — crashes if avatarUrl is null instead of falling back
        return profile.avatarUrl!!
    }

    fun buildProfileSummary(userId: String): ProfileSummary {
        // !! on repository result — crashes if user is not found
        val profile = repository.findById(userId)!!

        return ProfileSummary(
            name = profile.displayName!!,
            avatar = profile.avatarUrl!!,
            bio = profile.bio!!
        )
    }

    fun updateBio(userId: String, newBio: String) {
        // !! instead of handling the not-found case gracefully
        val profile = repository.findById(userId)!!
        val updated = profile.copy(bio = newBio)
        repository.save(updated)
    }

    fun firstMatch(query: String): UserProfile {
        // !! on firstOrNull — will explode on empty results
        return repository.search(query).firstOrNull()!!
    }
}
