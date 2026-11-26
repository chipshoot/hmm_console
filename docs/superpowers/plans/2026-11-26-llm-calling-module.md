# LLM Calling Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One provider-neutral LLM module in the app (OpenAI, Claude, DeepSeek, Gemini, self-hosted) with per-device keys, a Settings screen, and receipt scanning as its first user.

**Architecture:** A pure-Dart contract (`lib/core/llm/contract/`), an `LlmClient` that runs guards (sensitive → engine → consent → capabilities → key) and picks one of two adapters by wire format (OpenAI-compatible, Anthropic) on a dedicated Dio. Engines live in synced settings; keys and consent live in the Keychain per device.

**Tech Stack:** Flutter, Riverpod 3, Dio + `http_mock_adapter` (tests), `flutter_secure_storage`, `flutter_image_compress`, GoRouter, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-11-25-llm-calling-module-design.md` (approved 2026-11-26). Read §3 decisions D1–D8 and §5 before any task.

## Global Constraints

- No new pub dependencies (all packages above are already in `pubspec.yaml`).
- The Hmm access token never reaches a provider: the LLM Dio has **no** auth interceptor and is never `apiClientProvider`'s Dio.
- Keys, prompts and response bodies never appear in logs, exceptions, `toString()` or notes. The LLM logging interceptor records method, host, status, duration only.
- Sensitive guard is absolute (D8): `containsSensitive == true` → `LlmSensitiveRefused` before engine resolution, key read or any I/O.
- Keychain keys: `llm.key.<engineId>`, `llm.consent.<engineId>`. Settings keys: `ai.engines`, `ai.default`, `ai.routes`. v1 purpose string: `receipts`.
- Timeouts: connect 15 s, receive 120 s (non-streaming), stream idle 60 s. One retry on `rateLimited` only when `Retry-After` ≤ 10 s.
- `anthropic-version: 2023-06-01`.
- iOS + Android only: on other platforms the AI providers screen and the "My AI provider" receipt mode are hidden (`defaultTargetPlatform` is iOS/Android).
- UI rules (CLAUDE.md): Cupertino on iOS / Material on Android; icon buttons via `HmmIconButton` with localized tooltip; the new screen gets a `HelpId` + registry entry + `HelpButton`; every string in en and zh ARB.
- Permanent delete keeps a confirmation dialog.
- Tests: `flutter test --timeout 30s <path>`; never `dart format` a directory (format only files you touched); commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A pasted key with surrounding spaces or a trailing newline → stored trimmed; requests never carry the whitespace (Task 3 test `key store trims pasted key`).
2. A base URL typed with a trailing slash, or a custom URL with/without `/v1` → requests go to exactly one `/` join, no `//chat` (Task 4 test `joins base URL without double slash`).
3. A stream that drops mid-answer → `LlmUnreachable`, no `Completed` event, no hang past the 60 s idle timeout (Task 4 and Task 5 test `dropped stream errors`).
4. `jsonMode` providers (DeepSeek, Ollama) wrapping JSON in ```` ```json ```` fences → fences stripped before parse (Task 6 test `strips code fences in jsonMode`).
5. Another device deletes the engine the `receipts` route points to → selector falls back to the default; the orphaned key is swept on next start (Task 3 tests `route to missing engine falls back to default`, `sweeps orphan keys`).

---

### Task 1: Contract types and JSON-schema validator

**Files:**
- Create: `lib/core/llm/contract/llm_request.dart`, `llm_message.dart`, `llm_response.dart`, `llm_event.dart`, `llm_capabilities.dart`, `llm_exception.dart`, `llm_json_schema.dart`
- Create: `lib/core/llm/contract/contract.dart` (barrel)
- Create: `lib/core/llm/json_schema_validator.dart`
- Test: `test/core/llm/contract_test.dart`, `test/core/llm/json_schema_validator_test.dart`

**Interfaces — Produces** (immutable value classes, `==`/`hashCode`):
- `enum LlmRole { user, assistant, tool }`
- `sealed class LlmPart`; `TextPart(String text)`, `ImagePart(Uint8List bytes, String mimeType)`, `DocumentPart(Uint8List bytes, {String mimeType = 'application/pdf'})`, `ToolCallPart(String id, String name, String argumentsJson)`, `ToolResultPart(String callId, String contentJson)`
- `LlmMessage({required LlmRole role, required List<LlmPart> parts})`; `LlmMessage.user(String text)` convenience
- `LlmJsonSchema({required String name, required Map<String, Object?> schema})`
- `LlmToolSpec({required String name, required String description, required Map<String, Object?> inputSchema})` (reserved)
- `LlmRequest({String? system, required List<LlmMessage> messages, String? model, int maxTokens = 2048, double? temperature, LlmJsonSchema? responseSchema, required bool containsSensitive, List<LlmToolSpec> tools = const []})` — constructor `assert(tools.isEmpty)`; getters `bool get hasImages`, `bool get hasDocuments`
- `enum LlmStopReason { end, maxTokens, toolCall, refused }`
- `LlmUsage({int? inputTokens, int? outputTokens})`
- `LlmResponse({required String text, Map<String, Object?>? json, required LlmStopReason stopReason, LlmUsage? usage, String? model})`
- `sealed class LlmEvent`; `TextDelta(String text)`, `Completed(LlmResponse response)`
- `enum StructuredOutput { native, jsonMode, none }`
- `LlmCapabilities({required bool vision, required bool pdf, required bool streaming, required StructuredOutput structuredOutput, bool tools = false})` with `toJson`/`fromJson`
- `enum LlmCapability { vision, pdf, streaming, structuredOutput, tools }`
- `sealed class LlmException implements Exception` with `String? engineLabel` and `LlmException withEngine(String label)`; subclasses: `LlmKeyMissing`, `LlmInvalidKey`, `LlmRateLimited({Duration? retryAfter})`, `LlmQuotaExceeded`, `LlmUnreachable`, `LlmTimeout`, `LlmRefused`, `LlmUnsupported(LlmCapability capability)`, `LlmBadResponse(String detail)`, `LlmSensitiveRefused`, `LlmConsentRequired`, `LlmCancelled`. `toString()` returns the class name and engine label only.
- `List<String> validateJsonSchema(Object? value, Map<String, Object?> schema)` — returns error paths (empty = valid). Supports the subset: `type` (string or list incl. `"null"`), `properties`, `required`, `items`, `enum`, `additionalProperties: false`.

- [ ] **Step 1: Write the failing tests**

```dart
test('request refuses tools in v1', () {
  expect(() => LlmRequest(messages: [LlmMessage.user('hi')],
      containsSensitive: false,
      tools: [LlmToolSpec(name: 't', description: 'd', inputSchema: {})]),
    throwsA(isA<AssertionError>()));
});
test('hasImages / hasDocuments', () {
  final r = LlmRequest(containsSensitive: false, messages: [LlmMessage(
    role: LlmRole.user, parts: [ImagePart(Uint8List(1), 'image/jpeg')])]);
  expect(r.hasImages, isTrue); expect(r.hasDocuments, isFalse);
});
test('exception toString leaks nothing', () {
  expect(LlmBadResponse('secret body').toString(), isNot(contains('secret')));
});
test('capabilities round-trip', () { /* toJson → fromJson equals */ });
// validator
test('nullable type accepts null', () =>
  expect(validateJsonSchema(null, {'type': ['string', 'null']}), isEmpty));
test('missing required reported', () => expect(
  validateJsonSchema({}, {'type': 'object', 'required': ['lineItems'],
    'properties': {'lineItems': {'type': 'array'}}}),
  ['lineItems: required']));
test('enum and nested items', () { /* {"lineItems":[{"type":"Oil"}]} against enum Labour|Part|Fee → contains 'lineItems[0].type: enum' */ });
test('additionalProperties false rejects extras', () { /* {'x':1} → ['x: not allowed'] */ });
```

- [ ] **Step 2: Run to verify they fail**
Run: `flutter test --timeout 30s test/core/llm/` — Expected: FAIL (files missing).

- [ ] **Step 3: Implement the types and `validateJsonSchema`** as listed. Error path format: dotted keys, `[i]` for array indexes, suffix `: required` / `: type` / `: enum` / `: not allowed`.

- [ ] **Step 4: Run to verify they pass** — same command, all PASS; `flutter analyze lib/core/llm test/core/llm` clean.

- [ ] **Step 5: Commit** — `feat(llm): provider-neutral contract and schema validator (#97)`

---

### Task 2: SSE parser

**Files:**
- Create: `lib/core/llm/adapters/sse.dart`
- Test: `test/core/llm/sse_test.dart`

**Interfaces — Produces:**
- `class SseEvent { final String? event; final String data; }`
- `Stream<SseEvent> parseSse(Stream<List<int>> bytes)` — UTF-8 decode across chunk boundaries; events separated by a blank line; multiple `data:` lines joined with `\n`; lines starting with `:` ignored; `event:` sets the name; a trailing event without a blank line is emitted at stream end; a source error is forwarded.

- [ ] **Step 1: Failing tests** — `split chunks reassemble` (one event split across three byte chunks, including inside the multi-byte character `中`), `multi-line data joins with newline`, `comment keep-alives ignored`, `named events` (`event: content_block_delta`), `[DONE] passes through as data` (the adapter interprets it), `last event without blank line emitted`, `source error forwarded`.
- [ ] **Step 2: Run** `flutter test --timeout 30s test/core/llm/sse_test.dart` — FAIL.
- [ ] **Step 3: Implement `parseSse`** with `utf8.decoder` + `LineSplitter`.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat(llm): server-sent events parser (#97)`

---

### Task 3: Engines, presets, synced storage, selector, key store

**Files:**
- Create: `lib/core/llm/engines/llm_engine.dart`, `engine_presets.dart`, `llm_engine_registry.dart`, `engine_selector.dart`
- Create: `lib/core/llm/llm_key_store.dart`
- Modify: `lib/features/settings/domain/syncable_settings.dart` (fields `aiEngines` (String? JSON), `aiDefault` (String?), `aiRoutes` (String? JSON) — follow the `calendarShowLunar` pattern at lines 43/70/120/162/221/239)
- Modify: `lib/features/settings/data/syncable_settings_repository.dart` (keys `aiEnginesKey = 'ai.engines'`, `aiDefaultKey = 'ai.default'`, `aiRoutesKey = 'ai.routes'`; read/write like `calendarShowLunarKey` at lines 54/161/202)
- Test: `test/core/llm/engines_test.dart`, `test/core/llm/llm_key_store_test.dart`, extend the existing syncable-settings round-trip test under `test/features/settings/`

**Interfaces:**
- Consumes: `LlmCapabilities`, `StructuredOutput` (Task 1).
- Produces:
  - `enum LlmEngineKind { openai, anthropic, deepseek, gemini, custom }`; `enum WireFormat { openAiCompatible, anthropic }`
  - `LlmEngine({required String id, required String label, required LlmEngineKind kind, required String baseUrl, required String defaultModel, required bool requiresKey, required LlmCapabilities capabilities})`; `WireFormat get wireFormat` (`anthropic` → anthropic, else openAiCompatible); `toJson`/`fromJson`; `copyWith`
  - `LlmEngine presetEngine(LlmEngineKind kind, {required String id, required String label, required String model})` — values from the spec §5.4 table; custom: `baseUrl ''`, `requiresKey false`, vision/pdf false, `jsonMode`, streaming true; all presets streaming true
  - `class LlmEngineSettings { final List<LlmEngine> engines; final String? defaultId; final Map<String, String> routes; }`
  - `final llmEngineSettingsProvider` (Notifier<LlmEngineSettings>) with `add(LlmEngine)`, `update(LlmEngine)`, `remove(String id)` (also removes routes to it, clears default if it was default, and deletes this device's key + consent), `setDefault(String id)`, `setRoute(String purpose, String? id)` — persisted through the settings controller into `ai.*`
  - `LlmEngine? selectEngine(LlmEngineSettings s, {String? engineId, String? purpose})` — explicit id → route (if that engine exists) → default (if it exists) → `null`
  - `class LlmKeyStore` over `FlutterSecureStorage`: `Future<String?> readKey(String id)`, `Future<void> writeKey(String id, String key)` (trims; empty after trim → delete), `deleteKey(id)`, `Future<bool> hasKey(id)`, `Future<bool> hasConsent(id)`, `setConsent(id)`, `Future<void> sweepOrphans(Set<String> liveIds)` (deletes `llm.key.*` / `llm.consent.*` whose id is not live; uses `readAll`)
  - `final llmKeyStoreProvider = Provider<LlmKeyStore>(...)`

- [ ] **Step 1: Failing tests** — `engine json round-trip`; `wireFormat by kind`; `presets match spec table` (openai base `https://api.openai.com/v1`, pdf true, native; deepseek `https://api.deepseek.com/v1`, vision false, jsonMode; gemini `https://generativelanguage.googleapis.com/v1beta/openai`, pdf false, native; anthropic `https://api.anthropic.com`, pdf true, native); `selector: explicit beats route beats default`; `route to missing engine falls back to default`; `no engines → null`; `remove clears its route and default`; `key store trims pasted key` (`'  sk-abc\n'` → `'sk-abc'`); `blank key deletes`; `sweeps orphan keys` (keys and consent for `a`,`b`; live `{a}` → `b` entries gone, `a` kept); settings bundle round-trips `ai.engines`/`ai.default`/`ai.routes` and an absent value stays absent.
- [ ] **Step 2: Run** `flutter test --timeout 30s test/core/llm/engines_test.dart test/core/llm/llm_key_store_test.dart test/features/settings` — FAIL.
- [ ] **Step 3: Implement.** Use a fake `FlutterSecureStorage` in tests (override `read/write/delete/readAll`). Call `sweepOrphans` once after engine settings first load.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat(llm): engines, presets, synced engine settings and per-device key store (#97)`

---

### Task 4: LLM Dio and the OpenAI-compatible adapter

**Files:**
- Create: `lib/core/llm/adapters/llm_adapter.dart`, `openai_compatible_adapter.dart`, `lib/core/llm/llm_dio.dart`
- Test: `test/core/llm/openai_compatible_adapter_test.dart`, `test/core/llm/llm_dio_test.dart`

**Interfaces:**
- Consumes: contract (Task 1), `parseSse` (Task 2), `LlmEngine` (Task 3).
- Produces:
  - `abstract interface class LlmAdapter { WireFormat get format; Future<LlmResponse> complete(LlmEngine engine, String? key, LlmRequest request, {required String model, CancelToken? cancel}); Stream<LlmEvent> stream(LlmEngine engine, String? key, LlmRequest request, {required String model, CancelToken? cancel}); }` — the client resolves `model` (`request.model ?? engine.defaultModel`). Adapters throw only `LlmException`s; with a schema they return the raw JSON text in `LlmResponse.text` and leave `json` null (the client validates).
  - `Uri joinUrl(String base, String path)` — single-slash join.
  - `final llmDioProvider = Provider<Dio>(...)` — connect 15 s, receive 120 s, one interceptor logging `method host status ms` only; no auth interceptor.
  - `OpenAiCompatibleAdapter(Dio dio)`.

Request (POST `joinUrl(baseUrl, 'chat/completions')`, header `Authorization: Bearer <key>` only when key non-null):
`{"model", "messages":[{"role":"system","content":system}?, …], "max_tokens", "temperature"?}`. Content parts: text `{"type":"text","text"}`, image `{"type":"image_url","image_url":{"url":"data:<mime>;base64,<b64>"}}`, PDF `{"type":"file","file":{"filename":"document.pdf","file_data":"data:application/pdf;base64,<b64>"}}`. Schema: native → `"response_format":{"type":"json_schema","json_schema":{"name","schema","strict":true}}`; jsonMode → `{"type":"json_object"}` and append `"Respond with JSON matching this schema: <schema json>"` to the system prompt. Streaming adds `"stream":true,"stream_options":{"include_usage":true}`.
Response: `choices[0].message.content`, `finish_reason` (`stop`→end, `length`→maxTokens, `content_filter`→refused), `usage.prompt_tokens/completion_tokens`, `model`.
Errors: 401/403 → `LlmInvalidKey`; 429 with body `error.code == 'insufficient_quota'` → `LlmQuotaExceeded`, else `LlmRateLimited(retryAfter: Retry-After seconds)`; ≥500 or connection error → `LlmUnreachable`; Dio timeout → `LlmTimeout`; cancel → `LlmCancelled`; malformed body → `LlmBadResponse('openai: malformed')`.

- [ ] **Step 1: Failing tests** with `DioAdapter` (http_mock_adapter): `text request body golden` (exact JSON, system message first); `image part encodes data URL`; `pdf part uses file content`; `native schema sets response_format strict`; `jsonMode adds json_object and schema to system`; `no Authorization header when key null`; `joins base URL without double slash` (`'https://h/v1/'` → `https://h/v1/chat/completions`); `maps 401, 429 quota, 429 rate (Retry-After 7 → 7 s), 503, timeout, cancel`; `stream yields deltas then Completed with usage` (3 `data:` chunks + `[DONE]`); `dropped stream errors` (byte stream errors after the first delta → `LlmUnreachable`, no `Completed`); `llm dio has no auth interceptor and logs no headers` (run a request carrying header `x-api-key: SECRET` through a captured logger → output lacks `SECRET`).
- [ ] **Step 2: Run** `flutter test --timeout 30s test/core/llm/openai_compatible_adapter_test.dart test/core/llm/llm_dio_test.dart` — FAIL.
- [ ] **Step 3: Implement.** Streaming uses `ResponseType.stream` and `parseSse`; idle timeout 60 s via `Stream.timeout` → `LlmTimeout`.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat(llm): OpenAI-compatible adapter and dedicated Dio (#97)`

---

### Task 5: Anthropic adapter

**Files:**
- Create: `lib/core/llm/adapters/anthropic_adapter.dart`
- Test: `test/core/llm/anthropic_adapter_test.dart`

**Interfaces:**
- Consumes: `LlmAdapter`, `joinUrl`, `llmDioProvider` (Task 4); `parseSse` (Task 2).
- Produces: `AnthropicAdapter(Dio dio)` implementing `LlmAdapter`, `format == WireFormat.anthropic`.

Request: POST `joinUrl(baseUrl, 'v1/messages')`, headers `x-api-key: <key>`, `anthropic-version: 2023-06-01`, `content-type: application/json`. Body `{"model","max_tokens","system"?,"temperature"?,"messages":[{"role","content":[blocks]}]}`. Blocks: text `{"type":"text","text"}`, image `{"type":"image","source":{"type":"base64","media_type","data"}}`, PDF `{"type":"document","source":{"type":"base64","media_type":"application/pdf","data"}}`. Schema → `"tools":[{"name":<schema.name>,"description":"Return the result.","input_schema":<schema>}]`, `"tool_choice":{"type":"tool","name":<schema.name>}`; the `tool_use` block's `input` is returned as `jsonEncode(input)` in `text`.
Response: text = concatenated `text` blocks (or the tool input as above); `stop_reason` (`end_turn`/`stop_sequence`→end, `max_tokens`→maxTokens, `tool_use`→end when a schema was requested, `refusal`→refused); `usage.input_tokens/output_tokens`.
Streaming: `"stream":true`; `content_block_delta` with `delta.type == 'text_delta'` → `TextDelta`; `input_json_delta.partial_json` accumulated (no deltas emitted for it); `message_delta` carries `stop_reason` and usage; `message_stop` → `Completed`; `error` event → mapped exception.
Errors: 401/403 → `LlmInvalidKey`; 429 → `LlmRateLimited(Retry-After)`; 529, ≥500 or connection → `LlmUnreachable`; 400 whose `error.message` contains `credit balance` → `LlmQuotaExceeded`; timeout/cancel as Task 4.

- [ ] **Step 1: Failing tests** — `body golden with system top-level`; `image and document blocks`; `schema becomes forced tool`; `tool_use input returned as JSON text`; `headers carry key and version, no Authorization`; `refusal maps to refused`; `error mapping table` (401, 429+Retry-After, 529, 400 credit, timeout, cancel); `stream text deltas then Completed`; `stream accumulates input_json_delta into Completed text`; `dropped stream errors`.
- [ ] **Step 2: Run** `flutter test --timeout 30s test/core/llm/anthropic_adapter_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** — `feat(llm): Anthropic adapter (#97)`

---

### Task 6: LlmClient

**Files:**
- Create: `lib/core/llm/llm_client.dart`
- Test: `test/core/llm/llm_client_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.
- Produces:
  - `class LlmClient { LlmClient({required LlmEngineSettings Function() settings, required LlmKeyStore keys, required Map<WireFormat, LlmAdapter> adapters, Future<void> Function(Duration) delay = Future.delayed}); Future<LlmResponse> complete(LlmRequest r, {String? engineId, String? purpose, CancelToken? cancel}); Stream<LlmEvent> stream(LlmRequest r, {String? engineId, String? purpose, CancelToken? cancel}); Future<void> testConnection(LlmEngine engine, String? key); }`
  - `final llmClientProvider = Provider<LlmClient>(...)` wiring `llmEngineSettingsProvider`, `llmKeyStoreProvider`, and both adapters on `llmDioProvider`.

Behaviour (spec §5.2, in this order): (1) `containsSensitive` → `LlmSensitiveRefused`, before touching settings or keys; (2) `selectEngine` → null → `LlmKeyMissing()` with no label; (3) `!keys.hasConsent(id)` → `LlmConsentRequired`; (4) `hasImages && !vision` / `hasDocuments && !pdf` / schema with `structuredOutput == none` / `stream()` with `!streaming` → `LlmUnsupported(capability)`; (5) `requiresKey && key == null` → `LlmKeyMissing`; (6) adapter call; any thrown `LlmException` gets `withEngine(label)`; `LlmRateLimited` with `retryAfter` ≤ 10 s → `delay(retryAfter)` then one retry; (7) schema: strip a leading ```` ```json ```` or ```` ``` ```` fence and the trailing fence, `jsonDecode`, `validateJsonSchema`; on decode or validation error retry once with an extra user message `"Your previous reply was invalid: <errors>. Reply again with only valid JSON."`; second failure → `LlmBadResponse('schema')`. Success returns the response with `json` set. `stream()` with a schema validates on `Completed` (no retry). `testConnection` skips consent and sends `LlmRequest(messages: [LlmMessage.user('Reply with OK.')], maxTokens: 16, containsSensitive: false)`.

- [ ] **Step 1: Failing tests** with fake adapters and key store: `sensitive refused before settings or key read` (counters stay 0); `no engine → key missing`; `consent required`; `image to non-vision engine unsupported`; `pdf to non-pdf engine unsupported`; `missing key when requiresKey`; `keyless engine sends null key`; `engine label attached to adapter errors`; `retries once on short rate limit, not on long` (Retry-After 3 s → one retry through the fake delay; 30 s → none); `validates schema and sets json`; `strips code fences in jsonMode`; `retries once on invalid JSON then badResponse`; `purpose route used`; `testConnection skips consent`.
- [ ] **Step 2: Run** `flutter test --timeout 30s test/core/llm/llm_client_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS; then `flutter test --timeout 30s test/core/llm` all PASS.
- [ ] **Step 5: Commit** — `feat(llm): LlmClient with guards, selection, validation and retries (#97)`

---

### Task 7: Settings → AI providers, consent sheet, error messages, iOS network rules

**Files:**
- Create: `lib/features/settings/presentation/screens/ai_providers_screen.dart`, `ai_provider_edit_screen.dart`
- Create: `lib/core/llm/ui/llm_consent_sheet.dart`, `lib/core/llm/ui/llm_error_message.dart`
- Modify: `lib/core/navigation/router_config.dart` (under `/settings` routes beside `videos`, line ~263: `ai` → `AiProvidersScreen`, `ai/new` and `ai/:id` → `AiProviderEditScreen`); route names file used there (`aiProviders`, `aiProviderEdit`)
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart` ("AI providers" row near the receipt section at line ~373, iOS/Android only)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.aiProviders` + entry, following `HelpId.videoStorage` at line ~692)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ `flutter gen-l10n`)
- Modify: `ios/Runner/Info.plist` — `NSAppTransportSecurity` dict with `NSAllowsLocalNetworking` = true; `NSLocalNetworkUsageDescription` = "Hmm Console connects to AI models you host on your local network."
- Test: `test/features/settings/presentation/ai_providers_screen_test.dart`, `ai_provider_edit_screen_test.dart`, `test/core/llm/llm_error_message_test.dart`

**Interfaces:**
- Consumes: `llmEngineSettingsProvider`, `presetEngine`, `llmKeyStoreProvider` (Task 3); `joinUrl`, `llmDioProvider` (Task 4); `llmClientProvider.testConnection` (Task 6); `LlmException` (Task 1).
- Produces:
  - `Future<bool> showLlmConsentSheet(BuildContext context, LlmEngine engine)` — Cupertino action sheet on iOS / Material dialog on Android; copy "Content you send goes to {label} at {host}. Sensitive notes are never sent. Continue?"; accept → `LlmKeyStore.setConsent(engine.id)`, returns true.
  - `String llmErrorMessage(LlmException e, AppLocalizations l)` — one message per subclass, prefixed with the engine label when present (en example `"{label}: the key was rejected — check it in Settings → AI providers."`); never includes detail strings.
  - Screens per spec §6: list rows show label, "Default", and `Key ✓` / `Key needed on this device` / `No key needed`; "+ Add provider"; "Use for receipts" picker writes route `receipts`. Edit screen: kind picker; label; base URL (editable for custom only); model field + "Fetch models" (`GET joinUrl(base, 'models')` — OpenAI format with bearer, Anthropic `v1/models` with `x-api-key` + version — listing `data[].id`; failure keeps manual typing); key field obscured with paste button, shows "Saved on this device" when `hasKey`; capability toggles for custom; Save requires label, model and (custom) base URL; "Test connection" shows success or `llmErrorMessage`; Delete with a confirmation dialog.

- [ ] **Step 1: Failing tests** — list shows the three key states; add an OpenAI preset → saved with the preset base URL and the typed model, key stored trimmed; Save disabled without a model; custom engine requires a base URL; Test connection success and the `LlmInvalidKey` message; Delete asks for confirmation and removes the engine and its key; receipts picker writes the route; with `debugDefaultTargetPlatformOverride = TargetPlatform.windows` the Settings row is absent; error-message test covers every `LlmException` subclass and asserts no message contains a detail string; consent sheet accept stores consent, cancel does not.
- [ ] **Step 2: Run** `flutter test --timeout 30s test/features/settings/presentation/ai_providers_screen_test.dart test/features/settings/presentation/ai_provider_edit_screen_test.dart test/core/llm/llm_error_message_test.dart` — FAIL.
- [ ] **Step 3: Implement** (strings en + zh; `HmmIconButton` for icon buttons; `HelpButton` in both screens' top bars).
- [ ] **Step 4: Run** — PASS; `flutter test --timeout 30s test/core/help` PASS (icon-button guard, help registry).
- [ ] **Step 5: Commit** — `feat(llm): AI providers settings, consent sheet and error messages (#97)`

---

### Task 8: Receipt scan on the module

**Files:**
- Create: `lib/features/receipt_scan/data/llm_receipt_extractor.dart`, `lib/features/receipt_scan/data/receipt_llm_schema.dart`
- Modify: `lib/features/receipt_scan/domain/receipt_draft.dart` (`ReceiptExtractorMode.provider('provider')`; new top-level `ReceiptDraft receiptDraftFromJson(Map<String, dynamic> j, ReceiptExtractorMode source)` — the mapping now in `ApiLlmExtractor._fromJson`, moved here unchanged incl. the camel/Pascal key fallback)
- Modify: `lib/features/receipt_scan/data/api_llm_extractor.dart` (use `receiptDraftFromJson`)
- Modify: `lib/features/receipt_scan/providers/receipt_extractor_providers.dart` (case `provider => LlmReceiptExtractor(ref.watch(llmClientProvider))`)
- Modify: `lib/features/receipt_scan/presentation/receipt_extraction_settings_section.dart` (third option "My AI provider", iOS/Android only; choosing it with no engine for `receipts` or default opens `/settings/ai`; the Cloud AI label becomes "Hmm cloud AI")
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` (lines ~410/447/738: PDF option enabled for `cloudAi`, or for `provider` when the engine chosen by `selectEngine(purpose: 'receipts')` has `capabilities.pdf`; on `LlmConsentRequired` call `showLlmConsentSheet` then retry once; other `LlmException` → `llmErrorMessage` snackbar)
- Modify: ARB en/zh
- Test: `test/features/receipt_scan/data/llm_receipt_extractor_test.dart`, `test/features/receipt_scan/data/receipt_llm_schema_test.dart`, extend the existing settings-section and service-record-form receipt tests

**Interfaces:**
- Consumes: `LlmClient`, `LlmRequest`, parts, `LlmJsonSchema` (Tasks 1, 6); `selectEngine`, `llmEngineSettingsProvider` (Task 3); `showLlmConsentSheet`, `llmErrorMessage` (Task 7).
- Produces:
  - `const receiptLlmSchema = LlmJsonSchema(name: 'record_service_receipt', schema: {...})` — fields from the server's `AnthropicReceiptExtractionProvider.BuildSchema()` (`Hmm/src/Hmm.Utility.Services`): `shopName`, `date` (ISO yyyy-MM-dd), `odometer` (integer), `tax`, `total`, `currency` (ISO 4217), `lineItems[]` {`type` enum `Labour|Part|Fee`, `name`, `quantity` (integer), `unitCost`, `amount`}, with the server's field descriptions. **Strict-compatible for OpenAI:** every property listed in `required`, optional values as nullable types, `additionalProperties: false` on both objects.
  - `const receiptLlmPrompt` — the server prompt text (same file, the `"Extract this vehicle service receipt…"` string) ported verbatim, minus the words "using the tool".
  - `LlmReceiptExtractor(LlmClient client, {Future<Uint8List> Function(Uint8List)? compress}) implements ReceiptExtractor` — builds `LlmRequest(system: receiptLlmPrompt, messages: [user: ImagePart or DocumentPart], responseSchema: receiptLlmSchema, containsSensitive: input.sensitive)` and calls `complete(..., purpose: 'receipts')`; images go through `compress` (default: `FlutterImageCompress` to JPEG, long side ≤ 2000 px, quality stepped down until < 4 MB); returns `receiptDraftFromJson(response.json!, ReceiptExtractorMode.provider)`. `LlmException`s propagate unchanged.

- [ ] **Step 1: Failing tests** — `schema field list matches the server` (exact property names and the line-item enum); `schema is strict-compatible` (each object: all properties in `required`, `additionalProperties: false`); `sensitive input refused` (fake client receives nothing; `LlmSensitiveRefused`); `image request uses receipts purpose, schema and prompt`; `pdf input becomes DocumentPart`; `large image is downscaled under 4 MB` (fake `compress`); `json maps to draft with provider source`; `ApiLlmExtractor still maps the same JSON` (shared-mapper regression, incl. PascalCase keys); settings section shows the third option on iOS and hides it on Windows; PDF option enabled for `provider` only when the receipts engine has `pdf: true`.
- [ ] **Step 2: Run** `flutter test --timeout 30s test/features/receipt_scan test/features/automobile_records` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS; then full suite `flutter test --timeout 30s` PASS and `flutter analyze` clean.
- [ ] **Step 5: Commit** — `feat(receipt-scan): My AI provider mode on the LLM module (#97)`

---

## Self-review notes

- Spec coverage: §5.1 → T1; SSE (§5.3) → T2; §5.4/§5.5 → T3; §5.3 adapters → T4/T5; §5.2 → T6; §6, §8 (iOS, platforms), §10 → T7; §7 → T8; §9 testing per task; §11 future work intentionally not built.
- Names used across tasks: `LlmEngineSettings`, `selectEngine`, `LlmKeyStore`, `LlmAdapter`, `joinUrl`, `llmDioProvider`, `llmClientProvider`, `showLlmConsentSheet`, `llmErrorMessage`, `receiptLlmSchema`, `receiptDraftFromJson` — consistent.
