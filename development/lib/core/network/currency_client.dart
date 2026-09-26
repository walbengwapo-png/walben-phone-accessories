import 'package:dio/dio.dart';

class CurrencyRates {
  const CurrencyRates({
    required this.date,
    required this.usd,
    required this.eur,
  });
  final String date;
  final double usd;
  final double eur;
}

class CurrencyClient {
  CurrencyClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.frankfurter.dev',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  Future<CurrencyRates> phpRates() async {
    final responses = await Future.wait([
      _dio.get<dynamic>('/v2/rate/PHP/USD'),
      _dio.get<dynamic>('/v2/rate/PHP/EUR'),
    ]);
    final usd = _parse(responses[0].data, 'USD');
    final eur = _parse(responses[1].data, 'EUR');
    if (usd.$1 != eur.$1) {
      throw const FormatException('Currency rate dates do not match.');
    }
    return CurrencyRates(date: usd.$1, usd: usd.$2, eur: eur.$2);
  }

  (String, double) _parse(dynamic data, String quote) {
    if (data is! Map ||
        data['base'] != 'PHP' ||
        data['quote'] != quote ||
        data['date'] is! String ||
        data['rate'] is! num) {
      throw const FormatException('Invalid currency rate response.');
    }
    final rate = (data['rate'] as num).toDouble();
    if (!rate.isFinite || rate <= 0) {
      throw const FormatException('Invalid currency rate.');
    }
    return (data['date'] as String, rate);
  }
}
