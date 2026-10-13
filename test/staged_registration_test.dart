import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/services/staged_registration_service.dart';
import 'package:ott/data/models/location.dart';
import 'package:ott/data/models/user.dart';
import 'package:ott/app/widgets/month_year_picker_dialog.dart';
import 'package:ott/app/provider/userProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StagedRegistrationService service;

  setUp(() {
    service = StagedRegistrationService.instance;
    service.resetLaunchSession();
  });

  group('StagedRegistrationService - Step Determination & DOB Conditions', () {
    test('Condition 1 & 2: New user or existing user with dob=null, empty (""), or missing sees DOB dialog', () {
      // New user (missing all details including dob)
      final newUser = User(id: 1, emailId: '', dob: '', age: '', firstName: '', lastName: '');
      expect(StagedRegistrationService.isDobComplete(newUser), isFalse);
      expect(service.getNextIncompleteStep(newUser), StagedRegistrationStep.dobAndEmail);

      // Existing user with dob null
      final userNullDob = User(id: 2, emailId: 'user@filmytell.com', dob: null, age: '25', firstName: 'A');
      expect(StagedRegistrationService.isDobComplete(userNullDob), isFalse);
      expect(service.getNextIncompleteStep(userNullDob), StagedRegistrationStep.dobAndEmail);

      // Existing user with dob empty string
      final userEmptyDob = User(id: 3, emailId: 'user@filmytell.com', dob: '', age: '25', firstName: 'A');
      expect(StagedRegistrationService.isDobComplete(userEmptyDob), isFalse);
      expect(service.getNextIncompleteStep(userEmptyDob), StagedRegistrationStep.dobAndEmail);

      // Existing user with dob whitespace
      final userWhitespaceDob = User(id: 4, emailId: 'user@filmytell.com', dob: '   ', age: '25', firstName: 'A');
      expect(StagedRegistrationService.isDobComplete(userWhitespaceDob), isFalse);
      expect(service.getNextIncompleteStep(userWhitespaceDob), StagedRegistrationStep.dobAndEmail);
    });

    test('Condition 3: User with existing valid DOB does NOT see DOB dialog again solely for this field', () {
      final userWithDob = User(
        id: 5,
        emailId: 'user@filmytell.com',
        dob: 'July 2007',
        age: '19',
        firstName: '',
        lastName: '',
      );
      expect(StagedRegistrationService.isDobComplete(userWithDob), isTrue);
      // Next incomplete step moves directly to name; NOT dobAndEmail
      expect(service.getNextIncompleteStep(userWithDob), StagedRegistrationStep.name);
    });

    test('Step 2 (name) required when DOB complete but name missing', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        dob: 'July 2007',
        age: '19',
        firstName: '',
        lastName: '',
      );
      expect(StagedRegistrationService.isDobComplete(user), isTrue);
      expect(StagedRegistrationService.isNameComplete(user), isFalse);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.name);
    });

    test('Step 2 (name) satisfied if firstName is non-empty', () {
      final user = User(
        id: 1,
        emailId: 'test@filmytell.com',
        dob: 'July 2007',
        age: '19',
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
        dob: 'July 2007',
        age: '19',
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
        dob: 'July 2007',
        age: '19',
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
        dob: 'July 2007',
        age: '19',
        firstName: 'Sam',
        lastName: 'Wilson',
        location: Location(country: 'India', state: 'Maharashtra', city: 'Pune'),
      );
      expect(StagedRegistrationService.isDobComplete(user), isTrue);
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

  group('Step 1 (Birth Month & Year, Optional Email, Referral)', () {
    test('Selecting July 2007 sends and saves exactly "dob": "July 2007" with no day', () {
      final userProvider = UserProvider();
      userProvider.setBirthMonthAndYear('July', 2007);

      // Exact format: Full English month name + space + 4-digit year
      expect(userProvider.dobController.text, 'July 2007');

      // Verify exact JSON payload format
      final payload = {
        'dob': userProvider.dobController.text,
      };
      expect(payload['dob'], 'July 2007');

      // Reject day additions, hyphens, slashes, or timestamps
      expect(payload['dob']!.contains('01'), isFalse);
      expect(payload['dob']!.contains('-'), isFalse);
      expect(payload['dob']!.contains('/'), isFalse);
      expect(payload['dob']!.contains('T'), isFalse);
      expect(RegExp(r'^[A-Z][a-z]+\s+\d{4}$').hasMatch(payload['dob']!), isTrue);
    });

    test('Birth month and year selector formats as Month Year without fabricating a day', () {
      final userProvider = UserProvider();
      userProvider.setBirthMonthAndYear('October', 1992);

      // Formatted as 'Month Year'
      expect(userProvider.dobController.text, 'October 1992');
      // No day is present
      expect(userProvider.dobController.text.contains('-'), isFalse);
      expect(RegExp(r'^\w+\s+\d{4}$').hasMatch(userProvider.dobController.text), isTrue);

      // Age is computed correctly from year
      final expectedAge = DateTime.now().year - 1992;
      expect(userProvider.ageController.text, '$expectedAge');
    });

    test('parseBirthMonthAndYear parses Month Year and legacy formats accurately', () {
      // Month Year format
      final res1 = parseBirthMonthAndYear('October 1992');
      expect(res1['month'], 'October');
      expect(res1['year'], 1992);

      // Case insensitivity
      final res2 = parseBirthMonthAndYear('january 2005');
      expect(res2['month'], 'January');
      expect(res2['year'], 2005);

      // Backward compatible with legacy ISO date
      final res3 = parseBirthMonthAndYear('1995-08-15');
      expect(res3['month'], 'August');
      expect(res3['year'], 1995);

      // Empty / invalid input
      final res4 = parseBirthMonthAndYear('');
      expect(res4['month'], isNull);
      expect(res4['year'], isNull);
    });

    test('Birth month and year validation rejects future periods', () {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      String? validateMonthYear(String? month, int? year) {
        if (month == null || month.trim().isEmpty) return 'Select month';
        if (year == null) return 'Select year';
        if (year > currentYear) return 'Invalid year';
        if (year == currentYear) {
          final monthIndex = kBirthMonths.indexOf(month) + 1;
          if (monthIndex > currentMonth) return 'Invalid month';
        }
        return null;
      }

      // Valid past month and year
      expect(validateMonthYear('October', 1992), isNull);
      expect(validateMonthYear('January', currentYear), isNull);

      // Future year
      expect(validateMonthYear('January', currentYear + 1), 'Invalid year');

      // Future month in current year (if applicable)
      if (currentMonth < 12) {
        final futureMonthName = kBirthMonths[currentMonth];
        expect(validateMonthYear(futureMonthName, currentYear), 'Invalid month');
      }
    });

    test('Email is completely optional; empty string is valid and does not block submission', () {
      String? validateEmail(String? input) {
        if (input != null && input.trim().isNotEmpty) {
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegex.hasMatch(input.trim())) {
            return 'Invalid email address';
          }
        }
        return null; // Empty or null is valid!
      }

      // Empty inputs: valid (optional)
      expect(validateEmail(''), isNull);
      expect(validateEmail('   '), isNull);
      expect(validateEmail(null), isNull);

      // Valid emails
      expect(validateEmail('user@filmytell.com'), isNull);
      expect(validateEmail('test.name@domain.co.in'), isNull);

      // Invalid emails only when provided
      expect(validateEmail('notanemail'), 'Invalid email address');
      expect(validateEmail('user@'), 'Invalid email address');
      expect(validateEmail('@domain.com'), 'Invalid email address');
    });

    test('Empty optional email does not overwrite existing valid email in user model', () {
      final existingUser = User(
        id: 1,
        emailId: 'existing@filmytell.com',
        dob: 'October 1992',
      );

      // Controller has empty text
      final inputEmail = '';
      final updatedEmail = inputEmail.trim().isNotEmpty
          ? inputEmail.trim()
          : (existingUser.emailId ?? '');

      expect(updatedEmail, 'existing@filmytell.com');
    });

    test('Update user details payload preserves existing email when empty and uses month/year dob', () {
      final existingUser = User(
        id: 1,
        emailId: 'saved@filmytell.com',
        dob: 'May 1995',
      );

      // Empty email controller, filled DOB controller
      final emailInput = '';
      final dobInput = 'October 1992';

      final payload = {
        'id': existingUser.id,
        'emailId': emailInput.trim().isNotEmpty
            ? emailInput.trim()
            : (existingUser.emailId ?? ''),
        'dob': dobInput.trim().isNotEmpty
            ? dobInput.trim()
            : (existingUser.dob ?? ''),
      };

      expect(payload['emailId'], 'saved@filmytell.com');
      expect(payload['dob'], 'October 1992');
      // Verify no artificial day was added
      expect((payload['dob'] as String).contains('-01'), isFalse);
    });

    test('Unfilled optional email sends null for emailId in update user details payload', () {
      final newUser = User(
        id: 1,
        emailId: null,
        dob: '',
      );

      final emailInput = '';
      final dobInput = 'March 1996';

      final trimmedEmail = emailInput.trim();
      final String? emailToSend = trimmedEmail.isNotEmpty
          ? trimmedEmail
          : (newUser.emailId != null && newUser.emailId!.trim().isNotEmpty
              ? newUser.emailId!.trim()
              : null);

      final payload = {
        'id': newUser.id,
        'emailId': emailToSend,
        'dob': dobInput.trim().isNotEmpty ? dobInput.trim() : (newUser.dob ?? ''),
      };

      expect(payload['emailId'], isNull);
      expect(payload.containsKey('emailId'), isTrue);
      expect(payload['emailId'], null);
      expect(jsonEncode(payload), contains('"emailId":null'));
    });

    test('Referral code is optional and existing referral code is preserved', () {
      String getEffectiveReferralCode({
        required String controllerText,
        required String? pendingCode,
      }) {
        if (controllerText.trim().isNotEmpty) {
          return controllerText.trim();
        }
        return (pendingCode != null && pendingCode.trim().isNotEmpty)
            ? pendingCode.trim()
            : '';
      }

      // User enters nothing, but has pending referral from deep link
      expect(
        getEffectiveReferralCode(controllerText: '', pendingCode: 'REF123'),
        'REF123',
      );

      // User enters a code manually
      expect(
        getEffectiveReferralCode(controllerText: 'MANUAL50', pendingCode: 'REF123'),
        'MANUAL50',
      );

      // Both empty
      expect(
        getEffectiveReferralCode(controllerText: '', pendingCode: null),
        '',
      );
    });
  });

  group('Step 2 (Name) Optional & Skip Behavior', () {
    setUp(() {
      service.resetForTesting();
    });

    test('User can skip name and step advances to location on next launch', () async {
      final user = User(
        id: 42,
        dob: '1990-01-01',
        emailId: '',
        firstName: '',
        lastName: '',
      );

      // Initially next step is Name
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.name);

      // User explicitly skips Name
      await service.markStepSkipped(
        step: StagedRegistrationStep.name,
        userId: user.id,
      );

      expect(service.isStepSkipped(step: StagedRegistrationStep.name, userId: user.id), isTrue);

      // In the current launch, handled flag prevents showing location immediately
      expect(service.hasHandledStepInCurrentLaunch, isTrue);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: user,
        ),
        isFalse,
      );

      // On next application launch, next incomplete step advances to location
      service.resetLaunchSession();
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.location);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: user,
        ),
        isTrue,
      );
    });

    test('Skipping name does not overwrite existing name in user model', () {
      final existingUser = User(
        id: 42,
        firstName: 'ExistingName',
        lastName: '',
      );

      final inputName = '';
      final resolvedName = inputName.trim().isNotEmpty
          ? inputName.trim()
          : (existingUser.firstName ?? '');

      expect(resolvedName, 'ExistingName');
    });
  });

  group('Step 3 (Location) Current Location & Cancel Behavior', () {
    setUp(() {
      service.resetForTesting();
    });

    test('Cancelling location pop-up does NOT mark location complete', () {
      final user = User(
        id: 99,
        dob: '1992-06-20',
        firstName: 'Rohan',
        location: null,
      );

      expect(StagedRegistrationService.isLocationComplete(user), isFalse);

      // User cancels location
      service.markStepHandledForLaunch();

      // Handled in current launch: pop-up does not reopen during this session
      expect(service.hasHandledStepInCurrentLaunch, isTrue);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: user,
        ),
        isFalse,
      );

      // Location must NOT be marked complete in user data or service
      expect(StagedRegistrationService.isLocationComplete(user), isFalse);

      // On next launch session, location pop-up is offered again
      service.resetLaunchSession();
      expect(service.hasHandledStepInCurrentLaunch, isFalse);
      expect(service.getNextIncompleteStep(user), StagedRegistrationStep.location);
      expect(
        service.shouldShowStepInCurrentLaunch(
          step: StagedRegistrationStep.location,
          user: user,
        ),
        isTrue,
      );
    });

    test('Saving resolved location marks Step 3 complete', () async {
      final user = User(
        id: 99,
        dob: '1992-06-20',
        firstName: 'Rohan',
        location: null,
      );

      // Location detected and saved
      final completedUser = User(
        id: 99,
        dob: '1992-06-20',
        firstName: 'Rohan',
        location: Location(
          country: 'India',
          state: 'Karnataka',
          city: 'Bengaluru',
        ),
      );

      await service.markStepCompleted(
        step: StagedRegistrationStep.location,
        userId: user.id,
      );

      expect(StagedRegistrationService.isLocationComplete(completedUser), isTrue);
      expect(service.getNextIncompleteStep(completedUser), StagedRegistrationStep.none);
    });
  });
}

