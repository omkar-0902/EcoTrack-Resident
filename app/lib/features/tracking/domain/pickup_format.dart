import 'package:intl/intl.dart';

/// The fixed municipal collection window the app already communicates to
/// residents (previously hard-coded in the confirmation view). Not a backend
/// field.
const String kCollectionWindow = '7 AM - 10 AM';

/// "Today", "Tomorrow", or e.g. "November 4".
String relativePickupDay(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateFormat('yyyy-MM-dd');
  if (day.format(date) == day.format(today)) return 'Today';
  if (day.format(date) == day.format(today.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  return DateFormat('MMMM d').format(date);
}

/// e.g. "Nov 1, 12:40 PM".
String formatEventTime(DateTime time) =>
    DateFormat('MMM d, h:mm a').format(time);

/// e.g. "12:40 PM".
String formatClockTime(DateTime time) => DateFormat('h:mm a').format(time);
