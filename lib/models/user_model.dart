class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String plan; // "free" | "premium"

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.plan,
  });

  bool get isPremium => plan == 'premium';

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      plan: data['plan'] ?? 'free',
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'plan': plan,
      };
}
