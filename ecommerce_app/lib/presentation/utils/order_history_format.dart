String formatShortOrderDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final d = dateTime.toLocal();
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
