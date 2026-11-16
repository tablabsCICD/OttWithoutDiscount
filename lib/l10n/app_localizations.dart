import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_as.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ne.dart';
import 'app_localizations_or.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('as'),
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('ne'),
    Locale('or'),
    Locale('pa'),
    Locale('ta'),
    Locale('te'),
    Locale('ur')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Filmytell'**
  String get appTitle;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterMobileNumber;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @otpSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully'**
  String get otpSentSuccessfully;

  /// No description provided for @loginSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Logged in successfully'**
  String get loginSuccessfully;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover, Watch, Experience...'**
  String get homeTitle;

  /// No description provided for @movie.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movie;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @enterDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter Details'**
  String get enterDetails;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDate;

  /// No description provided for @enterBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Enter birth date'**
  String get enterBirthDate;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @enterFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter first name'**
  String get enterFirstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @enterLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter last name'**
  String get enterLastName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterEmail;

  /// No description provided for @referralCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral Code (Optional)'**
  String get referralCodeOptional;

  /// No description provided for @enterReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Enter referral code'**
  String get enterReferralCode;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterLocationDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter Location Details'**
  String get enterLocationDetails;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @enterCountry.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid country'**
  String get enterCountry;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @enterState.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid state'**
  String get enterState;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @enterDistrict.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid district'**
  String get enterDistrict;

  /// No description provided for @taluka.
  ///
  /// In en, this message translates to:
  /// **'Taluka'**
  String get taluka;

  /// No description provided for @enterTaluka.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid taluka'**
  String get enterTaluka;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchContent.
  ///
  /// In en, this message translates to:
  /// **'Search Content'**
  String get searchContent;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filterOptions.
  ///
  /// In en, this message translates to:
  /// **'Filter Options'**
  String get filterOptions;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @selectGenre.
  ///
  /// In en, this message translates to:
  /// **'Select Genre'**
  String get selectGenre;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @minimumRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get minimumRating;

  /// No description provided for @selectRating.
  ///
  /// In en, this message translates to:
  /// **'Select Rating'**
  String get selectRating;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get clearFilter;

  /// No description provided for @noContentFound.
  ///
  /// In en, this message translates to:
  /// **'No content found'**
  String get noContentFound;

  /// No description provided for @watchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get watchlist;

  /// No description provided for @noContentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get noContentAvailable;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @notifyMe.
  ///
  /// In en, this message translates to:
  /// **'Notify Me'**
  String get notifyMe;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @readyToStreamYourfavorites.
  ///
  /// In en, this message translates to:
  /// **'Ready to stream your favorites'**
  String get readyToStreamYourfavorites;

  /// No description provided for @addBalance.
  ///
  /// In en, this message translates to:
  /// **'Add Balance'**
  String get addBalance;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @noTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noTransactionsFound;

  /// No description provided for @rechargeWallet.
  ///
  /// In en, this message translates to:
  /// **'Recharge Wallet'**
  String get rechargeWallet;

  /// No description provided for @enterAmountMin10.
  ///
  /// In en, this message translates to:
  /// **'Enter amount (Min ₹10)'**
  String get enterAmountMin10;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @minimumRechargeAmountIs10.
  ///
  /// In en, this message translates to:
  /// **'Minimum recharge amount is ₹10'**
  String get minimumRechargeAmountIs10;

  /// No description provided for @walletRechargedWith.
  ///
  /// In en, this message translates to:
  /// **'Wallet recharged with'**
  String get walletRechargedWith;

  /// No description provided for @recharge.
  ///
  /// In en, this message translates to:
  /// **'Recharge'**
  String get recharge;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @enterYourQuery.
  ///
  /// In en, this message translates to:
  /// **'Enter your query'**
  String get enterYourQuery;

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach Image'**
  String get attachImage;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @selectPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Preferred Language'**
  String get selectPreferredLanguage;

  /// No description provided for @director.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get director;

  /// No description provided for @cast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get cast;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @runtime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get runtime;

  /// No description provided for @releaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get releaseDate;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @audioFormat.
  ///
  /// In en, this message translates to:
  /// **'Audio Formats'**
  String get audioFormat;

  /// No description provided for @subtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get subtitle;

  /// No description provided for @ageRating.
  ///
  /// In en, this message translates to:
  /// **'Age Rating'**
  String get ageRating;

  /// No description provided for @rent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get rent;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @watchTrailer.
  ///
  /// In en, this message translates to:
  /// **'Watch Trailer'**
  String get watchTrailer;

  /// No description provided for @watchMovie.
  ///
  /// In en, this message translates to:
  /// **'Watch Movie'**
  String get watchMovie;

  /// No description provided for @watchSeries.
  ///
  /// In en, this message translates to:
  /// **'Watch Series'**
  String get watchSeries;

  /// No description provided for @mediaHouse.
  ///
  /// In en, this message translates to:
  /// **'Media House'**
  String get mediaHouse;

  /// No description provided for @rentDuration.
  ///
  /// In en, this message translates to:
  /// **'Rent Duration'**
  String get rentDuration;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @myCredits.
  ///
  /// In en, this message translates to:
  /// **'My Credits'**
  String get myCredits;

  /// No description provided for @gifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get gifts;

  /// No description provided for @giftedMovies.
  ///
  /// In en, this message translates to:
  /// **'Gifted Movies'**
  String get giftedMovies;

  /// No description provided for @claimGiftCard.
  ///
  /// In en, this message translates to:
  /// **'Claim Gift Card'**
  String get claimGiftCard;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @feedbackAndInformation.
  ///
  /// In en, this message translates to:
  /// **'Feedback & Information'**
  String get feedbackAndInformation;

  /// No description provided for @termsPoliciesLiscenses.
  ///
  /// In en, this message translates to:
  /// **'Terms, Policies and Liscenses'**
  String get termsPoliciesLiscenses;

  /// No description provided for @aboutFilmytell.
  ///
  /// In en, this message translates to:
  /// **'About Filmytell'**
  String get aboutFilmytell;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// No description provided for @purchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Purchase History'**
  String get purchaseHistory;

  /// No description provided for @giftedByYou.
  ///
  /// In en, this message translates to:
  /// **'Gifted Movies By You'**
  String get giftedByYou;

  /// No description provided for @receivedGiftedMovies.
  ///
  /// In en, this message translates to:
  /// **'Received Gifted Movies'**
  String get receivedGiftedMovies;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get accountDetails;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get editAddress;

  /// No description provided for @minSeries.
  ///
  /// In en, this message translates to:
  /// **'Mini Series'**
  String get minSeries;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @filmytellPresents.
  ///
  /// In en, this message translates to:
  /// **'FILMYTELL PRESENTS'**
  String get filmytellPresents;

  /// No description provided for @filmytellOriginals.
  ///
  /// In en, this message translates to:
  /// **'Filmytell Originals'**
  String get filmytellOriginals;

  /// No description provided for @premiumStoriesDefault.
  ///
  /// In en, this message translates to:
  /// **'Discover premium Indian movies, series, and stories crafted for every screen.'**
  String get premiumStoriesDefault;

  /// No description provided for @watchNow.
  ///
  /// In en, this message translates to:
  /// **'Watch Now'**
  String get watchNow;

  /// No description provided for @playTrailer.
  ///
  /// In en, this message translates to:
  /// **'Play Trailer'**
  String get playTrailer;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'More Details'**
  String get moreDetails;

  /// No description provided for @trendingOnFilmytell.
  ///
  /// In en, this message translates to:
  /// **'Trending on FilmyTell'**
  String get trendingOnFilmytell;

  /// No description provided for @trendingIn.
  ///
  /// In en, this message translates to:
  /// **'Trending in'**
  String get trendingIn;

  /// No description provided for @watchPremiumMoviesSeries.
  ///
  /// In en, this message translates to:
  /// **'Watch premium movies and series on FilmyTell.'**
  String get watchPremiumMoviesSeries;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @latestContent.
  ///
  /// In en, this message translates to:
  /// **'Latest Content'**
  String get latestContent;

  /// No description provided for @howFilmytellWorks.
  ///
  /// In en, this message translates to:
  /// **'HOW FILMYTELL WORKS'**
  String get howFilmytellWorks;

  /// No description provided for @viewersEntertainmentTitle.
  ///
  /// In en, this message translates to:
  /// **'For Entertainment Lovers'**
  String get viewersEntertainmentTitle;

  /// No description provided for @viewersEntertainmentDescription.
  ///
  /// In en, this message translates to:
  /// **'Rent and Gift Movies, Series, Short Films. No subscription, No adds. Pure entertainment.'**
  String get viewersEntertainmentDescription;

  /// No description provided for @createAccountMobileOtp.
  ///
  /// In en, this message translates to:
  /// **'Create Account With Mobile OTP'**
  String get createAccountMobileOtp;

  /// No description provided for @browseMoviesAndSeries.
  ///
  /// In en, this message translates to:
  /// **'Browse Movies and Series'**
  String get browseMoviesAndSeries;

  /// No description provided for @payOnlyContentChoose.
  ///
  /// In en, this message translates to:
  /// **'Pay Only For The Content You Choose'**
  String get payOnlyContentChoose;

  /// No description provided for @giftMoviesFriendsFamily.
  ///
  /// In en, this message translates to:
  /// **'Gift Movies To Friends & Family'**
  String get giftMoviesFriendsFamily;

  /// No description provided for @buildWatchlistContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Build Watchlist & Continue Watching'**
  String get buildWatchlistContinueWatching;

  /// No description provided for @watchAcrossDevices.
  ///
  /// In en, this message translates to:
  /// **'Watch Across Mobile, Web & TV'**
  String get watchAcrossDevices;

  /// No description provided for @payPerMovie.
  ///
  /// In en, this message translates to:
  /// **'Pay Per Movie'**
  String get payPerMovie;

  /// No description provided for @movieGifting.
  ///
  /// In en, this message translates to:
  /// **'Movie Gifting'**
  String get movieGifting;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @multiDeviceAccess.
  ///
  /// In en, this message translates to:
  /// **'Multi-device Access'**
  String get multiDeviceAccess;

  /// No description provided for @regionalContent.
  ///
  /// In en, this message translates to:
  /// **'Regional Content'**
  String get regionalContent;

  /// No description provided for @securePlayback.
  ///
  /// In en, this message translates to:
  /// **'Secure Playback'**
  String get securePlayback;

  /// No description provided for @exploreContent.
  ///
  /// In en, this message translates to:
  /// **'Explore Content'**
  String get exploreContent;

  /// No description provided for @productionHouseWorks.
  ///
  /// In en, this message translates to:
  /// **'HOW PRODUCTION HOUSE WORKS'**
  String get productionHouseWorks;

  /// No description provided for @productionHousesTitle.
  ///
  /// In en, this message translates to:
  /// **'For Production House'**
  String get productionHousesTitle;

  /// No description provided for @productionHouseDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload, manage and monetize your content.'**
  String get productionHouseDescription;

  /// No description provided for @contentManagement.
  ///
  /// In en, this message translates to:
  /// **'Content Management'**
  String get contentManagement;

  /// No description provided for @revenueTracking.
  ///
  /// In en, this message translates to:
  /// **'Revenue Tracking'**
  String get revenueTracking;

  /// No description provided for @analyticsDashboard.
  ///
  /// In en, this message translates to:
  /// **'Analytics Dashboard'**
  String get analyticsDashboard;

  /// No description provided for @approvalWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Approval Workflow'**
  String get approvalWorkflow;

  /// No description provided for @releaseScheduling.
  ///
  /// In en, this message translates to:
  /// **'Release Scheduling'**
  String get releaseScheduling;

  /// No description provided for @secureDistribution.
  ///
  /// In en, this message translates to:
  /// **'Secure Distribution'**
  String get secureDistribution;

  /// No description provided for @registerProductionHouse.
  ///
  /// In en, this message translates to:
  /// **'Register Production House'**
  String get registerProductionHouse;

  /// No description provided for @completeVerification.
  ///
  /// In en, this message translates to:
  /// **'Complete Verification'**
  String get completeVerification;

  /// No description provided for @uploadMoviesSeries.
  ///
  /// In en, this message translates to:
  /// **'Upload Movies and Series'**
  String get uploadMoviesSeries;

  /// No description provided for @submitForApproval.
  ///
  /// In en, this message translates to:
  /// **'Submit For Approval'**
  String get submitForApproval;

  /// No description provided for @trackRevenuePerformance.
  ///
  /// In en, this message translates to:
  /// **'Track Revenue & Performance'**
  String get trackRevenuePerformance;

  /// No description provided for @reachGlobalAudience.
  ///
  /// In en, this message translates to:
  /// **'Reach Global Audience'**
  String get reachGlobalAudience;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get learnMore;

  /// No description provided for @mobileNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Mobile number is required'**
  String get mobileNumberRequired;

  /// No description provided for @enterAtLeast10Digits.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 10 digits'**
  String get enterAtLeast10Digits;

  /// No description provided for @enterValidIndianMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Indian mobile number'**
  String get enterValidIndianMobile;

  /// No description provided for @noQueryProvided.
  ///
  /// In en, this message translates to:
  /// **'No query provided.'**
  String get noQueryProvided;

  /// No description provided for @productionEnquiryTitle.
  ///
  /// In en, this message translates to:
  /// **'New Production House Enquiry'**
  String get productionEnquiryTitle;

  /// No description provided for @userMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'User Mobile Number'**
  String get userMobileNumber;

  /// No description provided for @query.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get query;

  /// No description provided for @redirectingWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to WhatsApp...'**
  String get redirectingWhatsapp;

  /// No description provided for @unableOpenWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Unable to open WhatsApp. Please try again.'**
  String get unableOpenWhatsapp;

  /// No description provided for @haveQuestionHelp.
  ///
  /// In en, this message translates to:
  /// **'Connect with our team'**
  String get haveQuestionHelp;

  /// No description provided for @messageQueryOptional.
  ///
  /// In en, this message translates to:
  /// **'Tell us your requirement or any doubt (Optional)'**
  String get messageQueryOptional;

  /// No description provided for @sendProductionEnquiry.
  ///
  /// In en, this message translates to:
  /// **'Send production enquiry'**
  String get sendProductionEnquiry;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get opening;

  /// No description provided for @sendEnquiry.
  ///
  /// In en, this message translates to:
  /// **'Send Enquiry'**
  String get sendEnquiry;

  /// No description provided for @watchAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Watch Anywhere'**
  String get watchAnywhere;

  /// No description provided for @availableDevicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Filmytell is available across your favorite screens.'**
  String get availableDevicesDescription;

  /// No description provided for @startWatching.
  ///
  /// In en, this message translates to:
  /// **'Start Watching'**
  String get startWatching;

  /// No description provided for @readyToStart.
  ///
  /// In en, this message translates to:
  /// **'READY TO START'**
  String get readyToStart;

  /// No description provided for @startJourneyToday.
  ///
  /// In en, this message translates to:
  /// **'Start Your Filmytell Journey Today'**
  String get startJourneyToday;

  /// No description provided for @chooseHowUseFilmytell.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to use Filmytell.'**
  String get chooseHowUseFilmytell;

  /// No description provided for @watchContent.
  ///
  /// In en, this message translates to:
  /// **'Watch Content'**
  String get watchContent;

  /// No description provided for @streamPremiumMoviesSeries.
  ///
  /// In en, this message translates to:
  /// **'Watch Premium Movies, Series, Mini Series and Short Film.'**
  String get streamPremiumMoviesSeries;

  /// No description provided for @userPortal.
  ///
  /// In en, this message translates to:
  /// **'User Portal'**
  String get userPortal;

  /// No description provided for @publishContent.
  ///
  /// In en, this message translates to:
  /// **'Publish Content'**
  String get publishContent;

  /// No description provided for @publishContentDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload, Manage and Monetize Your Content.'**
  String get publishContentDescription;

  /// No description provided for @productionHousePortal.
  ///
  /// In en, this message translates to:
  /// **'Production House Portal'**
  String get productionHousePortal;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @portals.
  ///
  /// In en, this message translates to:
  /// **'Portals'**
  String get portals;

  /// No description provided for @shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcuts;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUs;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @allRightsReserved.
  ///
  /// In en, this message translates to:
  /// **'@Filmytell. All Rights Reserved.'**
  String get allRightsReserved;

  /// No description provided for @giftAccess.
  ///
  /// In en, this message translates to:
  /// **'Gift access'**
  String get giftAccess;

  /// No description provided for @downloadOffline.
  ///
  /// In en, this message translates to:
  /// **'Download offline'**
  String get downloadOffline;

  /// No description provided for @unableOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Unable to open link'**
  String get unableOpenLink;

  /// No description provided for @unableOpenDocument.
  ///
  /// In en, this message translates to:
  /// **'Unable to open document'**
  String get unableOpenDocument;

  /// No description provided for @trailerNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Trailer is not available'**
  String get trailerNotAvailable;

  /// No description provided for @chatWithUsWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Chat with us on WhatsApp'**
  String get chatWithUsWhatsapp;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get needHelp;

  /// No description provided for @trendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending Now'**
  String get trendingNow;

  /// No description provided for @filmytellByNumbers.
  ///
  /// In en, this message translates to:
  /// **'Filmytell By The Numbers'**
  String get filmytellByNumbers;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @moviesLabel.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get moviesLabel;

  /// No description provided for @seriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get seriesLabel;

  /// No description provided for @productionHouses.
  ///
  /// In en, this message translates to:
  /// **'Production House'**
  String get productionHouses;

  /// No description provided for @growing.
  ///
  /// In en, this message translates to:
  /// **'Growing'**
  String get growing;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every Day'**
  String get everyDay;

  /// No description provided for @shortFilm.
  ///
  /// In en, this message translates to:
  /// **'Short Film'**
  String get shortFilm;

  /// No description provided for @cookies.
  ///
  /// In en, this message translates to:
  /// **'Cookies'**
  String get cookies;

  /// No description provided for @accountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Account Deletion'**
  String get accountDeletion;

  /// No description provided for @oneOttEcosystem.
  ///
  /// In en, this message translates to:
  /// **'One OTT ecosystem for viewers and creators'**
  String get oneOttEcosystem;

  /// No description provided for @oneOttEcosystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Secure streaming, pay-per-movie access, gifting, production house publishing, promoter growth tools, and multi-device entertainment.'**
  String get oneOttEcosystemDescription;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get readMore;

  /// No description provided for @readLess.
  ///
  /// In en, this message translates to:
  /// **'Read Less'**
  String get readLess;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'STEP'**
  String get step;

  /// No description provided for @enterEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get enterEmailAddress;

  /// No description provided for @enterValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get enterValidEmailAddress;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get enterPhoneNumber;

  /// No description provided for @enterValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get enterValidPhoneNumber;

  /// No description provided for @enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter message'**
  String get enterMessage;

  /// No description provided for @emailSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Email sent successfully.'**
  String get emailSentSuccessfully;

  /// No description provided for @failedToSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send email. Please try again.'**
  String get failedToSendEmail;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled.'**
  String get paymentCancelled;

  /// No description provided for @rechargeFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Recharge failed. Please try again.'**
  String get rechargeFailedTryAgain;

  /// No description provided for @paymentFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentFailedTryAgain;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @shortFilms.
  ///
  /// In en, this message translates to:
  /// **'Short Films'**
  String get shortFilms;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get to;

  /// No description provided for @failedLoadPurchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load purchase history'**
  String get failedLoadPurchaseHistory;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noPurchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'No purchases found'**
  String get noPurchaseHistory;

  /// No description provided for @noPurchaseHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Purchases made between the selected dates will appear here.'**
  String get noPurchaseHistoryHint;

  /// No description provided for @startDateBeforeEndDate.
  ///
  /// In en, this message translates to:
  /// **'Start date should be less than end date.'**
  String get startDateBeforeEndDate;

  /// No description provided for @statusSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get statusSuccessful;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @purchasedContent.
  ///
  /// In en, this message translates to:
  /// **'Purchased Content'**
  String get purchasedContent;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get amountPaid;

  /// No description provided for @transactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice No.'**
  String get invoiceNumber;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @viewInvoice.
  ///
  /// In en, this message translates to:
  /// **'View Invoice'**
  String get viewInvoice;

  /// No description provided for @shareInvoice.
  ///
  /// In en, this message translates to:
  /// **'Share Invoice'**
  String get shareInvoice;

  /// No description provided for @invoiceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Invoice not available'**
  String get invoiceNotAvailable;

  /// No description provided for @invalidInvoiceUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid invoice URL.'**
  String get invalidInvoiceUrl;

  /// No description provided for @unableOpenInvoice.
  ///
  /// In en, this message translates to:
  /// **'Unable to open invoice right now.'**
  String get unableOpenInvoice;

  /// No description provided for @unableShareInvoice.
  ///
  /// In en, this message translates to:
  /// **'Unable to share invoice right now.'**
  String get unableShareInvoice;

  /// No description provided for @purchaseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Purchase Invoice'**
  String get purchaseInvoice;

  /// No description provided for @invoiceShareText.
  ///
  /// In en, this message translates to:
  /// **'Here is your invoice for {title}.'**
  String invoiceShareText(String title);

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @noMoviesInSelectedLanguage.
  ///
  /// In en, this message translates to:
  /// **'No movies available in this selected language.'**
  String get noMoviesInSelectedLanguage;

  /// No description provided for @noContentInSelectedLanguage.
  ///
  /// In en, this message translates to:
  /// **'No content available in this selected language.'**
  String get noContentInSelectedLanguage;

  /// No description provided for @selectedLanguagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected languages'**
  String get selectedLanguagesLabel;

  /// No description provided for @tryAnotherLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Try choosing another language to discover more content.'**
  String get tryAnotherLanguageHint;

  /// No description provided for @searchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different title, actor or director, or clear the filters.'**
  String get searchNoResultsHint;

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String searchResultsCount(int count);

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get newestFirst;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @noTitle.
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get noTitle;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get homeSeeAll;

  /// No description provided for @homeStarRating.
  ///
  /// In en, this message translates to:
  /// **'{rating} star'**
  String homeStarRating(String rating);

  /// No description provided for @homeTrendingRank.
  ///
  /// In en, this message translates to:
  /// **'#{rank} Trending'**
  String homeTrendingRank(int rank);

  /// No description provided for @homeTrailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get homeTrailer;

  /// No description provided for @homeBirthMonthRequired.
  ///
  /// In en, this message translates to:
  /// **'Birth Month *'**
  String get homeBirthMonthRequired;

  /// No description provided for @homeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get homeMonth;

  /// No description provided for @homeSelectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get homeSelectMonth;

  /// No description provided for @homeInvalidMonth.
  ///
  /// In en, this message translates to:
  /// **'Invalid month'**
  String get homeInvalidMonth;

  /// No description provided for @homeBirthYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Birth Year *'**
  String get homeBirthYearRequired;

  /// No description provided for @homeYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get homeYear;

  /// No description provided for @homeSelectYear.
  ///
  /// In en, this message translates to:
  /// **'Select year'**
  String get homeSelectYear;

  /// No description provided for @homeInvalidYear.
  ///
  /// In en, this message translates to:
  /// **'Invalid year'**
  String get homeInvalidYear;

  /// No description provided for @homeBirthDateValue.
  ///
  /// In en, this message translates to:
  /// **'Birth Date: {month} {year}'**
  String homeBirthDateValue(String month, String year);

  /// No description provided for @homeEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (Optional)'**
  String get homeEmailOptional;

  /// No description provided for @homeFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Failure: {message}'**
  String homeFailureMessage(String message);

  /// No description provided for @homeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeContinue;

  /// No description provided for @homeNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (Optional)'**
  String get homeNameOptional;

  /// No description provided for @homeEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get homeEnterYourName;

  /// No description provided for @homeEnterValidName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid name'**
  String get homeEnterValidName;

  /// No description provided for @homeShareLocationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Share your current location to get regional content and personalized recommendations.'**
  String get homeShareLocationPrompt;

  /// No description provided for @homeLocationDetected.
  ///
  /// In en, this message translates to:
  /// **'Location Detected'**
  String get homeLocationDetected;

  /// No description provided for @homeOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get homeOpenAppSettings;

  /// No description provided for @homeFailedToSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Failed to save location'**
  String get homeFailedToSaveLocation;

  /// No description provided for @homeCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get homeCurrentLocation;

  /// No description provided for @homeFailedToSaveLocationToProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to save location to profile'**
  String get homeFailedToSaveLocationToProfile;

  /// No description provided for @homeCouldNotDetermineLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location'**
  String get homeCouldNotDetermineLocation;

  /// No description provided for @homeSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save Location'**
  String get homeSaveLocation;

  /// No description provided for @homeUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get homeUseCurrentLocation;

  /// No description provided for @navCloseAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Close app?'**
  String get navCloseAppTitle;

  /// No description provided for @navCloseAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to close the app?'**
  String get navCloseAppMessage;

  /// No description provided for @navClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get navClose;

  /// No description provided for @navToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle Theme'**
  String get navToggleTheme;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want Logout?'**
  String get navLogoutConfirm;

  /// No description provided for @cardMuteTrailer.
  ///
  /// In en, this message translates to:
  /// **'Mute trailer'**
  String get cardMuteTrailer;

  /// No description provided for @cardUnmuteTrailer.
  ///
  /// In en, this message translates to:
  /// **'Unmute trailer'**
  String get cardUnmuteTrailer;

  /// No description provided for @cardDefaultGenre.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get cardDefaultGenre;

  /// No description provided for @cardVideoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Video is not available'**
  String get cardVideoNotAvailable;

  /// No description provided for @cardNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'NA'**
  String get cardNotApplicable;

  /// No description provided for @cardRentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to rent {title}?'**
  String cardRentConfirm(String title);

  /// No description provided for @cardRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove Bookmark'**
  String get cardRemoveBookmark;

  /// No description provided for @cardBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get cardBookmark;

  /// No description provided for @cardRemovedFromBookmarks.
  ///
  /// In en, this message translates to:
  /// **'{title} removed from bookmarks'**
  String cardRemovedFromBookmarks(String title);

  /// No description provided for @cardAddedToBookmarks.
  ///
  /// In en, this message translates to:
  /// **'{title} added to bookmarks'**
  String cardAddedToBookmarks(String title);

  /// No description provided for @cardShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get cardShare;

  /// No description provided for @cardContentDetailsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Content details are not available yet'**
  String get cardContentDetailsNotAvailable;

  /// No description provided for @cardGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get cardGift;

  /// No description provided for @cardGiftMovie.
  ///
  /// In en, this message translates to:
  /// **'Gift Movie'**
  String get cardGiftMovie;

  /// No description provided for @cardGiftHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many people do you want to gift this movie to?'**
  String get cardGiftHowMany;

  /// No description provided for @cardRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get cardRecipients;

  /// No description provided for @cardEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get cardEnterValidNumber;

  /// No description provided for @cardPercentWatched.
  ///
  /// In en, this message translates to:
  /// **'{percent}% watched'**
  String cardPercentWatched(int percent);

  /// No description provided for @cardRentSeries.
  ///
  /// In en, this message translates to:
  /// **'Rent Series'**
  String get cardRentSeries;

  /// No description provided for @cardEpisodeVideoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Episode video is not available at the moment.'**
  String get cardEpisodeVideoNotAvailable;

  /// No description provided for @cardResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume {title}'**
  String cardResumeTitle(String title);

  /// No description provided for @cardResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get cardResume;

  /// No description provided for @cardGeneratingShareQr.
  ///
  /// In en, this message translates to:
  /// **'Generating share QR code...'**
  String get cardGeneratingShareQr;

  /// No description provided for @cardUnableToPrepareShare.
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare this share right now. Please try again.'**
  String get cardUnableToPrepareShare;

  /// No description provided for @cardShareContent.
  ///
  /// In en, this message translates to:
  /// **'Share Content'**
  String get cardShareContent;

  /// No description provided for @cardScanToWatch.
  ///
  /// In en, this message translates to:
  /// **'Scan to watch on Filmytell'**
  String get cardScanToWatch;

  /// No description provided for @cardUniversalLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Universal link copied to clipboard'**
  String get cardUniversalLinkCopied;

  /// No description provided for @cardCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get cardCopyLink;

  /// No description provided for @cardShareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Share link copied to clipboard'**
  String get cardShareLinkCopied;

  /// No description provided for @cardFailedToShare.
  ///
  /// In en, this message translates to:
  /// **'Failed to share content'**
  String get cardFailedToShare;

  /// No description provided for @cardTypeMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get cardTypeMovie;

  /// No description provided for @searchNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get searchNotAvailable;

  /// No description provided for @searchCrew.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get searchCrew;

  /// No description provided for @upcomingNotifiedOnRelease.
  ///
  /// In en, this message translates to:
  /// **'You’ll be notified on release day'**
  String get upcomingNotifiedOnRelease;

  /// No description provided for @upcomingNoContent.
  ///
  /// In en, this message translates to:
  /// **'No upcoming content'**
  String get upcomingNoContent;

  /// No description provided for @notifLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please log in again to view notifications.'**
  String get notifLoginAgain;

  /// No description provided for @notifRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed.'**
  String get notifRequestFailed;

  /// No description provided for @notifNoDataReturned.
  ///
  /// In en, this message translates to:
  /// **'No notification data returned.'**
  String get notifNoDataReturned;

  /// No description provided for @notifInvalidServerResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid server response. Please try again.'**
  String get notifInvalidServerResponse;

  /// No description provided for @notifUnableToFetch.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch notifications. Please try again.'**
  String get notifUnableToFetch;

  /// No description provided for @notifNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get notifNoNotifications;

  /// No description provided for @notifSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get notifSubject;

  /// No description provided for @notifSentBy.
  ///
  /// In en, this message translates to:
  /// **'Sent By'**
  String get notifSentBy;

  /// No description provided for @notifSentDate.
  ///
  /// In en, this message translates to:
  /// **'Sent Date'**
  String get notifSentDate;

  /// No description provided for @notifDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get notifDetails;

  /// No description provided for @notifAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get notifAttachments;

  /// No description provided for @notifAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get notifAttachment;

  /// No description provided for @notifAttachmentUrlUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachment URL is not available.'**
  String get notifAttachmentUrlUnavailable;

  /// No description provided for @notifUnableToOpenAttachment.
  ///
  /// In en, this message translates to:
  /// **'Unable to open attachment.'**
  String get notifUnableToOpenAttachment;

  /// No description provided for @shortsNoMiniSeriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Mini Series available'**
  String get shortsNoMiniSeriesAvailable;

  /// No description provided for @shortsTrending.
  ///
  /// In en, this message translates to:
  /// **'TRENDING'**
  String get shortsTrending;

  /// No description provided for @shortsPricePerPartWithLanguages.
  ///
  /// In en, this message translates to:
  /// **'₹ {coins} /part | {languages}'**
  String shortsPricePerPartWithLanguages(int coins, String languages);

  /// No description provided for @shortsPartsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Part} other{{count} Parts}}'**
  String shortsPartsCount(int count);

  /// No description provided for @shortsMiniSeriesDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Mini series details are not available yet'**
  String get shortsMiniSeriesDetailsUnavailable;

  /// No description provided for @playerInvalidVideo.
  ///
  /// In en, this message translates to:
  /// **'Invalid video'**
  String get playerInvalidVideo;

  /// No description provided for @playerVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get playerVideoUnavailable;

  /// No description provided for @playerSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get playerSessionExpired;

  /// No description provided for @playerFailedToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get playerFailedToLoadVideo;

  /// No description provided for @shortsInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance'**
  String get shortsInsufficientBalance;

  /// No description provided for @shortsNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have enough coins.'**
  String get shortsNotEnoughCoins;

  /// No description provided for @shortsSeeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get shortsSeeMore;

  /// No description provided for @shortsSeeLess.
  ///
  /// In en, this message translates to:
  /// **'See less'**
  String get shortsSeeLess;

  /// No description provided for @shortsShareAction.
  ///
  /// In en, this message translates to:
  /// **'share'**
  String get shortsShareAction;

  /// No description provided for @shortsShareTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Share text copied to clipboard'**
  String get shortsShareTextCopied;

  /// No description provided for @shortsEpisodeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Episode {current} / {total}'**
  String shortsEpisodeOfTotal(int current, int total);

  /// No description provided for @shortsEpisodeShort.
  ///
  /// In en, this message translates to:
  /// **'EP {number}'**
  String shortsEpisodeShort(int number);

  /// No description provided for @playerUnableToPlayTrailer.
  ///
  /// In en, this message translates to:
  /// **'Unable to play this trailer.'**
  String get playerUnableToPlayTrailer;

  /// No description provided for @playerPlayTrailerFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Play trailer fullscreen'**
  String get playerPlayTrailerFullscreen;

  /// No description provided for @playerFullscreenTrailer.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen trailer'**
  String get playerFullscreenTrailer;

  /// No description provided for @playerPauseTrailer.
  ///
  /// In en, this message translates to:
  /// **'Pause trailer'**
  String get playerPauseTrailer;

  /// No description provided for @playerPlayTrailerAction.
  ///
  /// In en, this message translates to:
  /// **'Play trailer'**
  String get playerPlayTrailerAction;

  /// No description provided for @playerTrailerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trailer unavailable'**
  String get playerTrailerUnavailable;

  /// No description provided for @detailsMovieVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Movie video is not available at the moment.'**
  String get detailsMovieVideoUnavailable;

  /// No description provided for @detailsContentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This content is currently unavailable. Please try again later.'**
  String get detailsContentUnavailable;

  /// No description provided for @detailsRatingValue.
  ///
  /// In en, this message translates to:
  /// **'{rating} rating'**
  String detailsRatingValue(String rating);

  /// No description provided for @detailsRuntimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String detailsRuntimeMinutes(int minutes);

  /// No description provided for @detailsRentPrice.
  ///
  /// In en, this message translates to:
  /// **'Rent Rs {price}'**
  String detailsRentPrice(String price);

  /// No description provided for @detailsMovieDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Movie details are not available yet'**
  String get detailsMovieDetailsUnavailable;

  /// No description provided for @detailsWatchlisted.
  ///
  /// In en, this message translates to:
  /// **'Watchlisted'**
  String get detailsWatchlisted;

  /// No description provided for @detailsAddToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist'**
  String get detailsAddToWatchlist;

  /// No description provided for @detailsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get detailsDownload;

  /// No description provided for @detailsDownloadNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Download is not available for this movie.'**
  String get detailsDownloadNotAvailable;

  /// No description provided for @detailsDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String detailsDownloadingPercent(String percent);

  /// No description provided for @detailsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get detailsDownloaded;

  /// No description provided for @detailsDownloadUpdated.
  ///
  /// In en, this message translates to:
  /// **'Download updated'**
  String get detailsDownloadUpdated;

  /// No description provided for @detailsCastAndCrew.
  ///
  /// In en, this message translates to:
  /// **'Cast & Crew'**
  String get detailsCastAndCrew;

  /// No description provided for @detailsCastAndCrewText.
  ///
  /// In en, this message translates to:
  /// **'Cast and Crew'**
  String get detailsCastAndCrewText;

  /// No description provided for @detailsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get detailsUntitled;

  /// No description provided for @detailsMoreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More Like This'**
  String get detailsMoreLikeThis;

  /// No description provided for @detailsTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get detailsTrending;

  /// No description provided for @detailsRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get detailsRecommended;

  /// No description provided for @detailsGiftThisMovie.
  ///
  /// In en, this message translates to:
  /// **'Gift This Movie'**
  String get detailsGiftThisMovie;

  /// No description provided for @detailsGiftRecipientsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter how many people you\'d like to gift this movie to.'**
  String get detailsGiftRecipientsPrompt;

  /// No description provided for @detailsNumberOfRecipients.
  ///
  /// In en, this message translates to:
  /// **'Number of recipients'**
  String get detailsNumberOfRecipients;

  /// No description provided for @detailsEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid number'**
  String get detailsEnterValidNumber;

  /// No description provided for @detailsReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{(1 review)} other{({count} reviews)}}'**
  String detailsReviewsCount(int count);

  /// No description provided for @detailsGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get detailsGallery;

  /// No description provided for @detailsReleaseOn.
  ///
  /// In en, this message translates to:
  /// **'Release On: {date}'**
  String detailsReleaseOn(String date);

  /// No description provided for @detailsReleaseOnComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Release On: Coming Soon'**
  String get detailsReleaseOnComingSoon;

  /// No description provided for @detailsUniversalAge.
  ///
  /// In en, this message translates to:
  /// **'Universal Age'**
  String get detailsUniversalAge;

  /// No description provided for @detailsParentalGuidance.
  ///
  /// In en, this message translates to:
  /// **'Parental Guidance'**
  String get detailsParentalGuidance;

  /// No description provided for @detailsAdultsOnly.
  ///
  /// In en, this message translates to:
  /// **'Adults Only'**
  String get detailsAdultsOnly;

  /// No description provided for @detailsRemoveOffline.
  ///
  /// In en, this message translates to:
  /// **'Remove Offline'**
  String get detailsRemoveOffline;

  /// No description provided for @detailsActionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Action completed.'**
  String get detailsActionCompleted;

  /// No description provided for @detailsRentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to rent this {type}?'**
  String detailsRentConfirm(String type);

  /// No description provided for @detailsRateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience'**
  String get detailsRateYourExperience;

  /// No description provided for @detailsYourFeedback.
  ///
  /// In en, this message translates to:
  /// **'Your Feedback!'**
  String get detailsYourFeedback;

  /// No description provided for @detailsPleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select rating..'**
  String get detailsPleaseSelectRating;

  /// No description provided for @detailsReviewSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'something went wrong to submit review'**
  String get detailsReviewSubmitFailed;

  /// No description provided for @detailsReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'review submitted successfully'**
  String get detailsReviewSubmitted;

  /// No description provided for @detailsSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get detailsSubmitReview;

  /// No description provided for @detailsAnonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous User'**
  String get detailsAnonymousUser;

  /// No description provided for @detailsNoSeasonsYet.
  ///
  /// In en, this message translates to:
  /// **'No seasons available yet'**
  String get detailsNoSeasonsYet;

  /// No description provided for @detailsNoEpisodesYet.
  ///
  /// In en, this message translates to:
  /// **'No episodes available yet'**
  String get detailsNoEpisodesYet;

  /// No description provided for @detailsEpisodesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Episodes coming soon'**
  String get detailsEpisodesComingSoon;

  /// No description provided for @detailsSeasonsAndEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Seasons & Episodes'**
  String get detailsSeasonsAndEpisodes;

  /// No description provided for @detailsSeasonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 season} other{{count} seasons}}'**
  String detailsSeasonsCount(int count);

  /// No description provided for @detailsEpisodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}}'**
  String detailsEpisodesCount(int count);

  /// No description provided for @detailsResumeWatching.
  ///
  /// In en, this message translates to:
  /// **'Resume Watching'**
  String get detailsResumeWatching;

  /// No description provided for @detailsSeriesDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Series details are not available yet'**
  String get detailsSeriesDetailsUnavailable;

  /// No description provided for @detailsDownloadNotAvailableSeries.
  ///
  /// In en, this message translates to:
  /// **'Download is not available for this series.'**
  String get detailsDownloadNotAvailableSeries;

  /// No description provided for @detailsSeasonN.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String detailsSeasonN(int number);

  /// No description provided for @detailsSeasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Season {number}: {title}'**
  String detailsSeasonTitle(int number, String title);

  /// No description provided for @detailsRentSeasonPrice.
  ///
  /// In en, this message translates to:
  /// **'Rent Season ₹{price}'**
  String detailsRentSeasonPrice(String price);

  /// No description provided for @detailsRentCompleteSeasonPrice.
  ///
  /// In en, this message translates to:
  /// **'Rent complete Season ₹{price}'**
  String detailsRentCompleteSeasonPrice(String price);

  /// No description provided for @detailsContinueWatchingPercent.
  ///
  /// In en, this message translates to:
  /// **'Continue watching - {percent}%'**
  String detailsContinueWatchingPercent(int percent);

  /// No description provided for @detailsEpisodeN.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String detailsEpisodeN(int number);

  /// No description provided for @detailsRecommendedSeries.
  ///
  /// In en, this message translates to:
  /// **'Recommended Series'**
  String get detailsRecommendedSeries;

  /// No description provided for @detailsRelatedContent.
  ///
  /// In en, this message translates to:
  /// **'Related Content'**
  String get detailsRelatedContent;

  /// No description provided for @detailsEpisodeUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Episode unlocked! Enjoy watching 🎬'**
  String get detailsEpisodeUnlocked;

  /// No description provided for @detailsSeasonUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Season unlocked! Enjoy watching 🎬'**
  String get detailsSeasonUnlocked;

  /// No description provided for @detailsGiftThisSeries.
  ///
  /// In en, this message translates to:
  /// **'Gift This Series'**
  String get detailsGiftThisSeries;

  /// No description provided for @detailsGiftSeriesRecipientsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter how many people you\'d like to gift this series to.'**
  String get detailsGiftSeriesRecipientsPrompt;

  /// No description provided for @detailsGiftSeries.
  ///
  /// In en, this message translates to:
  /// **'Gift Series'**
  String get detailsGiftSeries;

  /// No description provided for @detailsEpisodeRuntime.
  ///
  /// In en, this message translates to:
  /// **'Ep. {number} • {runtime}'**
  String detailsEpisodeRuntime(int number, String runtime);

  /// No description provided for @seriesPageNoSeriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No series available'**
  String get seriesPageNoSeriesAvailable;

  /// No description provided for @playerFailedToResumeVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to resume video'**
  String get playerFailedToResumeVideo;

  /// No description provided for @playerContentNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested content was not found.'**
  String get playerContentNotFound;

  /// No description provided for @playerRewind10Seconds.
  ///
  /// In en, this message translates to:
  /// **'Rewind 10 seconds'**
  String get playerRewind10Seconds;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerForward10Seconds.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get playerForward10Seconds;

  /// No description provided for @playerNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next Episode'**
  String get playerNextEpisode;

  /// No description provided for @playerMovieAlreadyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Movie is already downloaded.'**
  String get playerMovieAlreadyDownloaded;

  /// No description provided for @playerUnmuteMic.
  ///
  /// In en, this message translates to:
  /// **'Unmute Mic'**
  String get playerUnmuteMic;

  /// No description provided for @playerMuteMic.
  ///
  /// In en, this message translates to:
  /// **'Mute Mic'**
  String get playerMuteMic;

  /// No description provided for @playerMicMuted.
  ///
  /// In en, this message translates to:
  /// **'Mic Muted'**
  String get playerMicMuted;

  /// No description provided for @playerMicEnabled.
  ///
  /// In en, this message translates to:
  /// **'Mic Enabled'**
  String get playerMicEnabled;

  /// No description provided for @playerPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerPlaybackSpeed;

  /// No description provided for @playerResumedFrom.
  ///
  /// In en, this message translates to:
  /// **'Resumed from {time}'**
  String playerResumedFrom(String time);

  /// No description provided for @playerStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get playerStartOver;

  /// No description provided for @profileUnableOpenPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Unable to open privacy policy page right now.'**
  String get profileUnableOpenPrivacyPolicy;

  /// No description provided for @profileUnableOpenTerms.
  ///
  /// In en, this message translates to:
  /// **'Unable to open terms and condition right now.'**
  String get profileUnableOpenTerms;

  /// No description provided for @profileUnableOpenRating.
  ///
  /// In en, this message translates to:
  /// **'Unable to open rating page right now.'**
  String get profileUnableOpenRating;

  /// No description provided for @profileBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get profileBookmarks;

  /// No description provided for @profileRegisteredDevices.
  ///
  /// In en, this message translates to:
  /// **'Registered Devices'**
  String get profileRegisteredDevices;

  /// No description provided for @profileAppTour.
  ///
  /// In en, this message translates to:
  /// **'App Tour'**
  String get profileAppTour;

  /// No description provided for @profileTermsCondition.
  ///
  /// In en, this message translates to:
  /// **'Terms & Condition'**
  String get profileTermsCondition;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Version - {version}'**
  String profileVersion(String version);

  /// No description provided for @profileCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright Filmytell - All Rights Reserved.'**
  String get profileCopyright;

  /// No description provided for @profileTechnicalPartner.
  ///
  /// In en, this message translates to:
  /// **'Technical Partner'**
  String get profileTechnicalPartner;

  /// No description provided for @profileUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUserFallback;

  /// No description provided for @profileDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get profileDiscardChangesTitle;

  /// No description provided for @profileDiscardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to go back?'**
  String get profileDiscardChangesBody;

  /// No description provided for @profileDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get profileDiscard;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get profileEnterValidEmail;

  /// No description provided for @profileBirthDateMonthYear.
  ///
  /// In en, this message translates to:
  /// **'Birth Date (Month & Year)'**
  String get profileBirthDateMonthYear;

  /// No description provided for @profileSelectBirthMonthYear.
  ///
  /// In en, this message translates to:
  /// **'Select birth month and year'**
  String get profileSelectBirthMonthYear;

  /// No description provided for @profileAboutHeadline.
  ///
  /// In en, this message translates to:
  /// **'Filmytell – Rent Movies & Series'**
  String get profileAboutHeadline;

  /// No description provided for @profileAboutSubheadline.
  ///
  /// In en, this message translates to:
  /// **'No ads. No subscriptions. Just pure cinema.'**
  String get profileAboutSubheadline;

  /// No description provided for @profilePayPerView.
  ///
  /// In en, this message translates to:
  /// **'Pay Per View'**
  String get profilePayPerView;

  /// No description provided for @profileNoAds.
  ///
  /// In en, this message translates to:
  /// **'No Ads'**
  String get profileNoAds;

  /// No description provided for @profileExclusive.
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get profileExclusive;

  /// No description provided for @profileAboutIntro.
  ///
  /// In en, this message translates to:
  /// **'Your personal theatre in your pocket.\nWatch movies, web series & mini series anytime, anywhere.'**
  String get profileAboutIntro;

  /// No description provided for @profileWhyFilmytell.
  ///
  /// In en, this message translates to:
  /// **'Why Filmytell'**
  String get profileWhyFilmytell;

  /// No description provided for @profilePayPerViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only pay for what you watch'**
  String get profilePayPerViewSubtitle;

  /// No description provided for @profileNoAdsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uninterrupted experience'**
  String get profileNoAdsSubtitle;

  /// No description provided for @profileExclusiveContent.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Content'**
  String get profileExclusiveContent;

  /// No description provided for @profileExclusiveContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Independent & unique stories'**
  String get profileExclusiveContentSubtitle;

  /// No description provided for @profileWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get profileWatch;

  /// No description provided for @profileWebSeries.
  ///
  /// In en, this message translates to:
  /// **'Web Series'**
  String get profileWebSeries;

  /// No description provided for @profileRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get profileRegional;

  /// No description provided for @profileViewers.
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get profileViewers;

  /// No description provided for @profileViewersContent.
  ///
  /// In en, this message translates to:
  /// **'Watch anytime\nNo commitment'**
  String get profileViewersContent;

  /// No description provided for @profileCreators.
  ///
  /// In en, this message translates to:
  /// **'Creators'**
  String get profileCreators;

  /// No description provided for @profileCreatorsContent.
  ///
  /// In en, this message translates to:
  /// **'Reach global audience'**
  String get profileCreatorsContent;

  /// No description provided for @profileNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get profileNotAdded;

  /// No description provided for @profileEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get profileEmailAddress;

  /// No description provided for @profilePersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal Details'**
  String get profilePersonalDetails;

  /// No description provided for @profileBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get profileBirthday;

  /// No description provided for @profileAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddress;

  /// No description provided for @profileAddressLine.
  ///
  /// In en, this message translates to:
  /// **'Address Line'**
  String get profileAddressLine;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profilePincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get profilePincode;

  /// No description provided for @profileDeleteAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Delete your Filmytell account and personal profile data. Purchases, wallet activity, support tickets, and records required for legal, tax, security, or fraud-prevention purposes may be retained as required by law.'**
  String get profileDeleteAccountInfo;

  /// No description provided for @profileDeletionInfo.
  ///
  /// In en, this message translates to:
  /// **'Deletion Info'**
  String get profileDeletionInfo;

  /// No description provided for @profileDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get profileDeleting;

  /// No description provided for @profileDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDelete;

  /// No description provided for @profileUnableOpenAccountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Unable to open account deletion page right now.'**
  String get profileUnableOpenAccountDeletion;

  /// No description provided for @profileAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Unable to find your account. Please log in again.'**
  String get profileAccountNotFound;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your Filmytell account. You will be logged out after the request is completed.'**
  String get profileDeleteAccountConfirm;

  /// No description provided for @profileAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get profileAccountDeleted;

  /// No description provided for @profileUnableDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete account right now. Please try again.'**
  String get profileUnableDeleteAccount;

  /// No description provided for @profileSearchAddress.
  ///
  /// In en, this message translates to:
  /// **'Search your address'**
  String get profileSearchAddress;

  /// No description provided for @profileFetchingLocation.
  ///
  /// In en, this message translates to:
  /// **'Fetching location...'**
  String get profileFetchingLocation;

  /// No description provided for @profileUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get profileUseCurrentLocation;

  /// No description provided for @profileEnterCountry.
  ///
  /// In en, this message translates to:
  /// **'Enter country'**
  String get profileEnterCountry;

  /// No description provided for @profileEnterState.
  ///
  /// In en, this message translates to:
  /// **'Enter state'**
  String get profileEnterState;

  /// No description provided for @profileEnterDistrict.
  ///
  /// In en, this message translates to:
  /// **'Enter district'**
  String get profileEnterDistrict;

  /// No description provided for @profileEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter city'**
  String get profileEnterCity;

  /// No description provided for @profileEnterPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter pincode'**
  String get profileEnterPincode;

  /// No description provided for @profileAddressUpdated.
  ///
  /// In en, this message translates to:
  /// **'Address updated successfully!'**
  String get profileAddressUpdated;

  /// No description provided for @profileFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String profileFieldRequired(String field);

  /// No description provided for @profileNoOptionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No options available'**
  String get profileNoOptionsAvailable;

  /// No description provided for @profileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get profileSaveChanges;

  /// No description provided for @langSelectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one language.'**
  String get langSelectAtLeastOne;

  /// No description provided for @langUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Language updated successfully.'**
  String get langUpdatedSuccessfully;

  /// No description provided for @langUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get langUpdateFailed;

  /// No description provided for @langPreferredLanguages.
  ///
  /// In en, this message translates to:
  /// **'Preferred Languages'**
  String get langPreferredLanguages;

  /// No description provided for @langFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load languages'**
  String get langFailedToLoad;

  /// No description provided for @langMajorIndianLanguages.
  ///
  /// In en, this message translates to:
  /// **'Major Indian Languages'**
  String get langMajorIndianLanguages;

  /// No description provided for @langOtherIndianLanguages.
  ///
  /// In en, this message translates to:
  /// **'Other Indian Languages'**
  String get langOtherIndianLanguages;

  /// No description provided for @langForeignLanguages.
  ///
  /// In en, this message translates to:
  /// **'Foreign Languages'**
  String get langForeignLanguages;

  /// No description provided for @authOtpDetectedAutomatically.
  ///
  /// In en, this message translates to:
  /// **'OTP detected automatically.'**
  String get authOtpDetectedAutomatically;

  /// No description provided for @authGiftCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Gift Code: {code}'**
  String authGiftCodeLabel(String code);

  /// No description provided for @authReferralCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral Code: {code}'**
  String authReferralCodeLabel(String code);

  /// No description provided for @authEnterValidMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid mobile number'**
  String get authEnterValidMobileNumber;

  /// No description provided for @authSearchCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Search by country name and code ..'**
  String get authSearchCountryHint;

  /// No description provided for @authResendOtpIn.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP in {time}'**
  String authResendOtpIn(String time);

  /// No description provided for @authResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get authResendOtp;

  /// No description provided for @authSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get authSomethingWentWrong;

  /// No description provided for @authInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get authInvalidOtp;

  /// No description provided for @authUnableToLogin.
  ///
  /// In en, this message translates to:
  /// **'Unable to log in right now. Please try again.'**
  String get authUnableToLogin;

  /// No description provided for @authRequestingNewOtp.
  ///
  /// In en, this message translates to:
  /// **'Requesting a new OTP...'**
  String get authRequestingNewOtp;

  /// No description provided for @authWaitingForOtpSms.
  ///
  /// In en, this message translates to:
  /// **'Waiting for OTP SMS...'**
  String get authWaitingForOtpSms;

  /// No description provided for @authUnableToResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Unable to resend OTP. Please try again.'**
  String get authUnableToResendOtp;

  /// No description provided for @authAutoFillTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill timed out. Please enter the OTP manually.'**
  String get authAutoFillTimedOut;

  /// No description provided for @authAutoFillUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill is unavailable. Please enter the OTP manually.'**
  String get authAutoFillUnavailable;

  /// No description provided for @onboardingUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get onboardingUpdateAvailable;

  /// No description provided for @onboardingUpdateAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'A newer version is available ({version}). Please update for the best experience.'**
  String onboardingUpdateAvailableMessage(String version);

  /// No description provided for @onboardingLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get onboardingLater;

  /// No description provided for @onboardingUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get onboardingUpdateNow;

  /// No description provided for @helpDateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Date unavailable'**
  String get helpDateUnavailable;

  /// No description provided for @helpResponseTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'We typically respond within 24 hours. Add details for faster help.'**
  String get helpResponseTimeInfo;

  /// No description provided for @helpAppTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay the quick guide to important app features.'**
  String get helpAppTourSubtitle;

  /// No description provided for @helpRaiseTicket.
  ///
  /// In en, this message translates to:
  /// **'Raise a Ticket'**
  String get helpRaiseTicket;

  /// No description provided for @helpPleaseEnterQuery.
  ///
  /// In en, this message translates to:
  /// **'Please enter your query'**
  String get helpPleaseEnterQuery;

  /// No description provided for @helpQueryMinLength.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least 10 characters'**
  String get helpQueryMinLength;

  /// No description provided for @helpAttachmentAdded.
  ///
  /// In en, this message translates to:
  /// **'Attachment added'**
  String get helpAttachmentAdded;

  /// No description provided for @helpRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get helpRemove;

  /// No description provided for @helpUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get helpUploading;

  /// No description provided for @helpSubmitRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit support request?'**
  String get helpSubmitRequestTitle;

  /// No description provided for @helpSubmitRequestConfirm.
  ///
  /// In en, this message translates to:
  /// **'Please confirm you want to send this help support request.'**
  String get helpSubmitRequestConfirm;

  /// No description provided for @helpYourRequests.
  ///
  /// In en, this message translates to:
  /// **'Your Requests'**
  String get helpYourRequests;

  /// No description provided for @helpNoSentTickets.
  ///
  /// In en, this message translates to:
  /// **'No sent tickets yet'**
  String get helpNoSentTickets;

  /// No description provided for @helpNoSentTicketsHint.
  ///
  /// In en, this message translates to:
  /// **'Your submitted support requests will appear here.'**
  String get helpNoSentTicketsHint;

  /// No description provided for @helpDeleteTicketTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete ticket?'**
  String get helpDeleteTicketTitle;

  /// No description provided for @helpDeleteTicketConfirm.
  ///
  /// In en, this message translates to:
  /// **'This support ticket will be removed from your sent requests.'**
  String get helpDeleteTicketConfirm;

  /// No description provided for @deviceManagement.
  ///
  /// In en, this message translates to:
  /// **'Device Management'**
  String get deviceManagement;

  /// No description provided for @deviceNoActiveDevices.
  ///
  /// In en, this message translates to:
  /// **'No active devices found.'**
  String get deviceNoActiveDevices;

  /// No description provided for @deviceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get deviceRefresh;

  /// No description provided for @deviceCurrentDevice.
  ///
  /// In en, this message translates to:
  /// **'Current device'**
  String get deviceCurrentDevice;

  /// No description provided for @deviceOs.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get deviceOs;

  /// No description provided for @deviceAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get deviceAuthorization;

  /// No description provided for @deviceBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get deviceBlocked;

  /// No description provided for @deviceAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Authorized'**
  String get deviceAuthorized;

  /// No description provided for @deviceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get deviceUnknown;

  /// No description provided for @deviceRemoveDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove Device'**
  String get deviceRemoveDevice;

  /// No description provided for @deviceRemoveDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove device?'**
  String get deviceRemoveDeviceTitle;

  /// No description provided for @deviceRemoveDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'This device will no longer be authorized for protected playback.'**
  String get deviceRemoveDeviceConfirm;

  /// No description provided for @deviceRemovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Device removed successfully.'**
  String get deviceRemovedSuccessfully;

  /// No description provided for @pickerBirthMonthInFuture.
  ///
  /// In en, this message translates to:
  /// **'Birth month cannot be in the future'**
  String get pickerBirthMonthInFuture;

  /// No description provided for @pickerSelectBirthMonthYear.
  ///
  /// In en, this message translates to:
  /// **'Select Birth Month & Year'**
  String get pickerSelectBirthMonthYear;

  /// No description provided for @pickerSelectedMonthYear.
  ///
  /// In en, this message translates to:
  /// **'Selected: {month} {year}'**
  String pickerSelectedMonthYear(String month, String year);

  /// No description provided for @pickerJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get pickerJanuary;

  /// No description provided for @pickerFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get pickerFebruary;

  /// No description provided for @pickerMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get pickerMarch;

  /// No description provided for @pickerApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get pickerApril;

  /// No description provided for @pickerMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get pickerMay;

  /// No description provided for @pickerJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get pickerJune;

  /// No description provided for @pickerJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get pickerJuly;

  /// No description provided for @pickerAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get pickerAugust;

  /// No description provided for @pickerSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get pickerSeptember;

  /// No description provided for @pickerOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get pickerOctober;

  /// No description provided for @pickerNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get pickerNovember;

  /// No description provided for @pickerDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get pickerDecember;

  /// No description provided for @walletNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get walletNoTransactions;

  /// No description provided for @walletEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get walletEnterAmount;

  /// No description provided for @payProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get payProcessing;

  /// No description provided for @payProceedToPay.
  ///
  /// In en, this message translates to:
  /// **'Proceed to pay'**
  String get payProceedToPay;

  /// No description provided for @walletEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get walletEnterValidAmount;

  /// No description provided for @walletMinimumRechargeAmountRs.
  ///
  /// In en, this message translates to:
  /// **'Minimum recharge amount is Rs {amount}'**
  String walletMinimumRechargeAmountRs(String amount);

  /// No description provided for @walletMaximumRechargeAmountRs.
  ///
  /// In en, this message translates to:
  /// **'Maximum recharge amount is Rs {amount}'**
  String walletMaximumRechargeAmountRs(String amount);

  /// No description provided for @walletRechargedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Wallet recharged successfully.'**
  String get walletRechargedSuccessfully;

  /// No description provided for @walletUpdatingBalance.
  ///
  /// In en, this message translates to:
  /// **'Updating wallet balance...'**
  String get walletUpdatingBalance;

  /// No description provided for @payPreparingSecureCheckout.
  ///
  /// In en, this message translates to:
  /// **'Preparing secure checkout...'**
  String get payPreparingSecureCheckout;

  /// No description provided for @payReadyToOpenRazorpayCheckout.
  ///
  /// In en, this message translates to:
  /// **'Ready to open secure Razorpay checkout.'**
  String get payReadyToOpenRazorpayCheckout;

  /// No description provided for @payCheckoutUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Razorpay checkout is only available on web, Android, and iOS.'**
  String get payCheckoutUnsupportedPlatform;

  /// No description provided for @payLoginAgainToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please log in again to continue payment.'**
  String get payLoginAgainToContinue;

  /// No description provided for @payCreatingRazorpayOrder.
  ///
  /// In en, this message translates to:
  /// **'Creating Razorpay order...'**
  String get payCreatingRazorpayOrder;

  /// No description provided for @payCreatingStripeCheckoutSession.
  ///
  /// In en, this message translates to:
  /// **'Creating Stripe checkout session...'**
  String get payCreatingStripeCheckoutSession;

  /// No description provided for @payOpeningRazorpayCheckout.
  ///
  /// In en, this message translates to:
  /// **'Opening Razorpay checkout...'**
  String get payOpeningRazorpayCheckout;

  /// No description provided for @payOpeningStripeCheckout.
  ///
  /// In en, this message translates to:
  /// **'Opening Stripe checkout...'**
  String get payOpeningStripeCheckout;

  /// No description provided for @payOpenCheckout.
  ///
  /// In en, this message translates to:
  /// **'Open Checkout'**
  String get payOpenCheckout;

  /// No description provided for @billingPriceAmount.
  ///
  /// In en, this message translates to:
  /// **'Price: ₹ {price}'**
  String billingPriceAmount(String price);

  /// No description provided for @billingPriceTimesGifts.
  ///
  /// In en, this message translates to:
  /// **'₹ {price} × {count} Gifts'**
  String billingPriceTimesGifts(String price, int count);

  /// No description provided for @billingTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total: ₹ {amount}'**
  String billingTotalAmount(String amount);

  /// No description provided for @billingWalletAmount.
  ///
  /// In en, this message translates to:
  /// **'Wallet: ₹ {amount}'**
  String billingWalletAmount(String amount);

  /// No description provided for @billingProceedToPay.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Pay'**
  String get billingProceedToPay;

  /// No description provided for @billingHaveTitleGiftCard.
  ///
  /// In en, this message translates to:
  /// **'Have a {title} Gift Card?'**
  String billingHaveTitleGiftCard(String title);

  /// No description provided for @walletNoTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get walletNoTransactionsYet;

  /// No description provided for @billingConfirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'Confirm Purchase'**
  String get billingConfirmPurchase;

  /// No description provided for @billingConfirmPurchaseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to confirm the purchase?'**
  String get billingConfirmPurchaseQuestion;

  /// No description provided for @billingConfirmAndPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay'**
  String get billingConfirmAndPay;

  /// No description provided for @walletInsufficientBalanceRecharge.
  ///
  /// In en, this message translates to:
  /// **'Insufficient wallet balance. Please recharge your wallet.'**
  String get walletInsufficientBalanceRecharge;

  /// No description provided for @giftPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Gift purchase failed.'**
  String get giftPurchaseFailed;

  /// No description provided for @billingUnableToGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Unable to grant {contentType, select, series{series} other{movie}} access.'**
  String billingUnableToGrantAccess(String contentType);

  /// No description provided for @walletDeductionFailed.
  ///
  /// In en, this message translates to:
  /// **'Wallet deduction failed.'**
  String get walletDeductionFailed;

  /// No description provided for @paySuccessfulEnjoyContent.
  ///
  /// In en, this message translates to:
  /// **'Payment successful! Enjoy your content 🎬'**
  String get paySuccessfulEnjoyContent;

  /// No description provided for @billingProcessingPurchase.
  ///
  /// In en, this message translates to:
  /// **'Processing purchase...'**
  String get billingProcessingPurchase;

  /// No description provided for @billingPurchaseNotCompletedTryLater.
  ///
  /// In en, this message translates to:
  /// **'Purchase could not be completed. Please try again in a moment.'**
  String get billingPurchaseNotCompletedTryLater;

  /// No description provided for @billingPurchaseFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get billingPurchaseFailedTryAgain;

  /// No description provided for @billingInvoiceGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase completed, but invoice generation failed.'**
  String get billingInvoiceGenerationFailed;

  /// No description provided for @billingSeasonPurchase.
  ///
  /// In en, this message translates to:
  /// **'Season Purchase'**
  String get billingSeasonPurchase;

  /// No description provided for @billingEpisodePurchase.
  ///
  /// In en, this message translates to:
  /// **'Episode Purchase'**
  String get billingEpisodePurchase;

  /// No description provided for @billingAmountRupees.
  ///
  /// In en, this message translates to:
  /// **'Amount: ₹ {amount}'**
  String billingAmountRupees(String amount);

  /// No description provided for @billingSeasonNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String billingSeasonNumber(String number);

  /// No description provided for @billingEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String billingEpisodeNumber(String number);

  /// No description provided for @billingPurchaseSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Purchase successful'**
  String get billingPurchaseSuccessful;

  /// No description provided for @billingItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get billingItem;

  /// No description provided for @billingCoinsDeducted.
  ///
  /// In en, this message translates to:
  /// **'Coins Deducted'**
  String get billingCoinsDeducted;

  /// No description provided for @billingNewBalance.
  ///
  /// In en, this message translates to:
  /// **'New Balance'**
  String get billingNewBalance;

  /// No description provided for @billingInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get billingInvoice;

  /// No description provided for @billingAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get billingAvailable;

  /// No description provided for @billingNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get billingNotAvailable;

  /// No description provided for @giftEnterGiftCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Gift Card Number'**
  String get giftEnterGiftCardNumber;

  /// No description provided for @giftEnter16DigitNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter 16 Digit Number'**
  String get giftEnter16DigitNumber;

  /// No description provided for @giftRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get giftRedeem;

  /// No description provided for @giftCopiedText.
  ///
  /// In en, this message translates to:
  /// **'Copied: {text}'**
  String giftCopiedText(String text);

  /// No description provided for @giftShareMessage.
  ///
  /// In en, this message translates to:
  /// **'You have received a Filmytell gift: {movieTitle}\n\nClaim gift:\n{giftLink}\n\nFallback link:\n{fallbackLink}\n\nGift code: {couponCode}'**
  String giftShareMessage(String movieTitle, String giftLink,
      String fallbackLink, String couponCode);

  /// No description provided for @giftShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Filmytell movie gift'**
  String get giftShareSubject;

  /// No description provided for @giftNoHistoryAvailable.
  ///
  /// In en, this message translates to:
  /// **'No gift history available.'**
  String get giftNoHistoryAvailable;

  /// No description provided for @giftMovieNumber.
  ///
  /// In en, this message translates to:
  /// **'Movie #{id}'**
  String giftMovieNumber(String id);

  /// No description provided for @giftDateNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Date not available'**
  String get giftDateNotAvailable;

  /// No description provided for @giftThisMovie.
  ///
  /// In en, this message translates to:
  /// **'this movie'**
  String get giftThisMovie;

  /// No description provided for @giftGiftedLabel.
  ///
  /// In en, this message translates to:
  /// **'Gifted: '**
  String get giftGiftedLabel;

  /// No description provided for @giftRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining: '**
  String get giftRemainingLabel;

  /// No description provided for @giftPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price: '**
  String get giftPriceLabel;

  /// No description provided for @giftTotalPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Paid: '**
  String get giftTotalPaidLabel;

  /// No description provided for @giftCopyCouponCode.
  ///
  /// In en, this message translates to:
  /// **'Copy coupon code'**
  String get giftCopyCouponCode;

  /// No description provided for @giftShareGiftLink.
  ///
  /// In en, this message translates to:
  /// **'Share gift link'**
  String get giftShareGiftLink;

  /// No description provided for @giftShareClaimLink.
  ///
  /// In en, this message translates to:
  /// **'Share gift claim link'**
  String get giftShareClaimLink;

  /// No description provided for @giftMovieDetails.
  ///
  /// In en, this message translates to:
  /// **'Movie details'**
  String get giftMovieDetails;

  /// No description provided for @giftDetails.
  ///
  /// In en, this message translates to:
  /// **'Gift Details'**
  String get giftDetails;

  /// No description provided for @giftNoDetailsFound.
  ///
  /// In en, this message translates to:
  /// **'No gift details found'**
  String get giftNoDetailsFound;

  /// No description provided for @giftPriceRupees.
  ///
  /// In en, this message translates to:
  /// **'Price: ₹{price}'**
  String giftPriceRupees(String price);

  /// No description provided for @giftDescriptionValue.
  ///
  /// In en, this message translates to:
  /// **'Description: {description}'**
  String giftDescriptionValue(String description);

  /// No description provided for @giftCreatedDate.
  ///
  /// In en, this message translates to:
  /// **'Created Date'**
  String get giftCreatedDate;

  /// No description provided for @giftTotalGiftCount.
  ///
  /// In en, this message translates to:
  /// **'Total Gift Count'**
  String get giftTotalGiftCount;

  /// No description provided for @giftRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get giftRemaining;

  /// No description provided for @giftUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get giftUsed;

  /// No description provided for @giftTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get giftTotalPaid;

  /// No description provided for @giftUsersWhoClaimed.
  ///
  /// In en, this message translates to:
  /// **'Users who claimed'**
  String get giftUsersWhoClaimed;

  /// No description provided for @giftNoUsersClaimedYet.
  ///
  /// In en, this message translates to:
  /// **'No users have claimed this gift yet.'**
  String get giftNoUsersClaimedYet;

  /// No description provided for @watchlistDeleteDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get watchlistDeleteDownloadTitle;

  /// No description provided for @watchlistDeleteDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {title} from this device? You can download it again later.'**
  String watchlistDeleteDownloadMessage(String title);

  /// No description provided for @watchlistDownloadDeleted.
  ///
  /// In en, this message translates to:
  /// **'Download deleted.'**
  String get watchlistDownloadDeleted;

  /// No description provided for @watchlistCouldNotDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the download: {error}'**
  String watchlistCouldNotDeleteDownload(String error);

  /// No description provided for @watchlistGifted.
  ///
  /// In en, this message translates to:
  /// **'Gifted'**
  String get watchlistGifted;

  /// No description provided for @watchlistExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get watchlistExpired;

  /// No description provided for @giftCardExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String giftCardExpiresOn(String date);

  /// No description provided for @giftCardExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon · {date}'**
  String giftCardExpiringSoon(String date);

  /// No description provided for @giftCardGiftedOn.
  ///
  /// In en, this message translates to:
  /// **'Gifted on {date}'**
  String giftCardGiftedOn(String date);

  /// No description provided for @watchlistOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get watchlistOffline;

  /// No description provided for @watchlistDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get watchlistDeleteDownload;

  /// No description provided for @watchlistNoDownloadedContentFound.
  ///
  /// In en, this message translates to:
  /// **'No downloaded content found'**
  String get watchlistNoDownloadedContentFound;

  /// No description provided for @bookmarkMyBookmarks.
  ///
  /// In en, this message translates to:
  /// **'My Bookmarks'**
  String get bookmarkMyBookmarks;

  /// No description provided for @bookmarkNoBookmarksAdded.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks added'**
  String get bookmarkNoBookmarksAdded;

  /// No description provided for @bookmarkNoBookmarksFound.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks found'**
  String get bookmarkNoBookmarksFound;

  /// No description provided for @tourLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get tourLanguageTitle;

  /// No description provided for @tourLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Select app content language according to your preference.'**
  String get tourLanguageDescription;

  /// No description provided for @tourWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'Add/View your balance and view transactions.'**
  String get tourWalletDescription;

  /// No description provided for @tourProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get tourProfileTitle;

  /// No description provided for @tourProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage account settings, preferences, and personal information.'**
  String get tourProfileDescription;

  /// No description provided for @tourSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Content Faster'**
  String get tourSearchTitle;

  /// No description provided for @tourSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Search by movies, series, genres, language and rating instantly.'**
  String get tourSearchDescription;

  /// No description provided for @tourNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay Updated'**
  String get tourNotificationsTitle;

  /// No description provided for @tourNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive updates about new releases, recommendations, rewards, and important announcements.'**
  String get tourNotificationsDescription;

  /// No description provided for @tourMoreActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'More Actions'**
  String get tourMoreActionsTitle;

  /// No description provided for @tourMoreActionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Access additional options like Bookmark, Share and Gift.'**
  String get tourMoreActionsDescription;

  /// No description provided for @tourWatchlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Save for Later'**
  String get tourWatchlistTitle;

  /// No description provided for @tourWatchlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Add content to your watchlist and access it anytime.'**
  String get tourWatchlistDescription;

  /// No description provided for @tourDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Offline'**
  String get tourDownloadTitle;

  /// No description provided for @tourDownloadDescription.
  ///
  /// In en, this message translates to:
  /// **'Download your favorite content and watch it later without an internet connection.'**
  String get tourDownloadDescription;

  /// No description provided for @msgGiftPurchaseInProgress.
  ///
  /// In en, this message translates to:
  /// **'Gift purchase already in progress. Please wait.'**
  String get msgGiftPurchaseInProgress;

  /// No description provided for @msgUserNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in'**
  String get msgUserNotLoggedIn;

  /// No description provided for @msgGiftSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Gift saved successfully'**
  String get msgGiftSavedSuccessfully;

  /// No description provided for @msgFailedToSaveGift.
  ///
  /// In en, this message translates to:
  /// **'Failed to save gift'**
  String get msgFailedToSaveGift;

  /// No description provided for @msgServerErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Server error: {statusCode}'**
  String msgServerErrorCode(int statusCode);

  /// No description provided for @msgFailedToLoadGiftHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gift history'**
  String get msgFailedToLoadGiftHistory;

  /// No description provided for @msgGiftDetailsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Gift details not found'**
  String get msgGiftDetailsNotFound;

  /// No description provided for @msgErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Error: {statusCode}'**
  String msgErrorCode(int statusCode);

  /// No description provided for @msgGiftClaimInProgress.
  ///
  /// In en, this message translates to:
  /// **'Gift claim already in progress. Please wait.'**
  String get msgGiftClaimInProgress;

  /// No description provided for @msgGiftClaimTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long to respond. Please check your gift cards before trying again.'**
  String get msgGiftClaimTimeout;

  /// No description provided for @msgGiftClaimNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Unable to claim the gift card. Please check your internet connection and try again.'**
  String get msgGiftClaimNetworkError;

  /// No description provided for @msgGiftClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while claiming the gift card. Please try again later.'**
  String get msgGiftClaimFailed;

  /// No description provided for @msgPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get msgPurchaseFailed;

  /// No description provided for @msgPurchaseInProgress.
  ///
  /// In en, this message translates to:
  /// **'Purchase already in progress. Please wait.'**
  String get msgPurchaseInProgress;

  /// No description provided for @msgServerErrorTryLater.
  ///
  /// In en, this message translates to:
  /// **'Server error ({statusCode}). Please try again later.'**
  String msgServerErrorTryLater(int statusCode);

  /// No description provided for @msgSomethingWentWrongTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get msgSomethingWentWrongTryAgain;

  /// No description provided for @msgUserNotFoundPeriod.
  ///
  /// In en, this message translates to:
  /// **'User not found.'**
  String get msgUserNotFoundPeriod;

  /// No description provided for @msgPurchaseHistoryLoaded.
  ///
  /// In en, this message translates to:
  /// **'Purchase history loaded.'**
  String get msgPurchaseHistoryLoaded;

  /// No description provided for @msgFailedToLoadPurchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load purchase history.'**
  String get msgFailedToLoadPurchaseHistory;

  /// No description provided for @msgLatestMiniSeries.
  ///
  /// In en, this message translates to:
  /// **'Latest Mini Series'**
  String get msgLatestMiniSeries;

  /// No description provided for @msgTrendingMiniSeries.
  ///
  /// In en, this message translates to:
  /// **'Trending Mini Series'**
  String get msgTrendingMiniSeries;

  /// No description provided for @msgUnableToLoadMiniSeries.
  ///
  /// In en, this message translates to:
  /// **'Unable to load Mini Series. Please try again.'**
  String get msgUnableToLoadMiniSeries;

  /// No description provided for @msgUnableToLoadRegisteredDevices.
  ///
  /// In en, this message translates to:
  /// **'Unable to load registered devices.'**
  String get msgUnableToLoadRegisteredDevices;

  /// No description provided for @msgUnableToRemoveDevice.
  ///
  /// In en, this message translates to:
  /// **'Unable to remove this device.'**
  String get msgUnableToRemoveDevice;

  /// No description provided for @msgVideoNotAvailableForDownload.
  ///
  /// In en, this message translates to:
  /// **'Video is not available for download.'**
  String get msgVideoNotAvailableForDownload;

  /// No description provided for @msgDownloadAlreadyInProgress.
  ///
  /// In en, this message translates to:
  /// **'Download already in progress.'**
  String get msgDownloadAlreadyInProgress;

  /// No description provided for @msgFailedToDownloadMovie.
  ///
  /// In en, this message translates to:
  /// **'Failed to download movie.'**
  String get msgFailedToDownloadMovie;

  /// No description provided for @msgMovieDownloadedForOffline.
  ///
  /// In en, this message translates to:
  /// **'Movie downloaded for offline playback.'**
  String get msgMovieDownloadedForOffline;

  /// No description provided for @msgOfflineCopyNotFound.
  ///
  /// In en, this message translates to:
  /// **'Offline copy was not found.'**
  String get msgOfflineCopyNotFound;

  /// No description provided for @msgDownloadRemovedFromAppList.
  ///
  /// In en, this message translates to:
  /// **'Download removed from app list.'**
  String get msgDownloadRemovedFromAppList;

  /// No description provided for @msgOfflineCopyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Offline copy removed.'**
  String get msgOfflineCopyRemoved;

  /// No description provided for @msgContentAlreadyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Content is already downloaded for offline playback.'**
  String get msgContentAlreadyDownloaded;

  /// No description provided for @msgContentDownloadedForBrowser.
  ///
  /// In en, this message translates to:
  /// **'Content downloaded for offline browser playback.'**
  String get msgContentDownloadedForBrowser;

  /// No description provided for @msgFailedToDownloadContentOffline.
  ///
  /// In en, this message translates to:
  /// **'Failed to download content for offline playback.'**
  String get msgFailedToDownloadContentOffline;

  /// No description provided for @msgQueryMinLength.
  ///
  /// In en, this message translates to:
  /// **'Query must be at least 10 characters'**
  String get msgQueryMinLength;

  /// No description provided for @msgUserDetailsNotFound.
  ///
  /// In en, this message translates to:
  /// **'User details not found'**
  String get msgUserDetailsNotFound;

  /// No description provided for @msgTicketRaisedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ticket raised successfully'**
  String get msgTicketRaisedSuccessfully;

  /// No description provided for @msgNoDataReturned.
  ///
  /// In en, this message translates to:
  /// **'No data returned'**
  String get msgNoDataReturned;

  /// No description provided for @msgErrorInResponse.
  ///
  /// In en, this message translates to:
  /// **'Error in response'**
  String get msgErrorInResponse;

  /// No description provided for @msgSomethingWentWrongExclaim.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong!'**
  String get msgSomethingWentWrongExclaim;

  /// No description provided for @msgErrorAddingUser.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while adding user'**
  String get msgErrorAddingUser;

  /// No description provided for @msgTicketDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ticket deleted successfully'**
  String get msgTicketDeletedSuccessfully;

  /// No description provided for @msgUnableToDeleteTicket.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete ticket'**
  String get msgUnableToDeleteTicket;

  /// No description provided for @msgErrorDeletingTicket.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while deleting ticket'**
  String get msgErrorDeletingTicket;

  /// No description provided for @msgUserDataNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'User data is not available.'**
  String get msgUserDataNotAvailable;

  /// No description provided for @msgDataLoadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Data loaded successfully'**
  String get msgDataLoadedSuccessfully;

  /// No description provided for @msgErrorParsingData.
  ///
  /// In en, this message translates to:
  /// **'Error while parsing data'**
  String get msgErrorParsingData;

  /// No description provided for @msgLoadedCachedPurchaseContent.
  ///
  /// In en, this message translates to:
  /// **'Loaded cached purchase content.'**
  String get msgLoadedCachedPurchaseContent;

  /// No description provided for @msgErrorFetchingContent.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while fetching content'**
  String get msgErrorFetchingContent;

  /// No description provided for @msgWalletRefreshedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Wallet refreshed successfully.'**
  String get msgWalletRefreshedSuccessfully;

  /// No description provided for @msgFailedToRefreshWallet.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh wallet'**
  String get msgFailedToRefreshWallet;

  /// No description provided for @msgRechargeInProgress.
  ///
  /// In en, this message translates to:
  /// **'Recharge already in progress. Please wait.'**
  String get msgRechargeInProgress;

  /// No description provided for @msgWalletBalanceNotUpdatedYet.
  ///
  /// In en, this message translates to:
  /// **'Payment was verified, but the wallet balance has not updated yet. Please check again in a moment.'**
  String get msgWalletBalanceNotUpdatedYet;

  /// No description provided for @msgLoginAgainToUpdateWallet.
  ///
  /// In en, this message translates to:
  /// **'Please log in again to update your wallet balance.'**
  String get msgLoginAgainToUpdateWallet;

  /// No description provided for @msgWalletCreditFailedContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Payment was successful, but wallet credit failed. Please contact support.'**
  String get msgWalletCreditFailedContactSupport;

  /// No description provided for @msgWalletCreditInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Payment was successful, but wallet credit returned an invalid response.'**
  String get msgWalletCreditInvalidResponse;

  /// No description provided for @msgWalletCreditFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment was successful, but wallet credit failed.'**
  String get msgWalletCreditFailed;

  /// No description provided for @msgPaymentInProgress.
  ///
  /// In en, this message translates to:
  /// **'Payment already in progress. Please wait.'**
  String get msgPaymentInProgress;

  /// No description provided for @msgPaymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get msgPaymentSuccessful;

  /// No description provided for @msgWalletPaymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Wallet payment could not be completed. Please try again in a moment.'**
  String get msgWalletPaymentNotCompleted;

  /// No description provided for @msgWalletPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Wallet payment failed. Please try again.'**
  String get msgWalletPaymentFailed;

  /// No description provided for @msgSecurePlaybackNotPrepared.
  ///
  /// In en, this message translates to:
  /// **'Secure playback could not be prepared.'**
  String get msgSecurePlaybackNotPrepared;

  /// No description provided for @msgSecurePlaybackNotRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Secure playback could not be refreshed. Please retry.'**
  String get msgSecurePlaybackNotRefreshed;

  /// No description provided for @msgUserCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User created successfully'**
  String get msgUserCreatedSuccessfully;

  /// No description provided for @msgUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get msgUserNotFound;

  /// No description provided for @msgErrorUpdatingUser.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while update user'**
  String get msgErrorUpdatingUser;

  /// No description provided for @msgLocationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled on your device. Please enable location services in Settings.'**
  String get msgLocationServicesDisabled;

  /// No description provided for @msgLocationPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Please grant permission in App Settings, or tap Cancel.'**
  String get msgLocationPermissionPermanentlyDenied;

  /// No description provided for @msgLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. Tap Use Current Location to try again, or Cancel to continue.'**
  String get msgLocationPermissionDenied;

  /// No description provided for @locationEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get locationEnable;

  /// No description provided for @locationEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter Location Manually'**
  String get locationEnterManually;

  /// No description provided for @msgUnableToDetermineGpsLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine GPS location. Please check your GPS and try again.'**
  String get msgUnableToDetermineGpsLocation;

  /// No description provided for @msgReverseGeocodingStatusCode.
  ///
  /// In en, this message translates to:
  /// **'Reverse geocoding service returned status code {statusCode}.'**
  String msgReverseGeocodingStatusCode(int statusCode);

  /// No description provided for @msgUnableToResolveAddress.
  ///
  /// In en, this message translates to:
  /// **'Unable to resolve address ({reason}).'**
  String msgUnableToResolveAddress(String reason);

  /// No description provided for @msgNoAddressDetailsFound.
  ///
  /// In en, this message translates to:
  /// **'No address details found for your current coordinates.'**
  String get msgNoAddressDetailsFound;

  /// No description provided for @msgUnexpectedLocationError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while fetching location.'**
  String get msgUnexpectedLocationError;

  /// No description provided for @msgOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent'**
  String get msgOtpSent;

  /// No description provided for @msgUnableToSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Unable to send OTP. Please try again.'**
  String get msgUnableToSendOtp;

  /// No description provided for @msgUserLoggedInSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User logged in successfully'**
  String get msgUserLoggedInSuccessfully;

  /// No description provided for @msgNoInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get msgNoInternetConnection;

  /// No description provided for @msgServerTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long to respond. Please try again.'**
  String get msgServerTimeout;

  /// No description provided for @msgServerErrorTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get msgServerErrorTryAgainLater;

  /// No description provided for @sysPaymentStripeCheckoutUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Stripe checkout is only available on web, Android, and iOS.'**
  String get sysPaymentStripeCheckoutUnsupportedPlatform;

  /// No description provided for @sysPaymentInvalidStripeCheckoutUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid Stripe checkout URL returned from server.'**
  String get sysPaymentInvalidStripeCheckoutUrl;

  /// No description provided for @sysPaymentInvalidStripeCheckoutLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid Stripe checkout link.'**
  String get sysPaymentInvalidStripeCheckoutLink;

  /// No description provided for @sysPaymentUnableLaunchStripeCheckout.
  ///
  /// In en, this message translates to:
  /// **'Unable to launch Stripe checkout.'**
  String get sysPaymentUnableLaunchStripeCheckout;

  /// No description provided for @sysPaymentStripeCheckoutError.
  ///
  /// In en, this message translates to:
  /// **'Stripe checkout error.'**
  String get sysPaymentStripeCheckoutError;

  /// No description provided for @sysPaymentVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Payment verified successfully.'**
  String get sysPaymentVerifiedSuccessfully;

  /// No description provided for @sysPaymentVerificationFailedContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Payment verification failed. Please contact support if money was deducted.'**
  String get sysPaymentVerificationFailedContactSupport;

  /// No description provided for @sysPaymentVerificationInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Payment verification returned an invalid response. Please contact support if money was deducted.'**
  String get sysPaymentVerificationInvalidResponse;

  /// No description provided for @sysPaymentConfigureRazorpayKey.
  ///
  /// In en, this message translates to:
  /// **'Configure your Razorpay key before using checkout.'**
  String get sysPaymentConfigureRazorpayKey;

  /// No description provided for @sysPaymentVerificationDataIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Payment completed, but verification data is incomplete.'**
  String get sysPaymentVerificationDataIncomplete;

  /// No description provided for @sysPaymentVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment verification failed.'**
  String get sysPaymentVerificationFailed;

  /// No description provided for @sysPaymentCancelledOrFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled or failed.'**
  String get sysPaymentCancelledOrFailed;

  /// No description provided for @sysPaymentUnableOpenRazorpayCheckout.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Razorpay checkout.'**
  String get sysPaymentUnableOpenRazorpayCheckout;

  /// No description provided for @sysPaymentExternalWalletPending.
  ///
  /// In en, this message translates to:
  /// **'External wallet selected ({walletName}). Verification is pending.'**
  String sysPaymentExternalWalletPending(String walletName);

  /// No description provided for @sysPaymentUnknownWallet.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get sysPaymentUnknownWallet;

  /// No description provided for @sysRazorpayWebCheckoutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Razorpay web checkout is unavailable on this platform.'**
  String get sysRazorpayWebCheckoutUnavailable;

  /// No description provided for @sysRazorpayWebCheckoutEmptyResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected empty response from Razorpay web checkout.'**
  String get sysRazorpayWebCheckoutEmptyResponse;

  /// No description provided for @sysRazorpayWebCheckoutUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from Razorpay web checkout.'**
  String get sysRazorpayWebCheckoutUnexpectedResponse;

  /// No description provided for @sysPlaybackDeviceListUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The registered device list could not be read.'**
  String get sysPlaybackDeviceListUnreadable;

  /// No description provided for @sysPlaybackSecureConnectionRequired.
  ///
  /// In en, this message translates to:
  /// **'A secure connection is required for playback.'**
  String get sysPlaybackSecureConnectionRequired;

  /// No description provided for @sysPlaybackServiceNoResponse.
  ///
  /// In en, this message translates to:
  /// **'The secure playback service did not respond. Please retry.'**
  String get sysPlaybackServiceNoResponse;

  /// No description provided for @sysPlaybackCheckConnectionRetry.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and retry.'**
  String get sysPlaybackCheckConnectionRetry;

  /// No description provided for @sysPlaybackDeviceLimitReached.
  ///
  /// In en, this message translates to:
  /// **'The maximum registered-device limit has been reached. Remove an old device and retry.'**
  String get sysPlaybackDeviceLimitReached;

  /// No description provided for @sysPlaybackNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Playback is not allowed for this account or device.'**
  String get sysPlaybackNotAllowed;

  /// No description provided for @sysPlaybackContentOrSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested content or playback session was not found.'**
  String get sysPlaybackContentOrSessionNotFound;

  /// No description provided for @sysPlaybackTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many playback requests. Please wait and retry.'**
  String get sysPlaybackTooManyRequests;

  /// No description provided for @sysPlaybackNotConfiguredForPlatform.
  ///
  /// In en, this message translates to:
  /// **'Secure playback is not configured for this platform.'**
  String get sysPlaybackNotConfiguredForPlatform;

  /// No description provided for @sysPlaybackNoSecureSource.
  ///
  /// In en, this message translates to:
  /// **'This content does not have a secure playback source.'**
  String get sysPlaybackNoSecureSource;

  /// No description provided for @sysDownloadNotEnoughStorage.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage available for this download.'**
  String get sysDownloadNotEnoughStorage;

  /// No description provided for @sysDownloadHlsMovieFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download HLS movie.'**
  String get sysDownloadHlsMovieFailed;

  /// No description provided for @sysWalletBalanceUpdatedHistoryPending.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance updated. Transaction history will refresh shortly.'**
  String get sysWalletBalanceUpdatedHistoryPending;

  /// No description provided for @sysSessionReplacedOnOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired because you logged in from another device.'**
  String get sysSessionReplacedOnOtherDevice;

  /// No description provided for @sysContentShareMessage.
  ///
  /// In en, this message translates to:
  /// **'🎬 {title}\n\nWatch now 👇\n{link}\n\n📲 Download App:\niOS App Store: {appStoreLink}\nAndroid Play Store: {playStoreLink}\nWeb: {webLink}'**
  String sysContentShareMessage(String title, String link, String appStoreLink,
      String playStoreLink, String webLink);

  /// No description provided for @sysShareLabelMovie.
  ///
  /// In en, this message translates to:
  /// **'movie'**
  String get sysShareLabelMovie;

  /// No description provided for @sysShareLabelShortFilm.
  ///
  /// In en, this message translates to:
  /// **'short film'**
  String get sysShareLabelShortFilm;

  /// No description provided for @sysShareLabelSeries.
  ///
  /// In en, this message translates to:
  /// **'series'**
  String get sysShareLabelSeries;

  /// No description provided for @sysShareLabelMiniSeries.
  ///
  /// In en, this message translates to:
  /// **'mini series'**
  String get sysShareLabelMiniSeries;

  /// No description provided for @sysShareLabelShort.
  ///
  /// In en, this message translates to:
  /// **'short'**
  String get sysShareLabelShort;

  /// No description provided for @sysShareLabelGift.
  ///
  /// In en, this message translates to:
  /// **'gift'**
  String get sysShareLabelGift;

  /// No description provided for @sysShareLabelReferral.
  ///
  /// In en, this message translates to:
  /// **'referral'**
  String get sysShareLabelReferral;

  /// No description provided for @sysInvoiceReady.
  ///
  /// In en, this message translates to:
  /// **'Invoice ready'**
  String get sysInvoiceReady;

  /// No description provided for @sysInvoiceGeneratedChooseShare.
  ///
  /// In en, this message translates to:
  /// **'Invoice {invoiceNumber} has been generated. Choose where to share it.'**
  String sysInvoiceGeneratedChooseShare(String invoiceNumber);

  /// No description provided for @sysInvoiceSendOnWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send on WhatsApp'**
  String get sysInvoiceSendOnWhatsApp;

  /// No description provided for @sysInvoiceSendByEmail.
  ///
  /// In en, this message translates to:
  /// **'Send by Email'**
  String get sysInvoiceSendByEmail;

  /// No description provided for @sysInvoiceMoreSharingOptions.
  ///
  /// In en, this message translates to:
  /// **'More sharing options'**
  String get sysInvoiceMoreSharingOptions;

  /// No description provided for @sysInvoiceSelectWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Select WhatsApp to share this invoice.'**
  String get sysInvoiceSelectWhatsApp;

  /// No description provided for @sysInvoiceSelectEmailApp.
  ///
  /// In en, this message translates to:
  /// **'Select your email app to send this invoice.'**
  String get sysInvoiceSelectEmailApp;

  /// No description provided for @sysInvoiceShareHint.
  ///
  /// In en, this message translates to:
  /// **'Share invoice'**
  String get sysInvoiceShareHint;

  /// No description provided for @sysDeepLinkMovieUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Movie details are not available or have been removed'**
  String get sysDeepLinkMovieUnavailable;

  /// No description provided for @sysDeepLinkSeriesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Series details are not available or have been removed'**
  String get sysDeepLinkSeriesUnavailable;

  /// No description provided for @sysDeepLinkContentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Content details are not available or have been removed'**
  String get sysDeepLinkContentUnavailable;

  /// No description provided for @sysGiftSignInToClaim.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to claim your gift ({code})'**
  String sysGiftSignInToClaim(String code);

  /// No description provided for @fieldPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get fieldPhoneRequired;

  /// No description provided for @fieldMobileMinDigits.
  ///
  /// In en, this message translates to:
  /// **'Mobile number cannot be less than 10 digits'**
  String get fieldMobileMinDigits;

  /// No description provided for @fieldMobileMaxDigits.
  ///
  /// In en, this message translates to:
  /// **'Mobile number cannot be greater than 10 digits'**
  String get fieldMobileMaxDigits;

  /// No description provided for @fieldEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get fieldEmailRequired;

  /// No description provided for @fieldInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get fieldInvalidEmail;

  /// No description provided for @fieldOnlyAlphabets.
  ///
  /// In en, this message translates to:
  /// **'Only alphabets are allowed'**
  String get fieldOnlyAlphabets;

  /// No description provided for @fieldOnlyDigits.
  ///
  /// In en, this message translates to:
  /// **'Only digits are allowed'**
  String get fieldOnlyDigits;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @giftClaimAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'This gift card has already been claimed.'**
  String get giftClaimAlreadyClaimed;

  /// No description provided for @giftClaimExpired.
  ///
  /// In en, this message translates to:
  /// **'This gift card has expired.'**
  String get giftClaimExpired;

  /// No description provided for @giftClaimInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid gift card code. Please check and try again.'**
  String get giftClaimInvalidCode;

  /// No description provided for @genreAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get genreAction;

  /// No description provided for @genreComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get genreComedy;

  /// No description provided for @genreThriller.
  ///
  /// In en, this message translates to:
  /// **'Thriller'**
  String get genreThriller;

  /// No description provided for @genreHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get genreHorror;

  /// No description provided for @genreRomance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get genreRomance;

  /// No description provided for @genreFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get genreFantasy;

  /// No description provided for @genreMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get genreMystery;

  /// No description provided for @genreDocumentary.
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get genreDocumentary;

  /// No description provided for @genreAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get genreAnimation;

  /// No description provided for @genreAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get genreAdventure;

  /// No description provided for @genreMusical.
  ///
  /// In en, this message translates to:
  /// **'Musical'**
  String get genreMusical;

  /// No description provided for @genreHistorical.
  ///
  /// In en, this message translates to:
  /// **'Historical'**
  String get genreHistorical;

  /// No description provided for @genreCrime.
  ///
  /// In en, this message translates to:
  /// **'Crime'**
  String get genreCrime;

  /// No description provided for @genreSciFi.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get genreSciFi;

  /// No description provided for @newsTitle.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get newsTitle;

  /// No description provided for @newsNoMessageBody.
  ///
  /// In en, this message translates to:
  /// **'No message body'**
  String get newsNoMessageBody;

  /// No description provided for @newsPayload.
  ///
  /// In en, this message translates to:
  /// **'Payload'**
  String get newsPayload;

  /// No description provided for @routeMovieNotFound.
  ///
  /// In en, this message translates to:
  /// **'Movie not found'**
  String get routeMovieNotFound;

  /// No description provided for @routeInvalidMovieLink.
  ///
  /// In en, this message translates to:
  /// **'The shared movie link is invalid or incomplete.'**
  String get routeInvalidMovieLink;

  /// No description provided for @giftedToYou.
  ///
  /// In en, this message translates to:
  /// **'Gifted To You'**
  String get giftedToYou;

  /// No description provided for @giftedToYouEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Gifts Yet'**
  String get giftedToYouEmptyTitle;

  /// No description provided for @giftedToYouEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Movies and content gifted to you will appear here.'**
  String get giftedToYouEmptyMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'as',
        'bn',
        'en',
        'gu',
        'hi',
        'kn',
        'ml',
        'mr',
        'ne',
        'or',
        'pa',
        'ta',
        'te',
        'ur'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'as':
      return AppLocalizationsAs();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'ne':
      return AppLocalizationsNe();
    case 'or':
      return AppLocalizationsOr();
    case 'pa':
      return AppLocalizationsPa();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
