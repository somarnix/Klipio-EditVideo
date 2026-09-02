import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/application/timeline_scrub_controller.dart';

void main() {
  test('drag updates are coalesced and release performs one exact seek',
      () async {
    final calls = <({Duration position, bool exact})>[];
    final firstSeek = Completer<void>();
    var approximateCount = 0;
    final controller = TimelineScrubController(
      minimumSeekInterval: Duration.zero,
      onSeek: (position, exact) async {
        calls.add((position: position, exact: exact));
        if (!exact && approximateCount++ == 0) await firstSeek.future;
      },
    );

    controller.begin(const Duration(seconds: 1));
    controller.update(const Duration(seconds: 2));
    controller.update(const Duration(seconds: 3));
    expect(controller.playhead.value, const Duration(seconds: 3));
    expect(calls.where((call) => !call.exact).length, 1);

    final ending = controller.end(const Duration(milliseconds: 3500));
    firstSeek.complete();
    await ending;

    expect(calls.last.exact, isTrue);
    expect(calls.last.position, const Duration(milliseconds: 3500));
    expect(calls.where((call) => call.exact).length, 1);
    controller.dispose();
  });
}
