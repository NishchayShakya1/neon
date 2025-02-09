import 'package:meta/meta.dart';

@immutable
class Result<T> {
  Result(
    this.data,
    this.error, {
    required this.isLoading,
    required this.isCached,
  }) : assert(
          T != Never,
          'Result() called without specifying the data type. Call Result<T>() instead',
        );

  Result.loading()
      : data = null,
        error = null,
        isLoading = true,
        isCached = false,
        assert(
          T != Never,
          'Result.loading() called without specifying the data type. Call Result<T>.loading() instead',
        );

  Result.success(this.data)
      : error = null,
        isLoading = false,
        isCached = false,
        assert(
          T != Never,
          'Result.success() called without specifying the data type. Call Result<T>.success() instead',
        );

  Result.error(this.error)
      : data = null,
        isLoading = false,
        isCached = false,
        assert(
          T != Never,
          'Result.error() called without specifying the data type. Call Result<T>.error() instead',
        );

  final T? data;
  final Object? error;
  final bool isLoading;
  final bool isCached;

  Result<R> transform<R>(final R? Function(T data) call) => Result(
        hasData ? call(data as T) : null,
        error,
        isLoading: isLoading,
        isCached: isCached,
      );

  Result<T> asLoading() => copyWith(isLoading: true);

  Result<T> copyWith({
    final T? data,
    final Object? error,
    final bool? isLoading,
    final bool? isCached,
  }) =>
      Result(
        data ?? this.data,
        error ?? this.error,
        isLoading: isLoading ?? this.isLoading,
        isCached: isCached ?? this.isCached,
      );

  bool get hasError => error != null;

  bool get hasData => data != null;

  bool get hasUncachedData => hasData && !isCached;

  T get requireData {
    if (hasData) {
      return data!;
    }

    throw StateError('Result has no data');
  }

  @override
  bool operator ==(final Object other) =>
      other is Result && other.isLoading == isLoading && other.data == data && other.error == error;

  @override
  int get hashCode => Object.hash(data, error, isLoading, isCached);
}
