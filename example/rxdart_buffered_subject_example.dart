import 'dart:async';

import 'package:rxdart_buffered_subject/rxdart_buffered_subject.dart';

Future<void> main() async {
       final subject = BufferedSubject<int>();

       subject.add(1);
       subject.add(2);
       subject.add(3);

       final completer = Completer<void>();
       final StreamSubscription subscription = subject.stream.listen((event) {
         print(event);
         if (event == 3) {
           completer.complete();
         }
       }); // prints 1, 2, 3

       await completer.future;
       await subscription.cancel();

       subject.add(4);
       subject.stream.listen(print); // prints 4
}
