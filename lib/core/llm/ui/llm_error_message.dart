import '../../../l10n/gen/app_localizations.dart';
import '../contract/contract.dart';

/// One localized message per [LlmException], prefixed with the engine label
/// when known. Never includes detail strings, keys, prompts or provider
/// bodies.
String llmErrorMessage(LlmException e, AppLocalizations l) {
  final label = e.engineLabel ?? l.llmProviderGeneric;
  return switch (e) {
    LlmKeyMissing() => l.llmErrKeyMissing(label),
    LlmInvalidKey() => l.llmErrInvalidKey(label),
    LlmRateLimited() => l.llmErrRateLimited(label),
    LlmQuotaExceeded() => l.llmErrQuota(label),
    LlmUnreachable() => l.llmErrUnreachable(label),
    LlmTimeout() => l.llmErrTimeout(label),
    LlmRefused() => l.llmErrRefused(label),
    LlmUnsupported(:final capability) => l.llmErrUnsupported(
      label,
      switch (capability) {
        LlmCapability.vision => l.llmCapVision,
        LlmCapability.pdf => l.llmCapPdf,
        LlmCapability.streaming => l.llmCapStreaming,
        LlmCapability.structuredOutput => l.llmCapStructured,
        LlmCapability.tools => l.llmCapTools,
      },
    ),
    LlmBadResponse() => l.llmErrBadResponse(label),
    LlmSensitiveRefused() => l.llmErrSensitive(label),
    LlmConsentRequired() => l.llmErrConsent(label),
    LlmCancelled() => l.llmErrCancelled(label),
  };
}
