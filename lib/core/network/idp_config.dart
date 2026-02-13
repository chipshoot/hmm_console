class IdpConfig {
  const IdpConfig({
    required this.authority,
    required this.clientId,
    required this.clientSecret,
    required this.scopes,
  });

  final String authority;
  final String clientId;
  final String clientSecret;
  final String scopes;

  String get tokenEndpoint => '$authority/connect/token';

  static const production = IdpConfig(
    authority: 'https://auth.homemademessage.com',
    clientId: 'hmm.web',
    clientSecret: '',
    scopes: 'openid profile hmm.api offline_access',
  );

  static const development = IdpConfig(
    authority: 'https://localhost:5001',
    clientId: 'hmm.functest',
    clientSecret: 'hmm.functest.secret',
    scopes: 'openid profile hmm.api offline_access',
  );
}
