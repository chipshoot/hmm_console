import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/llm/adapters/llm_adapter.dart';
import '../../../../core/llm/contract/contract.dart';
import '../../../../core/llm/engines/engine_presets.dart';
import '../../../../core/llm/engines/llm_engine.dart';
import '../../../../core/llm/engines/llm_engine_registry.dart';
import '../../../../core/llm/llm_client.dart';
import '../../../../core/llm/llm_dio.dart';
import '../../../../core/llm/llm_key_store.dart';
import '../../../../core/llm/ui/llm_error_message.dart';
import '../../../../core/util/uuid.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../widgets/ai_choice_picker.dart';
import 'ai_providers_screen.dart' show aiKeyPresentProvider;

const _anthropicVersion = '2023-06-01';

/// Add (no [engineId]) or edit one AI provider. The saved key is never shown:
/// an empty key field leaves it untouched, a pasted key replaces it, and
/// Remove key deletes it.
class AiProviderEditScreen extends ConsumerStatefulWidget {
  const AiProviderEditScreen({super.key, this.engineId});

  final String? engineId;

  @override
  ConsumerState<AiProviderEditScreen> createState() =>
      _AiProviderEditScreenState();
}

class _AiProviderEditScreenState extends ConsumerState<AiProviderEditScreen> {
  final _label = TextEditingController();
  final _url = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();

  late final String _id = widget.engineId ?? generateUuid();
  LlmEngineKind _kind = LlmEngineKind.openai;
  bool _vision = false;
  bool _pdf = false;
  bool _makeDefault = false;
  bool _urlUnlocked = false;
  bool _hasKey = false;
  bool _initialized = false;
  bool _busy = false;
  bool _fetchFailed = false;
  String? _testResult;
  bool _testOk = false;

  bool get _isNew => widget.engineId == null;
  bool get _custom => _kind == LlmEngineKind.custom;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _applyPreset(_kind);
      _initialized = true;
    } else {
      _loadKeyState();
    }
    for (final c in [_label, _url, _model, _key]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _loadKeyState() async {
    final has = await ref.read(llmKeyStoreProvider).hasKey(_id);
    if (mounted) setState(() => _hasKey = has);
  }

  void _applyPreset(LlmEngineKind kind) {
    final p = presetEngine(kind, id: _id, label: '', model: '');
    _kind = kind;
    _url.text = p.baseUrl;
    _vision = p.capabilities.vision;
    _pdf = p.capabilities.pdf;
    _urlUnlocked = false;
    _fetchFailed = false;
  }

  /// Fills the form from the stored engine once the settings have loaded.
  void _initFrom(LlmEngine e) {
    _initialized = true;
    _kind = e.kind;
    _label.text = e.label;
    _url.text = e.baseUrl;
    _model.text = e.defaultModel;
    _vision = e.capabilities.vision;
    _pdf = e.capabilities.pdf;
  }

  String _kindName(AppLocalizations l, LlmEngineKind k) => switch (k) {
    LlmEngineKind.openai => 'OpenAI',
    LlmEngineKind.anthropic => 'Anthropic',
    LlmEngineKind.deepseek => 'DeepSeek',
    LlmEngineKind.gemini => 'Gemini',
    LlmEngineKind.custom => l.aiKindCustom,
  };

  LlmEngine _build() {
    final base = presetEngine(
      _kind,
      id: _id,
      label: _label.text.trim(),
      model: _model.text.trim(),
    );
    final caps = _custom
        ? LlmCapabilities(
            vision: _vision,
            pdf: _pdf,
            streaming: base.capabilities.streaming,
            structuredOutput: base.capabilities.structuredOutput,
          )
        : base.capabilities;
    return base.copyWith(baseUrl: _url.text.trim(), capabilities: caps);
  }

  bool get _canSave =>
      !_busy &&
      _label.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      (!_custom || _url.text.trim().isNotEmpty);

  /// The typed key, else the saved one; null when neither exists.
  Future<String?> _effectiveKey() async {
    final typed = _key.text.trim();
    if (typed.isNotEmpty) return typed;
    return ref.read(llmKeyStoreProvider).readKey(_id);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final notifier = ref.read(llmEngineSettingsProvider.notifier);
    final keys = ref.read(llmKeyStoreProvider);
    final engine = _build();
    final hadDefault = ref.read(llmEngineSettingsProvider).defaultId != null;
    if (_isNew) {
      await notifier.add(engine);
    } else {
      await notifier.update(engine);
    }
    if (_key.text.trim().isNotEmpty) {
      await keys.writeKey(_id, _key.text);
    }
    if (_makeDefault || (_isNew && !hadDefault)) {
      await notifier.setDefault(_id);
    }
    ref.invalidate(aiKeyPresentProvider);
    if (!mounted) return;
    await Navigator.of(context).maybePop();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && mounted) _key.text = text.trim();
  }

  Future<void> _removeKey() async {
    await ref.read(llmKeyStoreProvider).deleteKey(_id);
    ref.invalidate(aiKeyPresentProvider);
    if (!mounted) return;
    setState(() => _hasKey = false);
  }

  Future<void> _test() async {
    final l = AppLocalizations.of(context);
    final engine = _build();
    setState(() {
      _busy = true;
      _testResult = null;
    });
    String message;
    var ok = false;
    try {
      final key = await _effectiveKey();
      if (engine.requiresKey && key == null) {
        throw LlmKeyMissing(engineLabel: engine.label);
      }
      await ref.read(llmClientProvider).testConnection(engine, key);
      message = l.aiEditTestOk;
      ok = true;
    } on LlmException catch (e) {
      message = llmErrorMessage(e, l);
    } catch (_) {
      message = llmErrorMessage(
        LlmBadResponse('test', engineLabel: engine.label),
        l,
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testResult = message;
      _testOk = ok;
    });
  }

  /// Lists the provider's models. Failures only set a short note; response
  /// bodies are never shown.
  Future<void> _fetchModels() async {
    final engine = _build();
    setState(() {
      _busy = true;
      _fetchFailed = false;
    });
    List<String>? ids;
    try {
      final key = await _effectiveKey();
      final anthropic = engine.wireFormat == WireFormat.anthropic;
      final res = await ref
          .read(llmDioProvider)
          .getUri<Object?>(
            joinUrl(engine.baseUrl, anthropic ? 'v1/models' : 'models'),
            options: Options(
              headers: anthropic
                  ? {'x-api-key': ?key, 'anthropic-version': _anthropicVersion}
                  : {'Authorization': ?(key == null ? null : 'Bearer $key')},
              validateStatus: (_) => true,
            ),
          );
      final data = res.data;
      if ((res.statusCode ?? 0) == 200 && data is Map && data['data'] is List) {
        ids = [
          for (final m in data['data'] as List)
            if (m is Map && m['id'] is String) m['id'] as String,
        ];
      }
    } catch (_) {
      ids = null;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _fetchFailed = ids == null || ids.isEmpty;
    });
    if (ids == null || ids.isEmpty) return;
    final picked = await showAiChoice<String>(context, [
      for (final id in ids) AiChoice(id, id),
    ]);
    if (picked != null && mounted) _model.text = picked.value;
  }

  Future<bool> _confirmDelete(AppLocalizations l) async {
    final msg = Text(l.aiEditDeleteConfirm(_label.text.trim()));
    final apple = Theme.of(context).platform == TargetPlatform.iOS;
    final bool? ok;
    if (apple) {
      ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: msg,
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete),
            ),
          ],
        ),
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: msg,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete),
            ),
          ],
        ),
      );
    }
    return ok ?? false;
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    if (!await _confirmDelete(l) || !mounted) return;
    await ref.read(llmEngineSettingsProvider.notifier).remove(_id);
    ref.invalidate(aiKeyPresentProvider);
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(llmEngineSettingsProvider);
    if (!_initialized) {
      final e = settings.engines.where((e) => e.id == _id).firstOrNull;
      if (e != null) _initFrom(e);
    }
    final isDefault = settings.defaultId == _id;
    final presetUrlLocked = !_custom && !_urlUnlocked;

    return AppScaffold(
      title: _isNew ? l.aiEditTitleNew : l.aiEditTitle,
      actions: const [HelpButton(helpId: HelpId.aiProviders)],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: !_initialized
                ? const [Center(child: CircularProgressIndicator.adaptive())]
                : [
                    ListTile(
                      key: const Key('aiKindPicker'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.aiEditKind),
                      subtitle: Text(_kindName(l, _kind)),
                      trailing: _isNew ? const Icon(Icons.expand_more) : null,
                      onTap: !_isNew
                          ? null
                          : () async {
                              final picked =
                                  await showAiChoice<LlmEngineKind>(context, [
                                    for (final k in LlmEngineKind.values)
                                      AiChoice(k, _kindName(l, k)),
                                  ]);
                              if (picked == null) return;
                              setState(() => _applyPreset(picked.value));
                            },
                    ),
                    TextField(
                      controller: _label,
                      decoration: InputDecoration(labelText: l.aiEditLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _url,
                      readOnly: presetUrlLocked,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l.aiEditBaseUrl,
                        suffixIcon: presetUrlLocked
                            ? TextButton(
                                onPressed: () =>
                                    setState(() => _urlUnlocked = true),
                                child: Text(l.commonEdit),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _model,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: l.aiEditModel),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _busy || _url.text.trim().isEmpty
                            ? null
                            : _fetchModels,
                        child: Text(l.aiEditFetchModels),
                      ),
                    ),
                    if (_fetchFailed)
                      Text(
                        l.aiEditFetchFailed,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _key,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l.aiEditKey,
                        helperText: _hasKey && _key.text.isEmpty
                            ? l.aiEditKeySaved
                            : null,
                        suffixIcon: HmmIconButton(
                          icon: Icons.content_paste,
                          tooltip: l.aiEditKeyPaste,
                          onPressed: _paste,
                        ),
                      ),
                    ),
                    if (_hasKey)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: _removeKey,
                          child: Text(l.aiEditRemoveKey),
                        ),
                      ),
                    if (_custom) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.aiEditVision),
                        value: _vision,
                        onChanged: (v) => setState(() => _vision = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.aiEditPdf),
                        value: _pdf,
                        onChanged: (v) => setState(() => _pdf = v),
                      ),
                    ],
                    if (!isDefault)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.aiEditMakeDefault),
                        value: _makeDefault,
                        onChanged: (v) => setState(() => _makeDefault = v),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.network_check),
                      label: Text(l.aiEditTest),
                      onPressed: _canSave ? _test : null,
                    ),
                    if (_testResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testOk
                                ? null
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('aiSave'),
                      onPressed: _canSave ? _save : null,
                      child: Text(l.commonSave),
                    ),
                    if (!_isNew)
                      ListTile(
                        key: const Key('aiDelete'),
                        contentPadding: EdgeInsets.zero,
                        iconColor: Theme.of(context).colorScheme.error,
                        textColor: Theme.of(context).colorScheme.error,
                        leading: const Icon(Icons.delete_outline),
                        title: Text(l.commonDelete),
                        onTap: _delete,
                      ),
                    const SizedBox(height: 24),
                  ],
          ),
        ),
      ],
    );
  }
}
