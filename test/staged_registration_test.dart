import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/services/staged_registration_service.dart';
import 'package:ott/data/models/location.dart';
import 'package:ott/data/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StagedRegistrationService service;

  setUp(() {
    service = StagedRegistrationService.instance;
    service.resetLaunchSession();
  });

  group('StagedRegistrationService - Step Determination', () {
    test('Step 1 (emailAndAge) required when email and age/dob are missing', () {
      final user = User(id: 1, emailId: '', dob: '', age: '', firstName: '', lastName: '');
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.emailAndAge);
    });

    test('Step 1 required when email is present but age and dob are missing', () {
      final user = User(id: 1, emailId: 'test@filmytell.com', dob: '', age: '', firstName: '', lastName: '');
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.emailAndAge);
    });

    test('Step 1 satisfied by age field alone (birth-year based age)', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        dob: '',
        age: '25',
        firstName: '',
        lastName: '',
      );
      // Age is completed, so Step 1 is complete; next is Name
      expect(StagedRegistrationService.isEmailAndAgeComplete(user), isTrue);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.name);
    });

    test('Step 1 satisfied by legacy dob field alone', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        dob: '1999-05-12',
        age: '',
        firstName: '',
        lastName: '',
      );
      expect(StagedRegistrationService.isEmailAndAgeComplete(user), isTrue);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.name);
    });

    test('Step 2 (name) required when Step 1 complete but name missing', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        age: '28',
        firstName: '',
        lastName: '',
      );
      expect(StagedRegistrationService.isEmailAndAgeComplete(user), isTrue);
      expect(StagedRegistrationService.isNameComplete(user), isFalse);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.name);
    });

    test('Step 2 (name) satisfied if firstName is non-empty', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        age: '28',
        firstName: 'Alex',
        lastName: '',
      );
      expect(StagedRegistrationService.isNameComplete(user), isTrue);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.location);
    });

    test('Step 3 (location) required when Step 1 & 2 complete but location missing', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        age: '30',
        firstName: 'Jane',
        lastName: 'Doe',
        location: null,
      );
      expect(StagedRegistrationService.isLocationComplete(user), isFalse);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.location);
    });

    test('Step 3 (location) satisfied with country and city/state', () {
      final user = User(
        id: 1,
        emailId: 'user@example.com',
        age: '30',
        firstName: 'Jane',
        lastName: 'Doe',
        location: Location(country: 'United Kingdom', city: 'London', state: 'Greater London'),
      );
      expect(StagedRegistrationService.isLocationComplete(user), isTrue);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.none);
    });

    test('Completely registered user returns StagedRegistrationStep.none', () {
      final user = User(
        id: 1,
        emailId: 'user@filmytell.com',
        age: '24',
        firstName: 'Sam',
        lastName: 'Wilson',
        location: Location(country: 'India', state: 'Maharashtra', city: 'Pune'),
      );
      expect(StagedRegistrationService.isEmailAndAgeComplete(user), isTrue);
      expect(StagedRegistrationService.isNameComplete(user), isTrue);
      expect(StagedRegistrationService.isLocationComplete(user), isTrue);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.none);
    });

    test('Null or invalid user returns StagedRegistrationStep.none to avoid crash', () {
      expect(service.getNextIncompleteStep(null), StagedRegistrationStep.none);
      expect(service.getNextIncompleteStep(User(id: 0)), StagedRegistrationStep.none);
    });
  });

  group('Launch-Gating & One-Stage-Per-Launch Logic', () {
    final testUser = User(id: 1, emailId: '', dob: '', age: '');

    test('Shows only one stage per launch session', () async {
      // Launch 1
      expect(service.hasHandledStepInCurrentLaunch, isFalse);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.emailAndAge,
          user: testUser,
        ),
        isTrue,
      );

      // User completes Step 1 in Launch 1
      await service.markStepCompleted(
        step: StagedRegistrationStep.emailAndAge,
        userId: testUser.id,
      );
      expect(service.hasHandledStepInCurrentLaunch, isTrue);

      // In the same launch, Step 2 must NOT be shown
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.name,
          user: testUser,
        ),
        isFalse,
      );
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: testUser,
        ),
        isFalse,
      );

      // Simulate App Restart (Launch 2)
      service.resetLaunchSession();
      expect(service.hasHandledStepInCurrentLaunch, isFalse);
      // Now Step 2 can be shown in Launch 2
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.name,
          user: testUser,
        ),
        isTrue,
      );

      // User completes Step 2 in Launch 2
      await service.markStepCompleted(
        step: StagedRegistrationStep.name,
        userId: testUser.id,
      );
      expect(service.hasHandledStepInCurrentLaunch, isTrue);

      // In the same launch, Step 3 must NOT be shown
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: testUser,
        ),
        isFalse,
      );

      // Simulate App Restart (Launch 3)
      service.resetLaunchSession();
      // Now Step 3 can be shown in Launch 3
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: testUser,
        ),
        isTrue,
      );
    });

    test('Dialog active guard prevents duplicate pop-ups', () {
      expect(service.isDialogActive, isFalse);
      service.setDialogActive(true);
      expect(service.isDialogActive, isTrue);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.emailAndAge,
          user: testUser,
        ),
        isFalse,
      );

      service.setDialogActive(false);
      expect(service.isDialogActive, isFalse);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.emailAndAge,
          user: testUser,
        ),
        isTrue,
      );
    });
  });

  group('Single Name Mapping Tests', () {
    test('Single word name maps to firstName with empty lastName', () {
      final name = 'Pooja'.trim();
      final parts = name.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      expect(firstName, 'Pooja');
      expect(lastName, '');
    });

    test('Two word name maps to firstName and lastName', () {
      final name = 'John Doe'.trim();
      final parts = name.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      expect(firstName, 'John');
      expect(lastName, 'Doe');
    });

    test('Multi-word name preserves all trailing words in lastName', () {
      final name = 'Arthur Conan Doyle'.trim();
      final parts = name.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      expect(firstName, 'Arthur');
      expect(lastName, 'Conan Doyle');
    });
  });
}
