class User {
  final String id;
  final String name;
  final String accessToken;
  final String serverUrl;

  User({
    required this.id,
    required this.name,
    required this.accessToken,
    required this.serverUrl,
  });

  factory User.fromJson(Map<String, dynamic> json, String serverUrl, String token) {
    return User(
      id: json['Id'],
      name: json['Name'],
      accessToken: token,
      serverUrl: serverUrl,
    );
  }
}
