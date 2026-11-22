import '../contract/glucose_repository_contract.dart';
import 'fake_glucose_repository.dart';

void main() {
  runGlucoseRepositoryContract(() async => FakeGlucoseRepository());
}
