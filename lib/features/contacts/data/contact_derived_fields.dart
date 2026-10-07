import '../../cheatsheet/domain/derived_field_registry.dart';
import 'contact_codec.dart';

/// `Contact.displayName` in the contact's name order, so a card bound to it
/// shows 张伟 even while the stored value is still the legacy "伟 张"
/// (no bulk rewrite). Null on an empty name or any decode failure, so the
/// row falls back to the stored value.
String? contactDisplayNameField(Map<String, dynamic> entity) {
  try {
    final name = ContactCodec.fromMap(entity).displayName;
    return name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
}

const contactDerivedFields = <String, Map<String, DerivedFieldResolver>>{
  'Contact': {'displayName': contactDisplayNameField},
};
