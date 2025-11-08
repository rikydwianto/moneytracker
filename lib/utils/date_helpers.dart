import 'package:intl/intl.dart';

/// Helper to safely create DateFormat with Indonesian locale
/// Falls back to default locale if id_ID is not initialized
class DateHelpers {
  static DateFormat getDateFormat(String pattern) {
    try {
      return DateFormat(pattern, 'id_ID');
    } catch (e) {
      // Fallback to default locale if id_ID is not initialized yet
      return DateFormat(pattern);
    }
  }

  static DateFormat get shortDate => getDateFormat('d MMM yyyy');
  static DateFormat get longDate => getDateFormat('d MMMM yyyy');
  static DateFormat get dateTime => getDateFormat('dd MMM yyyy HH:mm');
  static DateFormat get fullDateTime => getDateFormat('dd MMMM yyyy HH:mm');
  static DateFormat get dateOnly => getDateFormat('dd MMM yyyy');

  // Format datetime for display
  static String format(DateTime date) {
    return dateTime.format(date);
  }

  // Format relative time like "2 menit yang lalu", "1 jam yang lalu", etc.
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Kemarin';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} hari yang lalu';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return weeks == 1 ? '1 minggu yang lalu' : '$weeks minggu yang lalu';
      } else {
        return shortDate.format(date);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
