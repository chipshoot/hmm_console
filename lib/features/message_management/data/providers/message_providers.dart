import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/i_message_provider.dart';
import '../../domain/providers/message_provider.dart';
import '../repositories/i_message_repository.dart';
import '../repositories/local_message_repository.dart';

final messageRepositoryProvider = Provider<IMessageRepository>(
  (ref) => LocalMessageRepository(),
);

final messageProviderProvider = Provider<IMessageProvider>(
  (ref) => MessageProvider(ref.watch(messageRepositoryProvider)),
);
