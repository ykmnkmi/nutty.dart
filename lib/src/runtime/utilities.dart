import 'package:meta/dart2js.dart';

void noop() {
  // ...
}

@tryInline
@pragma('dart2js:as:trust')
T unsafeCast<T>(Object? value) {
  return value as T;
}
