import 'package:flutter/foundation.dart';

enum LlmRole { user, assistant, tool }

@immutable
sealed class LlmPart {
  const LlmPart();
}

class TextPart extends LlmPart {
  const TextPart(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is TextPart && other.text == text;

  @override
  int get hashCode => Object.hash(TextPart, text);
}

class ImagePart extends LlmPart {
  const ImagePart(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;

  @override
  bool operator ==(Object other) =>
      other is ImagePart &&
      other.mimeType == mimeType &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(ImagePart, mimeType, Object.hashAll(bytes));
}

class DocumentPart extends LlmPart {
  const DocumentPart(this.bytes, {this.mimeType = 'application/pdf'});
  final Uint8List bytes;
  final String mimeType;

  @override
  bool operator ==(Object other) =>
      other is DocumentPart &&
      other.mimeType == mimeType &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode =>
      Object.hash(DocumentPart, mimeType, Object.hashAll(bytes));
}

class ToolCallPart extends LlmPart {
  const ToolCallPart(this.id, this.name, this.argumentsJson);
  final String id;
  final String name;
  final String argumentsJson;

  @override
  bool operator ==(Object other) =>
      other is ToolCallPart &&
      other.id == id &&
      other.name == name &&
      other.argumentsJson == argumentsJson;

  @override
  int get hashCode => Object.hash(ToolCallPart, id, name, argumentsJson);
}

class ToolResultPart extends LlmPart {
  const ToolResultPart(this.callId, this.contentJson);
  final String callId;
  final String contentJson;

  @override
  bool operator ==(Object other) =>
      other is ToolResultPart &&
      other.callId == callId &&
      other.contentJson == contentJson;

  @override
  int get hashCode => Object.hash(ToolResultPart, callId, contentJson);
}

@immutable
class LlmMessage {
  const LlmMessage({required this.role, required this.parts});

  LlmMessage.user(String text) : role = LlmRole.user, parts = [TextPart(text)];

  final LlmRole role;
  final List<LlmPart> parts;

  @override
  bool operator ==(Object other) =>
      other is LlmMessage &&
      other.role == role &&
      listEquals(other.parts, parts);

  @override
  int get hashCode => Object.hash(role, Object.hashAll(parts));
}
