String? routeQueryParameter(String? name, String parameter) {
  if (name == null || name.isEmpty || !name.contains('?')) return null;
  try {
    return Uri.parse('http://placeholder$name').queryParameters[parameter];
  } on FormatException {
    return null;
  }
}
