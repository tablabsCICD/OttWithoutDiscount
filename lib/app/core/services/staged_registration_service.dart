import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ott/data/models/user.dart';

/// Represents the stages of user registration onboarding.
enum StagedRegistrationStep {
  none,
  dobAndEmail,
  name,
  location;

  /// Backward-compatible alias for Step 1
  static StagedRegistrationStep get emailAndAge =>
      StagedRegistrationStep.dobAndEmail;
}

/// Service that manages the staged registration flow across successive application launches.
class StagedRegistrationService {
  StagedRegistrationService._();
  static final StagedRegistrationService instance =
      StagedRegistrationService._();

  static const String _prefKeyPrefixCompleted =
      'staged_reg_completed_step_';
  static const String _prefKeyPrefixSkipped =
      'staged_reg_skipped_step_';

  // In-memory state tracking for the current application launch/process.
  bool _hasHandledStepInCurrentLaunch = false;
  bool _isDialogActive = false;
  final Set<String> _skippedStepKeys = <String>{};
  final Set<String> _completedStepKeys = <String>{};

  /// Whether a staged registration pop-up has already been handled (shown, skipped, or completed)
  /// during the current application launch session.
  bool get hasHandledStepInCurrentLaunch => _hasHandledStepInCurrentLaunch;

  /// Whether a staged registration dialog is currently visible on screen.
  bool get isDialogActive => _isDialogActive;

  void setDialogActive(bool active) {
    _isDialogActive = active;
  }

  /// Loads cached skip/complete flags from SharedPreferences into in-memory sets.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_prefKeyPrefixSkipped) &&
            prefs.getBool(key) == true) {
          _skippedStepKeys.add(key);
        } else if (key.startsWith(_prefKeyPrefixCompleted) &&
            prefs.getBool(key) == true) {
          _completedStepKeys.add(key);
        }
      }
    } catch (e) {
      developer.log('Failed to load staged registration prefs: $e',
          name: 'StagedRegistration');
    }
  }

  /// Resets launch-session state. Useful on app restart or logout.
  void resetLaunchSession() {
    _hasHandledStepInCurrentLaunch = false;
    _isDialogActive = false;
    developer.log('StagedRegistrationService launch session reset',
        name: 'StagedRegistration');
  }

  /// Resets in-memory sets for testing.
  void resetForTesting() {
    _hasHandledStepInCurrentLaunch = false;
    _isDialogActive = false;
    _skippedStepKeys.clear();
    _completedStepKeys.clear();
  }

  /// Determines if Step 1 (Date of Birth) is complete.
  /// Complete only when [dob] is present and non-empty.
  /// Returns false if [dob] is null, empty string ("" ), or missing.
  static bool isDobComplete(User? user) {
    if (user == null) return false;
    final dob = user.dob?.trim() ?? '';
    return dob.isNotEmpty;
  }

  /// Backward-compatible alias for checking Step 1 completion.
  static bool isEmailAndAgeComplete(User? user) => isDobComplete(user);

  /// Determines if Step 2 (Name) is complete.
  static bool isNameComplete(User? user) {
    if (user == null) return false;
    final firstName = user.firstName?.trim() ?? '';
    return firstName.isNotEmpty;
  }

  /// Checks if a step was explicitly skipped by the user.
  bool isStepSkipped({
    required StagedRegistrationStep step,
    required int? userId,
  }) {
    if (userId == null || userId <= 0) return false;
    final key = '$_prefKeyPrefixSkipped${userId}_${step.name}';
    return _skippedStepKeys.contains(key);
  }

  /// Determines if Step 3 (Location) is complete.
  /// Checks for country and either city or state.
  static bool isLocationComplete(User? user) {
    if (user == null) return false;
    final loc = user.location;
    if (loc == null) return false;
    final country = loc.country?.trim() ?? '';
    final city = loc.city?.trim() ?? '';
    final state = loc.state?.trim() ?? '';
    return country.isNotEmpty && (city.isNotEmpty || state.isNotEmpty);
  }

  /// Determines the next incomplete registration step based on the user's saved data.
  /// Sequence:
  /// 1. Date of Birth (required), Email (optional), Referral Code (optional)
  /// 2. Name (optional - can be skipped)
  /// 3. Location (Current Location only with Cancel option)
  StagedRegistrationStep getNextIncompleteStep(User? user) {
    if (user == null || (user.id == null || user.id! <= 0)) {
      return StagedRegistrationStep.none;
    }

    if (!isDobComplete(user)) {
      return StagedRegistrationStep.dobAndEmail;
    }

    if (!isNameComplete(user) &&
        !isStepSkipped(
          step: StagedRegistrationStep.name,
          userId: user.id,
        )) {
      return StagedRegistrationStep.name;
    }

    if (!isLocationComplete(user)) {
      return StagedRegistrationStep.location;
    }

    return StagedRegistrationStep.none;
  }

  /// Checks if a step should be displayed in the current application launch.
  /// Enforces that at most one stage is presented per application launch.
  bool shouldShowStepInCurrentLaunch({
    required StagedRegistrationStep step,
    required User? user,
  }) {
    if (step == StagedRegistrationStep.none) return false;
    if (_isDialogActive) return false;
    if (_hasHandledStepInCurrentLaunch) return false;
    if (user == null || user.id == null) return false;

    return true;
  }

  /// Marks a registration step as successfully completed in both the current launch
  /// session and local persistent storage.
  Future<void> markStepCompleted({
    required StagedRegistrationStep step,
    required int? userId,
  }) async {
    _hasHandledStepInCurrentLaunch = true;
    _isDialogActive = false;

    if (userId != null && userId > 0) {
      final key = '$_prefKeyPrefixCompleted${userId}_${step.name}';
      _completedStepKeys.add(key);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(key, true);
        developer.log(
          'Marked $step as completed for userId=$userId in launch session and storage',
          name: 'StagedRegistration',
        );
      } catch (e) {
        developer.log('Failed to persist step completion: $e',
            name: 'StagedRegistration');
      }
    }
  }

  /// Marks a step as explicitly skipped by the user, ensuring it does not block
  /// progression to subsequent stages on subsequent launches.
  Future<void> markStepSkipped({
    required StagedRegistrationStep step,
    required int? userId,
  }) async {
    _hasHandledStepInCurrentLaunch = true;
    _isDialogActive = false;

    if (userId != null && userId > 0) {
      final key = '$_prefKeyPrefixSkipped${userId}_${step.name}';
      _skippedStepKeys.add(key);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(key, true);
        developer.log(
          'Marked $step as skipped for userId=$userId in storage',
          name: 'StagedRegistration',
        );
      } catch (e) {
        developer.log('Failed to persist step skip: $e',
            name: 'StagedRegistration');
      }
    }
  }

  /// Records that a pop-up has been handled (or cancelled) during the current launch,
  /// preventing subsequent stages from appearing prematurely during the same launch.
  void markStepHandledForLaunch() {
    _hasHandledStepInCurrentLaunch = true;
    _isDialogActive = false;
  }
}
