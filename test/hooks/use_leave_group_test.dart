import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whitenoise/hooks/use_leave_group.dart';
import 'package:whitenoise/src/rust/api/error.dart';
import 'package:whitenoise/src/rust/frb_generated.dart';

import '../mocks/mock_wn_api.dart';
import '../test_helpers.dart';

class _MockApi extends MockWnApi {
  bool shouldThrow = false;
  bool wasLeaveCalled = false;
  String? passedPubkey;
  String? passedGroupId;
  Completer<void>? leaveCompleter;

  @override
  Future<void> crateApiGroupsLeaveGroup({
    required String pubkey,
    required String groupId,
  }) async {
    wasLeaveCalled = true;
    passedPubkey = pubkey;
    passedGroupId = groupId;

    if (leaveCompleter != null) {
      await leaveCompleter!.future;
    }

    if (shouldThrow) {
      throw const ApiError.other(message: 'Failed to leave group');
    }
  }
}

void main() {
  final mockApi = _MockApi();

  setUpAll(() {
    RustLib.initMock(api: mockApi);
  });

  setUp(() {
    mockApi.shouldThrow = false;
    mockApi.wasLeaveCalled = false;
    mockApi.passedPubkey = null;
    mockApi.passedGroupId = null;
    mockApi.leaveCompleter = null;
  });

  testWidgets('initial state is not loading', (tester) async {
    final hook = await mountHook(
      tester,
      () => useLeaveGroup(accountPubkey: 'abc_pubkey', groupId: 'test_group'),
    );

    expect(hook().isLoading, isFalse);
    expect(mockApi.wasLeaveCalled, isFalse);
  });

  testWidgets('leaveGroup success sets loading true then false', (
    tester,
  ) async {
    mockApi.leaveCompleter = Completer<void>();

    final hook = await mountHook(
      tester,
      () => useLeaveGroup(accountPubkey: 'abc_pubkey', groupId: 'test_group'),
    );

    final future = hook().leaveGroup();

    await tester.pump();
    expect(hook().isLoading, isTrue);

    mockApi.leaveCompleter!.complete();
    await future;

    await tester.pump();
    expect(hook().isLoading, isFalse);

    expect(mockApi.wasLeaveCalled, isTrue);
    expect(mockApi.passedPubkey, 'abc_pubkey');
    expect(mockApi.passedGroupId, 'test_group');
  });

  testWidgets('leaveGroup error throws and resets loading', (tester) async {
    mockApi.leaveCompleter = Completer<void>();
    mockApi.shouldThrow = true;

    final hook = await mountHook(
      tester,
      () => useLeaveGroup(accountPubkey: 'abc_pubkey', groupId: 'test_group'),
    );

    final future = hook().leaveGroup();

    await tester.pump();
    expect(hook().isLoading, isTrue);

    mockApi.leaveCompleter!.complete();
    await expectLater(future, throwsA(isA<ApiError>()));

    await tester.pump();
    expect(hook().isLoading, isFalse);
    expect(mockApi.wasLeaveCalled, isTrue);
  });

  testWidgets('does not crash if unmounted during leaveGroup', (tester) async {
    mockApi.leaveCompleter = Completer<void>();

    final hook = await mountHook(
      tester,
      () => useLeaveGroup(accountPubkey: 'abc_pubkey', groupId: 'test_group'),
    );

    final future = hook().leaveGroup();
    await tester.pump();
    await tester.pumpWidget(const SizedBox()); // Unmount the widget
    mockApi.leaveCompleter!.complete();
    await future;
    expect(hook().isLoading, isTrue);
  });
}
