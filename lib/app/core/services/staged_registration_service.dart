import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ott/data/models/user.dart';

/// Represents the stages of user registration onboarding.
enum StagedRegistrationStep {
  none,
  emailAndAge,
  name,
  location,
}

/// Service that manages the staged registration flow across successive application launches.
class StagedRegistrationService {
  StagedRegistrationService._();
  static final StagedRegistrationService instance =
      StagedRegistrationService._();

  static const String _prefKeyPrefix = 'staged_reg_completed_step_';

  // In-memory state tracking for the current application launch/process.
  bool _hasHandledStepInCurrentLaunch = false;
  bool _isDialogActive = false;

  /// Whether a staged registration pop-up has already been handled (shown or completed)
  /// during the current application launch session.
  bool get hasHandledStepInCurrentLaunch => _hasHandledStepInCurrentLaunch;

  /// Whether a staged registration dialog is currently visible on screen.
  bool get isDialogActive => _isDialogActive;

  void setDialogActive(bool active) {
    _isDialogActive = active;
  }

  /// Resets launch-session state. Useful on app restart or logout.
  void resetLaunchSession() {
    _hasHandledStepInCurrentLaunch = false;
    _isDialogActive = false;
    developer.log('StagedRegistrationService launch session reset',
        name: 'StagedRegistration');
  }

  /// Determines if Step 1 (Email + Age / Birth Year) is complete.
  /// Accepts either [age] or [dob] to maintain backward compatibility with existing users.
  static bool isEmailAndAgeComplete(User? user) {
    if (user == null) return false;
    final email = user.emailId?.trim() ?? '';
    final age = user.age?.trim() ?? '';
    final dob = user.dob?.trim() ?? '';
    final hasEmail = email.isNotEmpty;
    final hasAgeOrDob = age.isNotEmpty || dob.isNotEmpty;
    return hasEmail && hasAgeOrDob;
  }

  /// Determines if Step 2 (Name) is complete.
  static bool isNameComplete(User? user) {
    if (user == null) return false;
    final firstName = user.firstName?.trim() ?? '';
    return firstName.isNotEmpty;
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
  /// 1. Email + Age + Optional Referral Code
  /// 2. Name
  /// 3. Location
  StagedRegistrationStep getNextIncompleteStep(User? user) {
    if (user == null || (user.id == null || user.id! <= 0)) {
      return StagedRegistrationStep.none;
    }

    if (!isEmailAndAgeComplete(user)) {
      return StagedRegistrationStep.emailAndAge;
    }

    if (!isNameComplete(user)) {
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
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = '$_prefKeyPrefix${userId}_${step.name}';
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

  /// Records that a pop-up has been shown or dismissed during the current launch,
  /// preventing subsequent stages from appearing prematurely during the same launch.
  void markStepHandledForLaunch() {
    _hasHandledStepInCurrentLaunch = true;
    _isDialogActive = false;
  }
}
