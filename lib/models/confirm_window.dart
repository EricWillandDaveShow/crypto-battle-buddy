class ConfirmWindow {
  final DateTime? expiresAt;

  ConfirmWindow({required this.expiresAt});

  bool get isActive {
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  int get secondsRemaining {
    if (!isActive) return 0;
    return expiresAt!.difference(DateTime.now()).inSeconds;
  }
}
