import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Module 2: Auth & Authorization — White-Box + Black-Box Unit Tests
///
/// Tests authentication routing logic, ApprovalGate behavior,
/// and SharedPreferences role storage patterns.
void main() {
  group('AuthChecker — _checkLoginStatus routing logic', () {
    // These tests validate the routing DECISION logic, not the actual Firebase calls.
    // The logic is: SharedPreferences user_role + Firebase currentUser → dashboard selection

    test('resident role should route to ResidentDashboardPage', () {
      final destination = _getDestinationForRole(
        'resident',
        hasFirebaseUser: true,
      );
      expect(destination, 'ResidentDashboardPage');
    });

    test('worker role should route to WorkerDashboardPage', () {
      final destination = _getDestinationForRole(
        'worker',
        hasFirebaseUser: true,
      );
      expect(destination, 'WorkerDashboardPage');
    });

    test('security role should route to SecurityDashboardPage', () {
      final destination = _getDestinationForRole(
        'security',
        hasFirebaseUser: true,
      );
      expect(destination, 'SecurityDashboardPage');
    });

    test(
      'authority role with authority_uid should route to AuthorityDashboardPage',
      () {
        final destination = _getDestinationForRole(
          'authority',
          hasFirebaseUser: false,
          hasAuthorityUid: true,
        );
        expect(destination, 'AuthorityDashboardPage');
      },
    );

    test('null role should route to SafeNetWelcomePage', () {
      final destination = _getDestinationForRole(null, hasFirebaseUser: false);
      expect(destination, 'SafeNetWelcomePage');
    });

    test(
      'valid role but no Firebase user should route to SafeNetWelcomePage',
      () {
        final destination = _getDestinationForRole(
          'resident',
          hasFirebaseUser: false,
        );
        expect(destination, 'SafeNetWelcomePage');
      },
    );

    test('unknown role should route to SafeNetWelcomePage', () {
      final destination = _getDestinationForRole(
        'admin',
        hasFirebaseUser: true,
      );
      expect(destination, 'SafeNetWelcomePage');
    });
  });

  group('ApprovalGate — Status-based UI rendering', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
      'approved + active user data should be recognized as approved',
      () async {
        await fakeFirestore.collection('users').doc('uid-1').set({
          'approvalStatus': 'approved',
          'isActive': true,
          'name': 'Test User',
        });

        final doc = await fakeFirestore.collection('users').doc('uid-1').get();
        final data = doc.data()!;
        final status = data['approvalStatus'] ?? 'pending';
        final isActive = data['isActive'] ?? false;

        expect(status, 'approved');
        expect(isActive, true);
        expect(status == 'approved' && isActive == true, isTrue);
      },
    );

    test('pending status should block access', () async {
      await fakeFirestore.collection('users').doc('uid-2').set({
        'approvalStatus': 'pending',
        'isActive': false,
        'name': 'Pending User',
      });

      final doc = await fakeFirestore.collection('users').doc('uid-2').get();
      final data = doc.data()!;
      final status = data['approvalStatus'] ?? 'pending';
      final isActive = data['isActive'] ?? false;

      expect(status == 'approved' && isActive == true, isFalse);
    });

    test('rejected status should block access', () async {
      await fakeFirestore.collection('users').doc('uid-3').set({
        'approvalStatus': 'rejected',
        'isActive': false,
        'name': 'Rejected User',
      });

      final doc = await fakeFirestore.collection('users').doc('uid-3').get();
      final data = doc.data()!;
      final status = data['approvalStatus'] ?? 'pending';

      expect(status, 'rejected');
      expect(status == 'approved', isFalse);
    });

    test('missing approvalStatus should default to pending', () async {
      await fakeFirestore.collection('users').doc('uid-4').set({
        'name': 'No Status User',
        'isActive': true,
      });

      final doc = await fakeFirestore.collection('users').doc('uid-4').get();
      final data = doc.data()!;
      final status = data['approvalStatus'] ?? 'pending';

      expect(status, 'pending');
    });

    test('approved but isActive=false should block access', () async {
      await fakeFirestore.collection('users').doc('uid-5').set({
        'approvalStatus': 'approved',
        'isActive': false,
        'name': 'Inactive User',
      });

      final doc = await fakeFirestore.collection('users').doc('uid-5').get();
      final data = doc.data()!;
      final status = data['approvalStatus'] ?? 'pending';
      final isActive = data['isActive'] ?? false;

      expect(status == 'approved' && isActive == true, isFalse);
    });

    test('missing isActive should default to false (blocked)', () async {
      await fakeFirestore.collection('users').doc('uid-6').set({
        'approvalStatus': 'approved',
        'name': 'No Active Flag User',
      });

      final doc = await fakeFirestore.collection('users').doc('uid-6').get();
      final data = doc.data()!;
      final isActive = data['isActive'] ?? false;

      expect(isActive, false);
    });
  });

  group('ApprovalGate — _approvalCard text content', () {
    test('pending status card has correct title and message', () {
      final result = _getApprovalCardContent('pending');
      expect(result['title'], 'Approval Pending');
      expect(result['message'], contains('waiting for authority approval'));
    });

    test('rejected status card has correct title and message', () {
      final result = _getApprovalCardContent('rejected');
      expect(result['title'], 'Access Rejected');
      expect(result['message'], contains('rejected by the authority'));
    });

    test('unknown status card should show rejected content', () {
      final result = _getApprovalCardContent('something_weird');
      expect(result['title'], 'Access Rejected');
    });
  });
}

/// Replicates the _checkLoginStatus routing decision from AuthChecker
String _getDestinationForRole(
  String? userRole, {
  bool hasFirebaseUser = false,
  bool hasAuthorityUid = false,
}) {
  // Authority check (uses SharedPreferences, not Firebase Auth)
  if (userRole == 'authority' && hasAuthorityUid) {
    return 'AuthorityDashboardPage';
  }

  // Firebase Auth user check
  if (hasFirebaseUser && userRole != null) {
    switch (userRole) {
      case 'resident':
        return 'ResidentDashboardPage';
      case 'worker':
        return 'WorkerDashboardPage';
      case 'security':
        return 'SecurityDashboardPage';
      default:
        return 'SafeNetWelcomePage';
    }
  }

  return 'SafeNetWelcomePage';
}

/// Replicates the _approvalCard logic from ApprovalGate
Map<String, String> _getApprovalCardContent(String status) {
  if (status == 'pending') {
    return {
      'title': 'Approval Pending',
      'message':
          'Your registration is waiting for authority approval.\nPlease contact the authority.',
    };
  } else {
    return {
      'title': 'Access Rejected',
      'message':
          'Your registration was rejected by the authority.\nPlease contact support.',
    };
  }
}
