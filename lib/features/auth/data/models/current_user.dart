class CurrentUserDataModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const CurrentUserDataModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}
