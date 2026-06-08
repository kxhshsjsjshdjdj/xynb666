class PeerModel {
  final String peerId;
  final String userName;
  bool isSharing;

  PeerModel({
    required this.peerId,
    required this.userName,
    this.isSharing = false,
  });

  factory PeerModel.fromMap(Map<String, dynamic> map) {
    return PeerModel(
      peerId: map['peerId'] ?? '',
      userName: map['userName'] ?? '未知用户',
      isSharing: map['isSharing'] ?? false,
    );
  }
}

// 随机房间ID
String generateRoomId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = DateTime.now().millisecondsSinceEpoch;
  String result = '';
  int n = rand;
  for (int i = 0; i < 6; i++) {
    result += chars[n % chars.length];
    n = (n * 1103515245 + 12345) & 0x7fffffff;
  }
  return result;
}

// 随机昵称
String generateUserName() {
  final adjectives = ['快乐', '聪明', '勇敢', '可爱', '帅气', '温柔', '活泼', '稳重'];
  final nouns = ['熊猫', '老虎', '兔子', '狐狸', '猫咪', '狗狗', '企鹅', '海豚'];
  final rand = DateTime.now().millisecondsSinceEpoch;
  final a = adjectives[rand % adjectives.length];
  final n = nouns[(rand ~/ 10) % nouns.length];
  return '$a$n';
}

// 头像颜色
int getAvatarColor(String name) {
  final colors = [
    0xFF6C63FF, 0xFFFF6584, 0xFF43B89C, 0xFFF4A261,
    0xFFE76F51, 0xFF457B9D, 0xFF2A9D8F, 0xFFE9C46A,
  ];
  int hash = 0;
  for (final c in name.runes) {
    hash += c;
  }
  return colors[hash % colors.length];
}
