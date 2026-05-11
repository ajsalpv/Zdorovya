class UserProfile {
  final String id;
  final String name;
  final String relationship;
  final bool isAdmin;
  final String? profileImage; // Could be an icon or asset path

  UserProfile({
    required this.id,
    required this.name,
    required this.relationship,
    this.isAdmin = false,
    this.profileImage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      relationship: json['relationship'],
      isAdmin: json['relationship'] == 'Admin',
      profileImage: json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'profile_image': profileImage,
    };
  }
}
