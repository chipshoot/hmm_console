import 'validators.dart';

mixin EmailPassValidator {
  String? validateEmail(String? email) {
    return Validators.validateEmail(email);
  }

  String? validatePassword(String? password) {
    return Validators.validatePassword(password);
  }
}
