enum DownloadNetworkPolicy {
  anyNetwork,
  wifiOnly,
  askOnMobileData;

  factory DownloadNetworkPolicy.parse(dynamic value) => switch (value) {
    'wifiOnly' || 1 || '1' => wifiOnly,
    'askOnMobileData' || 2 || '2' => askOnMobileData,
    _ => defaultValue,
  };

  static const defaultValue = anyNetwork;

  dynamic toData() => index;
}

enum DownloadNetworkConstraint {
  unrestricted,
  wifiRequired;

  bool get requiresWiFi => this == wifiRequired;
}

class DownloadNetworkPromptResult {
  const DownloadNetworkPromptResult({
    required this.constraint,
    required this.rememberForSession,
  });

  final DownloadNetworkConstraint constraint;
  final bool rememberForSession;
}

typedef DownloadNetworkPrompt = Future<DownloadNetworkPromptResult?> Function();

class DownloadNetworkSession {
  DownloadNetworkConstraint? _rememberedConstraint;
  Future<DownloadNetworkConstraint?>? _pendingResolution;

  Future<DownloadNetworkConstraint?> resolve({
    required DownloadNetworkPolicy policy,
    required bool isMobileDataOnly,
    required DownloadNetworkPrompt prompt,
  }) async {
    switch (policy) {
      case DownloadNetworkPolicy.anyNetwork:
        return DownloadNetworkConstraint.unrestricted;
      case DownloadNetworkPolicy.wifiOnly:
        return DownloadNetworkConstraint.wifiRequired;
      case DownloadNetworkPolicy.askOnMobileData:
        break;
    }

    final remembered = _rememberedConstraint;
    if (remembered != null) return remembered;

    if (!isMobileDataOnly) {
      return DownloadNetworkConstraint.wifiRequired;
    }

    final pending = _pendingResolution;
    if (pending != null) return pending;

    final resolution = _resolvePrompt(prompt);
    _pendingResolution = resolution;

    try {
      return await resolution;
    } finally {
      _pendingResolution = null;
    }
  }

  Future<DownloadNetworkConstraint?> _resolvePrompt(
    DownloadNetworkPrompt prompt,
  ) async {
    final result = await prompt();
    if (result == null) return null;

    if (result.rememberForSession) {
      _rememberedConstraint = result.constraint;
    }

    return result.constraint;
  }
}
