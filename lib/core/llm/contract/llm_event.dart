import 'package:flutter/foundation.dart';

import 'llm_response.dart';

@immutable
sealed class LlmEvent {
  const LlmEvent();
}

class TextDelta extends LlmEvent {
  const TextDelta(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is TextDelta && other.text == text;

  @override
  int get hashCode => Object.hash(TextDelta, text);
}

class Completed extends LlmEvent {
  const Completed(this.response);
  final LlmResponse response;

  @override
  bool operator ==(Object other) =>
      other is Completed && other.response == response;

  @override
  int get hashCode => Object.hash(Completed, response);
}
