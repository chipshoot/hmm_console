import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/core.dart';

class SocialLogin extends StatelessWidget {
  const SocialLogin({super.key, this.onGoogleLogin, this.onAppleLogin});

  final VoidCallback? onGoogleLogin;
  final VoidCallback? onAppleLogin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        OutlinedButton(onPressed: onGoogleLogin, child: Text(l.authGoogle)),
        GapWidgets.w16,
        OutlinedButton(onPressed: onAppleLogin, child: Text(l.authApple)),
      ],
    );
  }
}
