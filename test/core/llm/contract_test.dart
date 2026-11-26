import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';

void main() {
  test('request refuses tools in v1', () {
    expect(
      () => LlmRequest(
        messages: [LlmMessage.user('hi')],
        containsSensitive: false,
        tools: [LlmToolSpec(name: 't', description: 'd', inputSchema: {})],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('hasImages / hasDocuments', () {
    final r = LlmRequest(
      containsSensitive: false,
      messages: [
        LlmMessage(
          role: LlmRole.user,
          parts: [ImagePart(Uint8List(1), 'image/jpeg')],
        ),
      ],
    );
    expect(r.hasImages, isTrue);
    expect(r.hasDocuments, isFalse);
    final d = LlmRequest(
      containsSensitive: false,
      messages: [
        LlmMessage(role: LlmRole.user, parts: [DocumentPart(Uint8List(1))]),
      ],
    );
    expect(d.hasDocuments, isTrue);
    expect(d.hasImages, isFalse);
  });

  test('LlmMessage.user makes one text part', () {
    final m = LlmMessage.user('hi');
    expect(m.role, LlmRole.user);
    expect(m.parts, [const TextPart('hi')]);
  });

  test('byte parts compare by content', () {
    expect(
      ImagePart(Uint8List.fromList([1, 2]), 'image/png'),
      ImagePart(Uint8List.fromList([1, 2]), 'image/png'),
    );
    expect(
      ImagePart(Uint8List.fromList([1, 2]), 'image/png'),
      isNot(ImagePart(Uint8List.fromList([1, 3]), 'image/png')),
    );
    expect(
      DocumentPart(Uint8List.fromList([1])).hashCode,
      DocumentPart(Uint8List.fromList([1])).hashCode,
    );
  });

  test('exception toString leaks nothing', () {
    expect(LlmBadResponse('secret body').toString(), isNot(contains('secret')));
    expect(
      LlmBadResponse('x').withEngine('mine').toString(),
      'LlmBadResponse(mine)',
    );
  });

  test('withEngine keeps subclass and sets label', () {
    final e = LlmRateLimited(
      retryAfter: const Duration(seconds: 3),
    ).withEngine('e1');
    expect(e, isA<LlmRateLimited>());
    expect(e.engineLabel, 'e1');
    expect((e as LlmRateLimited).retryAfter, const Duration(seconds: 3));
    expect(
      LlmUnsupported(LlmCapability.pdf).withEngine('x'),
      isA<LlmUnsupported>(),
    );
    expect(LlmCancelled().engineLabel, isNull);
  });

  test('capabilities round-trip', () {
    const c = LlmCapabilities(
      vision: true,
      pdf: false,
      streaming: true,
      structuredOutput: StructuredOutput.jsonMode,
    );
    expect(LlmCapabilities.fromJson(c.toJson()), c);
    expect(LlmCapabilities.fromJson(c.toJson()).tools, isFalse);
  });

  test('value equality of response, schema and events', () {
    expect(
      const LlmResponse(text: 'a', stopReason: LlmStopReason.end),
      const LlmResponse(text: 'a', stopReason: LlmStopReason.end),
    );
    expect(const TextDelta('x'), const TextDelta('x'));
    expect(
      const LlmJsonSchema(name: 'n', schema: {'type': 'object'}),
      const LlmJsonSchema(name: 'n', schema: {'type': 'object'}),
    );
    expect(const LlmUsage(inputTokens: 1), const LlmUsage(inputTokens: 1));
  });
}
