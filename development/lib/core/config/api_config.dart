class ApiConfig {
  const ApiConfig._();

  static const _configured = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://wbenogsudan.duckdns.org',
  );

  static String get baseUrl => _configured.replaceFirst(RegExp(r'/+$'), '');
}
