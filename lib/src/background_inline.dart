import 'dart:async';

/// Runs [computation] on the current thread after yielding to the event loop.
Future<T> run<T>(FutureOr<T> Function() computation) => Future<T>(computation);
