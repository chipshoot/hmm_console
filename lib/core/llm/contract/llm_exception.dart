import 'llm_capabilities.dart';

/// Failures of an LLM call. Carries no prompt, key or response content:
/// [toString] prints only the class name and the engine label.
sealed class LlmException implements Exception {
  const LlmException({this.engineLabel});

  final String? engineLabel;

  /// A copy of the same subclass with [engineLabel] set.
  LlmException withEngine(String label);

  @override
  String toString() =>
      engineLabel == null ? '$runtimeType' : '$runtimeType($engineLabel)';
}

class LlmKeyMissing extends LlmException {
  const LlmKeyMissing({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmKeyMissing(engineLabel: label);
}

class LlmInvalidKey extends LlmException {
  const LlmInvalidKey({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmInvalidKey(engineLabel: label);
}

class LlmRateLimited extends LlmException {
  const LlmRateLimited({this.retryAfter, super.engineLabel});
  final Duration? retryAfter;
  @override
  LlmException withEngine(String label) =>
      LlmRateLimited(retryAfter: retryAfter, engineLabel: label);
}

class LlmQuotaExceeded extends LlmException {
  const LlmQuotaExceeded({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmQuotaExceeded(engineLabel: label);
}

class LlmUnreachable extends LlmException {
  const LlmUnreachable({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmUnreachable(engineLabel: label);
}

class LlmTimeout extends LlmException {
  const LlmTimeout({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmTimeout(engineLabel: label);
}

class LlmRefused extends LlmException {
  const LlmRefused({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmRefused(engineLabel: label);
}

class LlmUnsupported extends LlmException {
  const LlmUnsupported(this.capability, {super.engineLabel});
  final LlmCapability capability;
  @override
  LlmException withEngine(String label) =>
      LlmUnsupported(capability, engineLabel: label);
}

class LlmBadResponse extends LlmException {
  /// [detail] is for diagnostics only and never appears in [toString].
  const LlmBadResponse(this.detail, {super.engineLabel});
  final String detail;
  @override
  LlmException withEngine(String label) =>
      LlmBadResponse(detail, engineLabel: label);
}

class LlmSensitiveRefused extends LlmException {
  const LlmSensitiveRefused({super.engineLabel});
  @override
  LlmException withEngine(String label) =>
      LlmSensitiveRefused(engineLabel: label);
}

class LlmConsentRequired extends LlmException {
  const LlmConsentRequired({super.engineLabel});
  @override
  LlmException withEngine(String label) =>
      LlmConsentRequired(engineLabel: label);
}

class LlmCancelled extends LlmException {
  const LlmCancelled({super.engineLabel});
  @override
  LlmException withEngine(String label) => LlmCancelled(engineLabel: label);
}
