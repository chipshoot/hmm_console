import '../domain/driver_licence.dart';

/// Storage for the single driver's licence.
///
/// Pure persistence: the caller hands over a licence whose image refs are
/// already in the vault, and this writes the content and the attachments
/// column. Picking bytes, persisting them and deleting removed ones lives in
/// the state notifier, the same split the insurance and service-record
/// features use — a repository that also drove the vault would need the
/// picker's FutureProvider and would force every repository provider in the
/// app to become async.
abstract interface class IDriverLicenceRepository {
  /// The stored licence, or null when nothing has been saved yet.
  Future<DriverLicence?> getLicence();

  /// Creates the licence note or updates the existing one. Never creates a
  /// second: the subject is fixed.
  Future<DriverLicence> saveLicence(DriverLicence licence);
}
