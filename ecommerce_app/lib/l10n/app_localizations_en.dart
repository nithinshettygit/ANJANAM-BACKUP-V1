// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ANJANAM';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get kannada => 'Kannada';

  @override
  String get continueLabel => 'Continue';

  @override
  String get settings => 'Settings';

  @override
  String get manageAppPreferences => 'Manage app preferences';

  @override
  String get account => 'Account';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get buyNow => 'Buy Now';

  @override
  String get goToCart => 'Go to Cart';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get remove => 'Remove';

  @override
  String get signInToAddToCart => 'Sign in to add to cart';

  @override
  String get signInRequiredToManageCart => 'Sign in required to manage cart.';

  @override
  String get close => 'Close';

  @override
  String get signIn => 'Sign in';

  @override
  String get removeFromCartQuestion => 'Remove from cart?';

  @override
  String get itemRemovedFromCart => 'This item will be removed from your cart.';

  @override
  String get cancel => 'Cancel';

  @override
  String get myCart => 'My Cart';

  @override
  String get yourCartIsEmpty => 'Your cart is empty';

  @override
  String get browseProducts => 'Browse products';

  @override
  String get loadingCart => 'Loading cart...';

  @override
  String get couldNotLoadCart => 'Could not load cart';

  @override
  String totalAmount(Object amount) {
    return 'Total: $amount';
  }

  @override
  String get checkout => 'Checkout';

  @override
  String get addNewAddress => 'Add new address';

  @override
  String get saveAddressForFutureOrders =>
      'Save this address for future orders';

  @override
  String get onlinePayment => 'Online payment (Razorpay)';

  @override
  String get cashOnDelivery => 'Cash on Delivery';

  @override
  String get payWhenOrderArrives => 'Pay when your order arrives';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get defaultAddress => 'Default address';

  @override
  String get requiredDeliveryFields =>
      'Please complete the required delivery address fields (marked *).';

  @override
  String get fixHighlightedAddressFields =>
      'Please fix the highlighted address fields.';

  @override
  String checkoutFailed(Object error) {
    return 'Checkout failed: $error';
  }

  @override
  String orderCreatedCodNotSaved(Object error) {
    return 'Order was created but COD could not be saved: $error';
  }

  @override
  String get sessionExpiredLoginAgain => 'Session expired, please login again';

  @override
  String couldNotOpenPayment(Object error) {
    return 'Could not open payment: $error';
  }

  @override
  String get paymentFailedTryAgain => 'Payment failed. Please try again.';

  @override
  String get paymentPendingUpdateShortly =>
      'Payment pending, we will update shortly';

  @override
  String get importantPaymentNotice =>
      'Important: Do not close, refresh, or go back until your order confirmation appears. Leaving this screen early can cause payment verification issues.';

  @override
  String get placeOrder => 'Place order';

  @override
  String get waitingForPayment => 'Waiting for payment…';

  @override
  String get processingOrder => 'Processing order…';

  @override
  String get openingPayment => 'Opening payment…';

  @override
  String get confirmingPayment => 'Confirming payment…';

  @override
  String get paymentSuccess => 'Payment success';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get orderPlaced => 'Order placed!';

  @override
  String get paymentSuccessful => 'Payment successful!';

  @override
  String get removeAddressQuestion => 'Remove address?';

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get savedAddresses => 'Saved addresses';

  @override
  String get orderSummary => 'Order summary';

  @override
  String get delivery => 'Delivery';

  @override
  String get payment => 'Payment';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get razorpay => 'Razorpay';

  @override
  String get noItemsToCheckout => 'No items to checkout';

  @override
  String get addItemsBeforeOrder =>
      'Add items to your cart before placing an order.';

  @override
  String get preparingCheckout => 'Preparing checkout…';

  @override
  String get save => 'Save';

  @override
  String get onlyFewLeft => 'Only a few left';

  @override
  String get newestFirst => 'Newest first';

  @override
  String get priceLowToHigh => 'Price: low to high';

  @override
  String get priceHighToLow => 'Price: high to low';

  @override
  String get sort => 'Sort';

  @override
  String get priceInr => 'Price (INR)';

  @override
  String get min => 'Min';

  @override
  String get max => 'Max';

  @override
  String get filter => 'Filter';

  @override
  String get adjustFilters => 'Adjust filters';

  @override
  String addedToCart(Object product) {
    return '$product added to cart';
  }

  @override
  String get addedToCartGeneric => 'Added to cart';

  @override
  String get inStockOnly => 'In stock only';

  @override
  String get hideZeroInventory => 'Hide products with zero inventory';

  @override
  String get login => 'Login';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get username => 'Username';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get usernameMinLength => 'Username must be at least 2 characters';

  @override
  String get usernameTooLong => 'Username is too long';

  @override
  String get confirmPasswordRequired => 'Confirm password is required';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get loggingIn => 'Logging in...';

  @override
  String get creatingAccount => 'Creating account...';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get connectingToGoogle => 'Connecting to Google...';

  @override
  String get noAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get alreadyHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get loginSuccessful => 'Login successful';

  @override
  String get registrationSuccessful => 'Registration completed successfully.';

  @override
  String get checkInboxBeforeSignIn =>
      'Your account has been created. If email confirmation is required, please check your inbox before signing in.';

  @override
  String get googleLoginUnavailable =>
      'Google login is unavailable right now. Please refresh and try again.';

  @override
  String get googleSignupUnavailable =>
      'Google sign-up is unavailable right now. Please refresh and try again.';

  @override
  String get googleSignInCancelled => 'Google sign-in cancelled.';

  @override
  String get myOrders => 'My Orders';

  @override
  String get ordersNav => 'Orders';

  @override
  String get refresh => 'Refresh';

  @override
  String get wishlist => 'Wishlist';

  @override
  String get cart => 'Cart';

  @override
  String get searchOrders => 'Search by order id, status, or product…';

  @override
  String get noMatchingOrders => 'No matching orders';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get tryDifferentKeywords =>
      'Try different keywords or clear the search.';

  @override
  String get orderAppearsAfterPlacement =>
      'When you place an order, it will show up here.';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get startShopping => 'Start shopping';

  @override
  String get loadingOrders => 'Loading orders...';

  @override
  String get couldNotLoadOrders => 'Could not load orders';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get pendingPayment => 'Pending payment';

  @override
  String get paymentFailedStatus => 'Payment failed';

  @override
  String get processing => 'Processing';

  @override
  String get packed => 'Packed';

  @override
  String get shipped => 'Shipped';

  @override
  String get outForDelivery => 'Out for delivery';

  @override
  String get delivered => 'Delivered';

  @override
  String get cancellationPending => 'Cancellation pending approval';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get cancelPending => 'Cancel pending';

  @override
  String get paid => 'Paid';

  @override
  String get pending => 'Pending';

  @override
  String get refunded => 'Refunded';

  @override
  String get orderItem => 'Order item';

  @override
  String orderNumber(Object id) {
    return 'Order #$id';
  }

  @override
  String moreItems(Object count, Object label) {
    return '+$count more $label';
  }

  @override
  String orderDate(Object date) {
    return 'Order date: $date';
  }

  @override
  String quantityAndAmount(Object amount, Object quantity) {
    return 'Qty: $quantity · $amount';
  }

  @override
  String get viewOrderDetails => 'View order details';

  @override
  String get buyAgain => 'Buy again';

  @override
  String get writeReview => 'Write review';

  @override
  String get trackOrder => 'Track order';

  @override
  String get viewAccountDetails => 'View account details';

  @override
  String get customerDetails => 'Customer Details';

  @override
  String get customerDetailsSection => 'Customer details';

  @override
  String get myOrdersSection => 'My Orders';

  @override
  String get trackOrders => 'Track orders';

  @override
  String get savedWishlist => 'Wishlist';

  @override
  String get savedItems => 'Saved items';

  @override
  String get support => 'Support';

  @override
  String get legalAndSupport => 'Legal & Support';

  @override
  String get accountOptions => 'Account options';

  @override
  String get myProfile => 'My Profile';

  @override
  String get editPersonalDetails => 'Edit personal details';

  @override
  String get deliveryAddresses => 'Delivery Addresses';

  @override
  String get manageSavedAddresses => 'Manage saved addresses';

  @override
  String get helpSupport => 'Help / Support';

  @override
  String get faqsContact => 'FAQs and contact';

  @override
  String get logout => 'Logout';

  @override
  String get goToSignIn => 'Go to sign in';

  @override
  String get accountLoadError =>
      'We could not load your account. Please try signing in again.';

  @override
  String profileLoadError(Object error) {
    return 'Failed to load profile: $error';
  }

  @override
  String get loadingOrder => 'Loading order...';

  @override
  String get couldNotLoadOrder => 'Could not load order';

  @override
  String get retryPaymentMessage => 'Payment failed. You can retry payment.';

  @override
  String get pendingPaymentMessage =>
      'Payment is pending. You can complete payment with Razorpay.';

  @override
  String get created => 'Created';

  @override
  String get assigned => 'Assigned';

  @override
  String get inTransit => 'In transit';

  @override
  String get rtoInitiated => 'RTO initiated';

  @override
  String get rto => 'RTO';

  @override
  String get home => 'Home';

  @override
  String get shop => 'Shop';

  @override
  String get explore => 'Explore';

  @override
  String get popularProducts => 'Popular Products';

  @override
  String get popular => 'Popular';

  @override
  String get popularEmpty =>
      'Popular products will appear here as customers shop more.';

  @override
  String get recommendedForYou => 'Recommended For You';

  @override
  String get forYou => 'For you';

  @override
  String get recommendationsEmpty =>
      'No recommendations right now. Explore our catalog for more products.';

  @override
  String get festivalSpecials => 'Festival Specials';

  @override
  String get festival => 'Festival';

  @override
  String get festivalEmpty =>
      'Festival specials are coming soon. Please check back shortly.';

  @override
  String get newArrivals => 'New Arrivals';

  @override
  String get newLabel => 'New';

  @override
  String get newArrivalsEmpty =>
      'No new arrivals yet. We are adding fresh products soon.';

  @override
  String get viewAll => 'View all >';

  @override
  String get quickPicks => 'Quick picks';

  @override
  String get shopByCategory => 'Shop by category';

  @override
  String get festivalPick => 'Festival pick';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyDataSubtitle => 'How we collect and use data';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get termsSubtitle => 'Using ANJANAM services';

  @override
  String get refundPolicy => 'Refund Policy';

  @override
  String get refundSubtitle => 'Returns and refunds';

  @override
  String get supportLabel => 'Support';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountSubtitle => 'How to request account deletion';

  @override
  String get legalSupport => 'Legal & Support';

  @override
  String get privacy => 'Privacy';

  @override
  String get terms => 'Terms';

  @override
  String get refunds => 'Refunds';

  @override
  String get enterEmailToReset => 'Enter your email to reset password';

  @override
  String get resetInstructionsSent =>
      'If an account exists for this email, we sent reset instructions. Links expire after a short time for security.';

  @override
  String get retry => 'Retry';

  @override
  String get unableToContinueGoogle => 'Unable to continue with Google.';

  @override
  String get accountAlreadyExists => 'Account already exists';

  @override
  String get connectionProblem => 'Connection problem';

  @override
  String get pleaseTryLater => 'Please try later';

  @override
  String get confirmationEmailDelayed => 'Confirmation email delayed';

  @override
  String get registrationCouldNotComplete =>
      'Registration could not be completed';

  @override
  String get signInUnsuccessful => 'Sign-in unsuccessful';

  @override
  String get emailConfirmationRequired => 'Email confirmation required';

  @override
  String get sessionEnded => 'Session ended';

  @override
  String get pleaseWait => 'Please wait';

  @override
  String get emailDelayed => 'Email delayed';

  @override
  String get signInCouldNotComplete => 'Sign-in could not be completed';

  @override
  String get passwordRequirements => 'Password requirements';

  @override
  String get couldNotUpdatePassword => 'Could not update password';

  @override
  String get unableToSignOut => 'Unable to sign out';

  @override
  String get closeDialog => 'Close';
}
