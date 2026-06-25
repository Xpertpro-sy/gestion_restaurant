class StaffNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool read;

  StaffNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });
}
