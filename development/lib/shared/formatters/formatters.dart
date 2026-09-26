import 'package:intl/intl.dart';

final _peso = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);
String peso(dynamic amount) => _peso.format(_number(amount));
num _number(dynamic value) =>
    value is num ? value : num.tryParse('$value') ?? 0;
String statusLabel(dynamic value) => '$value'
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
String localDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null
      ? '—'
      : DateFormat.yMMMd().add_jm().format(date.toLocal());
}
