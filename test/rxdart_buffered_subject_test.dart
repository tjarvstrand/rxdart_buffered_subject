// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import 'dart:async';
import 'dart:collection';

import 'package:rxdart/rxdart.dart';
import 'package:rxdart_buffered_subject/rxdart_buffered_subject.dart';
import 'package:test/test.dart';

void main() {
  group('BufferedSubject', () {
    test('replays the buffered items to first subscriber', () async {
      final subject = BufferedSubject<int>()
        ..add(1)
        ..add(2)
        ..add(3);
      await expectLater(subject.stream, emitsInOrder(const <int>[1, 2, 3]));

      subject
        ..add(4)
        ..add(5);
      await expectLater(subject.stream, emitsInOrder(const <int>[4, 5]));
    });

    test('replays the buffered items to first subscriber, includes null', () async {
      final subject = BufferedSubject<int?>()
        ..add(null)
        ..add(1)
        ..add(2)
        ..add(3)
        ..add(null);

      await expectLater(
        subject.stream,
        emitsInOrder(const <int?>[null, 1, 2, 3, null]),
      );
      subject.add(4);
      await expectLater(
        subject.stream,
        emitsInOrder(const <int?>[4]),
      );
    });

    test('replays the buffered errors to first subscriber', () async {
      final subject = BufferedSubject<int>()
        ..addError(Exception())
        ..addError(Exception())
        ..addError(Exception());

      await expectLater(subject.stream,
          emitsInOrder(<StreamMatcher>[emitsError(isException), emitsError(isException), emitsError(isException)]));
      subject.addError(Exception());
      await expectLater(subject.stream, emitsInOrder(<StreamMatcher>[emitsError(isException)]));
    });

    test('replays the buffered items to first subscriber that directly subscribes to the Subject', () async {
      final subject = BufferedSubject<int>()
        ..add(1)
        ..add(2)
        ..add(3);

      await expectLater(subject, emitsInOrder(const <int>[1, 2, 3]));
      subject.add(4);
      await expectLater(subject, emitsInOrder(const <int>[4]));
    });

    test('replays the buffered items and errors to the first subscriber directly subscribing to the Subject', () async {
      final subject = BufferedSubject<int>()
        ..add(1)
        ..addError(Exception())
        ..addError(Exception())
        ..add(2);

      await expectLater(subject, emitsInOrder(<dynamic>[1, emitsError(isException), emitsError(isException), 2]));
      subject
        ..addError(Exception())
        ..add(3);
      await expectLater(subject, emitsInOrder(<dynamic>[emitsError(isException), 3]));
    });

    test('replays the most recently emitted items up to a max size', () async {
      final subject = BufferedSubject<int>(maxSize: 2)
        ..add(1) // Should be dropped
        ..add(2)
        ..add(3);

      await expectLater(subject.stream, emitsInOrder(const <int>[2, 3]));
      subject.add(4);
      await expectLater(subject.stream, emitsInOrder(const <int>[4]));
    });

    test('replays the most recently emitted items up to a max age', () async {
      // One timestamp call for add+truncateBuffer for each element and then one for onListen
      final timestamps = Queue.of([
        0, 0, // First event add + truncateBuffer
        1, 1, // Second event add + truncateBuffer
        2, 2, // Third event add + truncateBuffer
        3, // onListen 1
        4, 4, // Fourth event add + truncateBuffer
        5 // onListen 2
      ]);

      final subject = BufferedSubject<int>(
        maxAge: const Duration(microseconds: 2),
        timeStampFun: timestamps.removeFirst,
      )
        ..add(1) // Should be dropped
        ..add(2)
        ..add(3);

      await expectLater(subject.stream, emitsInOrder(const <int>[2, 3])).timeout(const Duration(seconds: 3));
      subject.add(4);
      await expectLater(subject.stream, emitsInOrder(const <int>[4]));
    });

    test('emits done event to listeners when the subject is closed', () async {
      final subject = BufferedSubject<int>();

      await expectLater(subject.isClosed, isFalse);

      subject.add(1);
      scheduleMicrotask(subject.close);

      await expectLater(subject.stream, emitsInOrder(<dynamic>[1, emitsDone]));
      await expectLater(subject.isClosed, isTrue);
    });

    test('emits error events to subscribers', () async {
      final subject = BufferedSubject<int>();

      scheduleMicrotask(() => subject.addError(Exception()));

      await expectLater(subject.stream, emitsError(isException));
    });

    test('replays the buffered items from addStream', () async {
      final subject = BufferedSubject<int>();

      await subject.addStream(Stream<int>.fromIterable(const [1, 2, 3]));

      await expectLater(subject.stream, emitsInOrder(const <int>[1, 2, 3]));
      subject.add(4);
      await expectLater(subject.stream, emitsInOrder(const <int>[4]));
    });

    test('allows items to be added once addStream is complete and there is no listener', () async {
      final subject = BufferedSubject<int>();

      await subject.addStream(Stream.fromIterable(const [1, 2]));
      subject.add(3);

      await expectLater(subject.stream, emitsInOrder(const <int>[1, 2, 3]));
    });

    test('allows items to be added once addStream completes with an error and there is no listener', () async {
      final subject = BufferedSubject<int>();
      await subject.addStream(Stream<int>.error(Exception()), cancelOnError: true).whenComplete(() => subject.add(1));
      await expectLater(subject.stream, emitsInOrder(<StreamMatcher>[emitsError(isException), emits(1)]));
    });

    test('does not allow events to be added when addStream is active and there is no listener', () async {
      final subject = BufferedSubject<int>()
        // Purposely don't wait for the future to complete, then try to add items
        // ignore: unawaited_futures
        ..addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.add(1), throwsStateError);
    });

    test('does not allow errors to be added when addStream is active and there is no listener', () async {
      final subject = BufferedSubject<int>()
        // Purposely don't wait for the future to complete, then try to add items
        // ignore: unawaited_futures
        ..addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.addError(Error()), throwsStateError);
    });

    test('does not allow subject to be closed when addStream is active and there is no listener', () async {
      final subject = BufferedSubject<int>()
        // Purposely don't wait for the future to complete, then try to add items
        // ignore: unawaited_futures
        ..addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(subject.close, throwsStateError);
    });

    test('does not allow addStream to add items when previous addStream is active and there is no listener', () async {
      final subject = BufferedSubject<int>()
        // Purposely don't wait for the future to complete, then try to add items
        // ignore: unawaited_futures
        ..addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.addStream(Stream.fromIterable(const [1])), throwsStateError);
    });

    test('allows items to be added once addStream is complete and there are listeners', () async {
      final subject = BufferedSubject<int>();
      final result = expectLater(subject.stream, emitsInOrder(const <int>[1, 2, 3]));

      await subject.addStream(Stream.fromIterable(const [1, 2]));
      subject.add(3);

      await result;
    });

    test('allows items to be added once addStream completes with an error and there are listeners', () async {
      final subject = BufferedSubject<int>();
      final result = expectLater(subject.stream, emitsInOrder(<StreamMatcher>[emitsError(isException), emits(1)]));
      await subject.addStream(Stream<int>.error(Exception()), cancelOnError: true).whenComplete(() => subject.add(1));
      await result;
    });

    test('does not allow events to be added when addStream is active and there are listeners', () async {
      final subject = BufferedSubject<int>();
      final sub = subject.listen((_) {});

      // Purposely don't wait for the future to complete, then try to add items
      unawaited(subject.addStream(Stream.fromIterable(const [1, 2, 3])));

      await expectLater(() => subject.add(1), throwsStateError);
      await sub.cancel();
    });

    test('does not allow errors to be added when addStream is active and there are listeners', () async {
      final subject = BufferedSubject<int>();
      final sub = subject.listen((_) {});

      // Purposely don't wait for the future to complete, then try to add items
      unawaited(subject.addStream(Stream.fromIterable(const [1, 2, 3])));

      await expectLater(() => subject.addError(Error()), throwsStateError);
      await sub.cancel();
    });

    test('does not allow subject to be closed when addStream is active and there are listeners', () async {
      final subject = BufferedSubject<int>();
      final sub = subject.listen((_) {});

      // Purposely don't wait for the future to complete, then try to add items
      unawaited(subject.addStream(Stream.fromIterable(const [1, 2, 3])));

      await expectLater(subject.close, throwsStateError);
      await sub.cancel();
    });

    test('does not allow addStream to add items when previous addStream is active and there are listeners', () async {
      final subject = BufferedSubject<int>();
      final sub = subject.listen((_) {});

      // Purposely don't wait for the future to complete, then try to add items
      // ignore: unawaited_futures
      subject.addStream(Stream.fromIterable(const [1, 2, 3]));

      await expectLater(() => subject.addStream(Stream.fromIterable(const [1])), throwsStateError);
      await sub.cancel();
    });

    test('returns onListen callback set in constructor', () async {
      void testOnListen() {}

      final subject = BufferedSubject<int>(onListen: testOnListen);

      await expectLater(subject.onListen, testOnListen);
    });

    test('sets onListen callback', () async {
      void testOnListen() {}

      final subject = BufferedSubject<int>();

      await expectLater(subject.onListen, isNull);

      subject.onListen = testOnListen;

      await expectLater(subject.onListen, testOnListen);
    });

    test('returns onCancel callback set in constructor', () async {
      Future<void> onCancel() => Future<void>.value(null);

      final subject = BufferedSubject<void>(onCancel: onCancel);

      await expectLater(subject.onCancel, onCancel);
    });

    test('sets onCancel callback', () async {
      void testOnCancel() {}

      final subject = BufferedSubject<void>();

      await expectLater(subject.onCancel, isNull);

      subject.onCancel = testOnCancel;

      await expectLater(subject.onCancel, testOnCancel);
    });

    test('reports if a listener is present', () async {
      final subject = BufferedSubject<void>();

      await expectLater(subject.hasListener, isFalse);

      subject.stream.listen(null);

      await expectLater(subject.hasListener, isTrue);
    });

    test('onPause unsupported', () {
      final subject = BufferedSubject<void>();

      expect(subject.isPaused, isFalse);
      expect(() => subject.onPause, throwsUnsupportedError);
      expect(() => subject.onPause = () {}, throwsUnsupportedError);
    });

    test('onResume unsupported', () {
      final subject = BufferedSubject<void>();

      expect(() => subject.onResume, throwsUnsupportedError);
      expect(() => subject.onResume = () {}, throwsUnsupportedError);
    });

    test('returns controller sink', () async {
      final subject = BufferedSubject<int>();

      await expectLater(subject.sink, const TypeMatcher<EventSink<int>>());
    });

    test('correctly closes done Future', () async {
      final subject = BufferedSubject<int>();

      scheduleMicrotask(subject.close);

      await expectLater(subject.done, completes);
    });

    test('can be listened to multiple times', () async {
      final subject = BufferedSubject<int>();
      final stream = subject.stream;

      subject
        ..add(1)
        ..add(2);

      await expectLater(stream, emitsInOrder(const <int>[1, 2]));
      subject.add(3);
      await expectLater(stream, emitsInOrder(const <int>[3]));
    });

    test('always returns the same stream', () async {
      final subject = BufferedSubject<int>();

      await expectLater(subject.stream, equals(subject.stream));
    });

    test('is always treated as a broadcast Stream', () async {
      final subject = BufferedSubject<int>();
      final stream = subject.asyncMap(Future.value);

      expect(subject.isBroadcast, isTrue);
      expect(stream.isBroadcast, isTrue);
    });

    test('rxdart issue/419: sync behavior', () async {
      final subject = BufferedSubject<int>(sync: true)..add(1);
      final mappedStream = subject.map((event) => event).shareValue()..listen(null);

      expect(mappedStream.value, equals(1));

      await subject.close();
    });

    test('rxdart issue/419: sync throughput', () async {
      final subject = BufferedSubject<int>(sync: true)..add(1);
      final mappedStream = subject.map((event) => event).shareValue()..listen(null);

      subject.add(2);

      expect(mappedStream.value, equals(2));

      await subject.close();
    });

    test('rxdart issue/419: async behavior', () async {
      final subject = BufferedSubject<int>()..add(1);
      final mappedStream = subject.map((event) => event).shareValue();

      mappedStream.listen(null, onDone: () => expect(mappedStream.value, equals(1)));

      expect(mappedStream.valueOrNull, isNull);

      await subject.close();
    });

    test('rxdart issue/419: async throughput', () async {
      final subject = BufferedSubject<int>()..add(1);
      final mappedStream = subject.map((event) => event).shareValue();

      mappedStream.listen(null, onDone: () => expect(mappedStream.value, equals(2)));

      subject.add(2);

      expect(mappedStream.valueOrNull, isNull);

      await subject.close();
    });
  });
}
