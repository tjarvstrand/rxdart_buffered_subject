## Features

`BufferedSubject` - An RxDart-based broadcast StreamController that caches the added values while there are no 
listeners. When the first new listener subscribes to the Stream, the cached values will be emitted to the listener.

## Usage
```dart
final subject = BufferedSubject<int>();
subject.add(1);
subject.add(2);
subject.add(3);
subject.stream.listen(() {...}) // <-- Will get events 1, 2 and 3
```
