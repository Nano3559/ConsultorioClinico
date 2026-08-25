import 'package:intl/intl.dart';

/// Formateadores y helpers de fecha.
class AppFormatters {
  AppFormatters._();

  static final DateFormat _day = DateFormat('EEEE d', 'es');
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy');
  static final DateFormat _month = DateFormat('MMMM yyyy', 'es');
  static final DateFormat _dayMonth = DateFormat('d MMM', 'es');

  static String day(DateTime d) => _day.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String month(DateTime d) => _month.format(d);

  static String initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String money(num value) {
    final f = NumberFormat('#,##0', 'es');
    return 'Gs ${f.format(value)}';
  }
}