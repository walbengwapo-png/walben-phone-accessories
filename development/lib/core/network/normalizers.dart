/// Defensive normalization for SQL-JSON values returned by the PHP API.
/// SQL/JSON may hand back values as int, String, or bool depending on the driver.
library;

int? normInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

num normNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

bool normBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return v == 1 || v == '1' || v == 'true' || v == 'TRUE';
}

String normStr(dynamic v) => v == null ? '' : '$v';

String? normStrNull(dynamic v) {
  final s = '$v';
  if (v == null || s.isEmpty || s == 'null') return null;
  return s;
}
