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
