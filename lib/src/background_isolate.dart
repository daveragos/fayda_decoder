import 'dart:async';
import 'dart:isolate';

/// Runs [computation] on a short-lived isolate.
Future<T> run<T>(FutureOr<T> Function() computation) =>
    Isolate.run(computation, debugName: 'fayda_decoder');
