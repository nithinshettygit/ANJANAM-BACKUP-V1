import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('hi'),
    Locale('kn')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ANJANAM'**
  String get appTitle;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @kannada.
  ///
  /// In en, this message translates to:
  /// **'Kannada'**
  String get kannada;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @manageAppPreferences.
  ///
  /// In en, this message translates to:
  /// **'Manage app preferences'**
  String get manageAppPreferences;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get buyNow;

  /// No description provided for @goToCart.
  ///
  /// In en, this message translates to:
  /// **'Go to Cart'**
  String get goToCart;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @signInToAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add to cart'**
  String get signInToAddToCart;

  /// No description provided for @signInRequiredToManageCart.
  ///
  /// In en, this message translates to:
  /// **'Sign in required to manage cart.'**
  String get signInRequiredToManageCart;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @removeFromCartQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove from cart?'**
  String get removeFromCartQuestion;

  /// No description provided for @itemRemovedFromCart.
  ///
  /// In en, this message translates to:
  /// **'This item will be removed from your cart.'**
  String get itemRemovedFromCart;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @myCart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get myCart;

  /// No description provided for @yourCartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get yourCartIsEmpty;

  /// No description provided for @browseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse products'**
  String get browseProducts;

  /// No description provided for @loadingCart.
  ///
  /// In en, this message translates to:
  /// **'Loading cart...'**
  String get loadingCart;

  /// No description provided for @couldNotLoadCart.
  ///
  /// In en, this message translates to:
  /// **'Could not load cart'**
  String get couldNotLoadCart;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String totalAmount(Object amount);

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add new address'**
  String get addNewAddress;

  /// No description provided for @saveAddressForFutureOrders.
  ///
  /// In en, this message translates to:
  /// **'Save this address for future orders'**
  String get saveAddressForFutureOrders;

  /// No description provided for @onlinePayment.
  ///
  /// In en, this message translates to:
  /// **'Online payment (Razorpay)'**
  String get onlinePayment;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cashOnDelivery;

  /// No description provided for @payWhenOrderArrives.
  ///
  /// In en, this message translates to:
  /// **'Pay when your order arrives'**
  String get payWhenOrderArrives;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @defaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Default address'**
  String get defaultAddress;

  /// No description provided for @requiredDeliveryFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete the required delivery address fields (marked *).'**
  String get requiredDeliveryFields;

  /// No description provided for @fixHighlightedAddressFields.
  ///
  /// In en, this message translates to:
  /// **'Please fix the highlighted address fields.'**
  String get fixHighlightedAddressFields;

  /// No description provided for @checkoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed: {error}'**
  String checkoutFailed(Object error);

  /// No description provided for @orderCreatedCodNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Order was created but COD could not be saved: {error}'**
  String orderCreatedCodNotSaved(Object error);

  /// No description provided for @sessionExpiredLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please login again'**
  String get sessionExpiredLoginAgain;

  /// No description provided for @couldNotOpenPayment.
  ///
  /// In en, this message translates to:
  /// **'Could not open payment: {error}'**
  String couldNotOpenPayment(Object error);

  /// No description provided for @paymentFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentFailedTryAgain;

  /// No description provided for @paymentPendingUpdateShortly.
  ///
  /// In en, this message translates to:
  /// **'Payment pending, we will update shortly'**
  String get paymentPendingUpdateShortly;

  /// No description provided for @importantPaymentNotice.
  ///
  /// In en, this message translates to:
  /// **'Important: Do not close, refresh, or go back until your order confirmation appears. Leaving this screen early can cause payment verification issues.'**
  String get importantPaymentNotice;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @waitingForPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment…'**
  String get waitingForPayment;

  /// No description provided for @processingOrder.
  ///
  /// In en, this message translates to:
  /// **'Processing order…'**
  String get processingOrder;

  /// No description provided for @openingPayment.
  ///
  /// In en, this message translates to:
  /// **'Opening payment…'**
  String get openingPayment;

  /// No description provided for @confirmingPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirming payment…'**
  String get confirmingPayment;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment success'**
  String get paymentSuccess;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get orderPlaced;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get paymentSuccessful;

  /// No description provided for @removeAddressQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove address?'**
  String get removeAddressQuestion;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get savedAddresses;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get orderSummary;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @razorpay.
  ///
  /// In en, this message translates to:
  /// **'Razorpay'**
  String get razorpay;

  /// No description provided for @noItemsToCheckout.
  ///
  /// In en, this message translates to:
  /// **'No items to checkout'**
  String get noItemsToCheckout;

  /// No description provided for @addItemsBeforeOrder.
  ///
  /// In en, this message translates to:
  /// **'Add items to your cart before placing an order.'**
  String get addItemsBeforeOrder;

  /// No description provided for @preparingCheckout.
  ///
  /// In en, this message translates to:
  /// **'Preparing checkout…'**
  String get preparingCheckout;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @onlyFewLeft.
  ///
  /// In en, this message translates to:
  /// **'Only a few left'**
  String get onlyFewLeft;

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get newestFirst;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get priceLowToHigh;

  /// No description provided for @priceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get priceHighToLow;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @priceInr.
  ///
  /// In en, this message translates to:
  /// **'Price (INR)'**
  String get priceInr;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get min;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @adjustFilters.
  ///
  /// In en, this message translates to:
  /// **'Adjust filters'**
  String get adjustFilters;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{product} added to cart'**
  String addedToCart(Object product);

  /// No description provided for @addedToCartGeneric.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get addedToCartGeneric;

  /// No description provided for @inStockOnly.
  ///
  /// In en, this message translates to:
  /// **'In stock only'**
  String get inStockOnly;

  /// No description provided for @hideZeroInventory.
  ///
  /// In en, this message translates to:
  /// **'Hide products with zero inventory'**
  String get hideZeroInventory;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @usernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 2 characters'**
  String get usernameMinLength;

  /// No description provided for @usernameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Username is too long'**
  String get usernameTooLong;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm password is required'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @loggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get loggingIn;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @connectingToGoogle.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google...'**
  String get connectingToGoogle;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccountSignUp;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @loginSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccessful;

  /// No description provided for @registrationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration completed successfully.'**
  String get registrationSuccessful;

  /// No description provided for @checkInboxBeforeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created. If email confirmation is required, please check your inbox before signing in.'**
  String get checkInboxBeforeSignIn;

  /// No description provided for @googleLoginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google login is unavailable right now. Please refresh and try again.'**
  String get googleLoginUnavailable;

  /// No description provided for @googleSignupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-up is unavailable right now. Please refresh and try again.'**
  String get googleSignupUnavailable;

  /// No description provided for @googleSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in cancelled.'**
  String get googleSignInCancelled;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Search by order id, status, or product…'**
  String get searchOrders;

  /// No description provided for @noMatchingOrders.
  ///
  /// In en, this message translates to:
  /// **'No matching orders'**
  String get noMatchingOrders;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @tryDifferentKeywords.
  ///
  /// In en, this message translates to:
  /// **'Try different keywords or clear the search.'**
  String get tryDifferentKeywords;

  /// No description provided for @orderAppearsAfterPlacement.
  ///
  /// In en, this message translates to:
  /// **'When you place an order, it will show up here.'**
  String get orderAppearsAfterPlacement;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get startShopping;

  /// No description provided for @loadingOrders.
  ///
  /// In en, this message translates to:
  /// **'Loading orders...'**
  String get loadingOrders;

  /// No description provided for @couldNotLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Could not load orders'**
  String get couldNotLoadOrders;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @pendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Pending payment'**
  String get pendingPayment;

  /// No description provided for @paymentFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailedStatus;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @packed.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get packed;

  /// No description provided for @shipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get shipped;

  /// No description provided for @outForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get outForDelivery;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancellationPending.
  ///
  /// In en, this message translates to:
  /// **'Cancellation pending approval'**
  String get cancellationPending;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @cancelPending.
  ///
  /// In en, this message translates to:
  /// **'Cancel pending'**
  String get cancelPending;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

  /// No description provided for @orderItem.
  ///
  /// In en, this message translates to:
  /// **'Order item'**
  String get orderItem;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(Object id);

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more {label}'**
  String moreItems(Object count, Object label);

  /// No description provided for @orderDate.
  ///
  /// In en, this message translates to:
  /// **'Order date: {date}'**
  String orderDate(Object date);

  /// No description provided for @quantityAndAmount.
  ///
  /// In en, this message translates to:
  /// **'Qty: {quantity} · {amount}'**
  String quantityAndAmount(Object amount, Object quantity);

  /// No description provided for @viewOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'View order details'**
  String get viewOrderDetails;

  /// No description provided for @buyAgain.
  ///
  /// In en, this message translates to:
  /// **'Buy again'**
  String get buyAgain;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write review'**
  String get writeReview;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get trackOrder;

  /// No description provided for @viewAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'View account details'**
  String get viewAccountDetails;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetails;

  /// No description provided for @customerDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Customer details'**
  String get customerDetailsSection;

  /// No description provided for @myOrdersSection.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrdersSection;

  /// No description provided for @trackOrders.
  ///
  /// In en, this message translates to:
  /// **'Track orders'**
  String get trackOrders;

  /// No description provided for @savedWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get savedWishlist;

  /// No description provided for @savedItems.
  ///
  /// In en, this message translates to:
  /// **'Saved items'**
  String get savedItems;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @legalAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Legal & Support'**
  String get legalAndSupport;

  /// No description provided for @accountOptions.
  ///
  /// In en, this message translates to:
  /// **'Account options'**
  String get accountOptions;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @editPersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit personal details'**
  String get editPersonalDetails;

  /// No description provided for @deliveryAddresses.
  ///
  /// In en, this message translates to:
  /// **'Delivery Addresses'**
  String get deliveryAddresses;

  /// No description provided for @manageSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Manage saved addresses'**
  String get manageSavedAddresses;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help / Support'**
  String get helpSupport;

  /// No description provided for @faqsContact.
  ///
  /// In en, this message translates to:
  /// **'FAQs and contact'**
  String get faqsContact;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @goToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get goToSignIn;

  /// No description provided for @accountLoadError.
  ///
  /// In en, this message translates to:
  /// **'We could not load your account. Please try signing in again.'**
  String get accountLoadError;

  /// No description provided for @profileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile: {error}'**
  String profileLoadError(Object error);

  /// No description provided for @loadingOrder.
  ///
  /// In en, this message translates to:
  /// **'Loading order...'**
  String get loadingOrder;

  /// No description provided for @couldNotLoadOrder.
  ///
  /// In en, this message translates to:
  /// **'Could not load order'**
  String get couldNotLoadOrder;

  /// No description provided for @retryPaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. You can retry payment.'**
  String get retryPaymentMessage;

  /// No description provided for @pendingPaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment is pending. You can complete payment with Razorpay.'**
  String get pendingPaymentMessage;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get inTransit;

  /// No description provided for @rtoInitiated.
  ///
  /// In en, this message translates to:
  /// **'RTO initiated'**
  String get rtoInitiated;

  /// No description provided for @rto.
  ///
  /// In en, this message translates to:
  /// **'RTO'**
  String get rto;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @popularProducts.
  ///
  /// In en, this message translates to:
  /// **'Popular Products'**
  String get popularProducts;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @popularEmpty.
  ///
  /// In en, this message translates to:
  /// **'Popular products will appear here as customers shop more.'**
  String get popularEmpty;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended For You'**
  String get recommendedForYou;

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @recommendationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recommendations right now. Explore our catalog for more products.'**
  String get recommendationsEmpty;

  /// No description provided for @festivalSpecials.
  ///
  /// In en, this message translates to:
  /// **'Festival Specials'**
  String get festivalSpecials;

  /// No description provided for @festival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get festival;

  /// No description provided for @festivalEmpty.
  ///
  /// In en, this message translates to:
  /// **'Festival specials are coming soon. Please check back shortly.'**
  String get festivalEmpty;

  /// No description provided for @newArrivals.
  ///
  /// In en, this message translates to:
  /// **'New Arrivals'**
  String get newArrivals;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @newArrivalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No new arrivals yet. We are adding fresh products soon.'**
  String get newArrivalsEmpty;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all >'**
  String get viewAll;

  /// No description provided for @quickPicks.
  ///
  /// In en, this message translates to:
  /// **'Quick picks'**
  String get quickPicks;

  /// No description provided for @shopByCategory.
  ///
  /// In en, this message translates to:
  /// **'Shop by category'**
  String get shopByCategory;

  /// No description provided for @festivalPick.
  ///
  /// In en, this message translates to:
  /// **'Festival pick'**
  String get festivalPick;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we collect and use data'**
  String get privacyDataSubtitle;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @termsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Using ANJANAM services'**
  String get termsSubtitle;

  /// No description provided for @refundPolicy.
  ///
  /// In en, this message translates to:
  /// **'Refund Policy'**
  String get refundPolicy;

  /// No description provided for @refundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Returns and refunds'**
  String get refundSubtitle;

  /// No description provided for @supportLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportLabel;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How to request account deletion'**
  String get deleteAccountSubtitle;

  /// No description provided for @legalSupport.
  ///
  /// In en, this message translates to:
  /// **'Legal & Support'**
  String get legalSupport;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @refunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refunds;

  /// No description provided for @enterEmailToReset.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset password'**
  String get enterEmailToReset;

  /// No description provided for @resetInstructionsSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, we sent reset instructions. Links expire after a short time for security.'**
  String get resetInstructionsSent;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @unableToContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue with Google.'**
  String get unableToContinueGoogle;

  /// No description provided for @accountAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Account already exists'**
  String get accountAlreadyExists;

  /// No description provided for @connectionProblem.
  ///
  /// In en, this message translates to:
  /// **'Connection problem'**
  String get connectionProblem;

  /// No description provided for @pleaseTryLater.
  ///
  /// In en, this message translates to:
  /// **'Please try later'**
  String get pleaseTryLater;

  /// No description provided for @confirmationEmailDelayed.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email delayed'**
  String get confirmationEmailDelayed;

  /// No description provided for @registrationCouldNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Registration could not be completed'**
  String get registrationCouldNotComplete;

  /// No description provided for @signInUnsuccessful.
  ///
  /// In en, this message translates to:
  /// **'Sign-in unsuccessful'**
  String get signInUnsuccessful;

  /// No description provided for @emailConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Email confirmation required'**
  String get emailConfirmationRequired;

  /// No description provided for @sessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get sessionEnded;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @emailDelayed.
  ///
  /// In en, this message translates to:
  /// **'Email delayed'**
  String get emailDelayed;

  /// No description provided for @signInCouldNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Sign-in could not be completed'**
  String get signInCouldNotComplete;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Password requirements'**
  String get passwordRequirements;

  /// No description provided for @couldNotUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Could not update password'**
  String get couldNotUpdatePassword;

  /// No description provided for @unableToSignOut.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign out'**
  String get unableToSignOut;

  /// No description provided for @closeDialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeDialog;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'kn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
