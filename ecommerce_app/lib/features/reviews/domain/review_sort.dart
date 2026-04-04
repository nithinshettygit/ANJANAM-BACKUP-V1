enum ReviewSort {
  recent,
  high,
  low;

  String get apiValue {
    switch (this) {
      case ReviewSort.recent:
        return 'recent';
      case ReviewSort.high:
        return 'high';
      case ReviewSort.low:
        return 'low';
    }
  }

  String get label {
    switch (this) {
      case ReviewSort.recent:
        return 'Most recent';
      case ReviewSort.high:
        return 'Highest rating';
      case ReviewSort.low:
        return 'Lowest rating';
    }
  }
}
