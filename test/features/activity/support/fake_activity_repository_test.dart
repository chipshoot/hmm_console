import '../contract/activity_repository_contract.dart';
import 'fake_activity_repository.dart';

void main() {
  runActivityRepositoryContract(() async => FakeActivityRepository());
}
