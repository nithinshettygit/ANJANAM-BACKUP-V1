import 'app_exception.dart';

class Result<T> {
  final T? data;
  final AppException? error;

  const Result._({required this.data, required this.error});

  bool get isSuccess => error == null;

  static Result<T> ok<T>(T data) => Result<T>._(data: data, error: null);
  static Result<T> err<T>(AppException error) => Result<T>._(data: null, error: error);
}

