import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/data/contact_derived_fields.dart';
import '../domain/derived_field_registry.dart';

/// Every feature's derived cheatsheet fields. Riverpod is the app's only DI,
/// so features register here rather than into a global at startup.
final derivedFieldRegistryProvider = Provider<DerivedFieldRegistry>(
  (ref) => const DerivedFieldRegistry({...contactDerivedFields}),
);
