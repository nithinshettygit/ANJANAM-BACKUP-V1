// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'ANJANAM';

  @override
  String get chooseLanguage => 'भाषा चुनें';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get kannada => 'कन्नड़';

  @override
  String get continueLabel => 'जारी रखें';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get manageAppPreferences => 'ऐप प्राथमिकताएँ प्रबंधित करें';

  @override
  String get account => 'खाता';

  @override
  String get addToCart => 'कार्ट में जोड़ें';

  @override
  String get buyNow => 'अभी खरीदें';

  @override
  String get goToCart => 'कार्ट पर जाएँ';

  @override
  String get outOfStock => 'स्टॉक में नहीं है';

  @override
  String get unavailable => 'उपलब्ध नहीं है';

  @override
  String get remove => 'हटाएँ';

  @override
  String get signInToAddToCart => 'कार्ट में जोड़ने के लिए साइन इन करें';

  @override
  String get signInRequiredToManageCart =>
      'कार्ट प्रबंधित करने के लिए साइन इन करना आवश्यक है।';

  @override
  String get close => 'बंद करें';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get removeFromCartQuestion => 'कार्ट से हटाएँ?';

  @override
  String get itemRemovedFromCart => 'यह आइटम आपके कार्ट से हटा दिया जाएगा।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get myCart => 'मेरा कार्ट';

  @override
  String get yourCartIsEmpty => 'आपका कार्ट खाली है';

  @override
  String get browseProducts => 'उत्पाद देखें';

  @override
  String get loadingCart => 'कार्ट लोड हो रहा है...';

  @override
  String get couldNotLoadCart => 'कार्ट लोड नहीं हो सका';

  @override
  String totalAmount(Object amount) {
    return 'कुल: $amount';
  }

  @override
  String get checkout => 'चेकआउट';

  @override
  String get addNewAddress => 'नया पता जोड़ें';

  @override
  String get saveAddressForFutureOrders =>
      'इस पते को भविष्य के ऑर्डर के लिए सेव करें';

  @override
  String get onlinePayment => 'ऑनलाइन भुगतान (Razorpay)';

  @override
  String get cashOnDelivery => 'कैश ऑन डिलीवरी';

  @override
  String get payWhenOrderArrives => 'ऑर्डर आने पर भुगतान करें';

  @override
  String get setAsDefault => 'डिफ़ॉल्ट के रूप में सेट करें';

  @override
  String get edit => 'संपादित करें';

  @override
  String get delete => 'हटाएँ';

  @override
  String get defaultAddress => 'डिफ़ॉल्ट पता';

  @override
  String get requiredDeliveryFields =>
      'कृपया आवश्यक डिलीवरी पता फ़ील्ड भरें (* से चिह्नित)।';

  @override
  String get fixHighlightedAddressFields =>
      'कृपया हाइलाइट किए गए पता फ़ील्ड ठीक करें।';

  @override
  String checkoutFailed(Object error) {
    return 'चेकआउट विफल: $error';
  }

  @override
  String orderCreatedCodNotSaved(Object error) {
    return 'ऑर्डर बन गया, लेकिन कैश ऑन डिलीवरी सेव नहीं हो सका: $error';
  }

  @override
  String get sessionExpiredLoginAgain =>
      'सेशन समाप्त हो गया, कृपया फिर से लॉगिन करें';

  @override
  String couldNotOpenPayment(Object error) {
    return 'भुगतान शुरू नहीं हो सका: $error';
  }

  @override
  String get paymentFailedTryAgain =>
      'भुगतान विफल हुआ। कृपया फिर से प्रयास करें।';

  @override
  String get paymentPendingUpdateShortly =>
      'भुगतान लंबित है, हम जल्द ही अपडेट करेंगे';

  @override
  String get importantPaymentNotice =>
      'महत्वपूर्ण: ऑर्डर की पुष्टि दिखाई देने तक बंद, रीफ़्रेश या वापस न जाएँ। ऐसा करने से भुगतान सत्यापन में समस्या हो सकती है।';

  @override
  String get placeOrder => 'ऑर्डर करें';

  @override
  String get waitingForPayment => 'भुगतान की प्रतीक्षा हो रही है…';

  @override
  String get processingOrder => 'ऑर्डर प्रोसेस हो रहा है…';

  @override
  String get openingPayment => 'भुगतान खोला जा रहा है…';

  @override
  String get confirmingPayment => 'भुगतान की पुष्टि हो रही है…';

  @override
  String get paymentSuccess => 'भुगतान सफल';

  @override
  String get paymentFailed => 'भुगतान विफल';

  @override
  String get orderPlaced => 'ऑर्डर हो गया!';

  @override
  String get paymentSuccessful => 'भुगतान सफल रहा!';

  @override
  String get removeAddressQuestion => 'पता हटाएँ?';

  @override
  String get deliveryAddress => 'डिलीवरी पता';

  @override
  String get savedAddresses => 'सेव किए गए पते';

  @override
  String get orderSummary => 'ऑर्डर सारांश';

  @override
  String get delivery => 'डिलीवरी';

  @override
  String get payment => 'भुगतान';

  @override
  String get paymentMethod => 'भुगतान का तरीका';

  @override
  String get razorpay => 'Razorpay';

  @override
  String get noItemsToCheckout => 'चेकआउट के लिए कोई आइटम नहीं है';

  @override
  String get addItemsBeforeOrder =>
      'ऑर्डर करने से पहले अपने कार्ट में आइटम जोड़ें।';

  @override
  String get preparingCheckout => 'चेकआउट तैयार हो रहा है…';

  @override
  String get save => 'सेव करें';

  @override
  String get onlyFewLeft => 'केवल कुछ बचे हैं';

  @override
  String get newestFirst => 'नवीनतम पहले';

  @override
  String get priceLowToHigh => 'कीमत: कम से अधिक';

  @override
  String get priceHighToLow => 'कीमत: अधिक से कम';

  @override
  String get sort => 'क्रमबद्ध करें';

  @override
  String get priceInr => 'कीमत (INR)';

  @override
  String get min => 'न्यूनतम';

  @override
  String get max => 'अधिकतम';

  @override
  String get filter => 'फ़िल्टर';

  @override
  String get adjustFilters => 'फ़िल्टर बदलें';

  @override
  String addedToCart(Object product) {
    return '$product कार्ट में जोड़ दिया गया';
  }

  @override
  String get addedToCartGeneric => 'कार्ट में जोड़ दिया गया';

  @override
  String get inStockOnly => 'केवल स्टॉक में उपलब्ध';

  @override
  String get hideZeroInventory => 'शून्य इन्वेंट्री वाले उत्पाद छिपाएँ';

  @override
  String get login => 'लॉगिन';

  @override
  String get signUp => 'साइन अप';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get username => 'उपयोगकर्ता नाम';

  @override
  String get confirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get passwordRequired => 'पासवर्ड आवश्यक है';

  @override
  String get usernameRequired => 'उपयोगकर्ता नाम आवश्यक है';

  @override
  String get usernameMinLength =>
      'उपयोगकर्ता नाम कम से कम 2 अक्षरों का होना चाहिए';

  @override
  String get usernameTooLong => 'उपयोगकर्ता नाम बहुत लंबा है';

  @override
  String get confirmPasswordRequired => 'पासवर्ड की पुष्टि आवश्यक है';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get loggingIn => 'लॉगिन हो रहा है...';

  @override
  String get creatingAccount => 'खाता बनाया जा रहा है...';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get continueWithGoogle => 'Google के साथ जारी रखें';

  @override
  String get connectingToGoogle => 'Google से कनेक्ट हो रहा है...';

  @override
  String get noAccountSignUp => 'खाता नहीं है? साइन अप करें';

  @override
  String get alreadyHaveAccountSignIn => 'पहले से खाता है? साइन इन करें';

  @override
  String get loginSuccessful => 'लॉगिन सफल रहा';

  @override
  String get registrationSuccessful => 'पंजीकरण सफलतापूर्वक पूरा हुआ।';

  @override
  String get checkInboxBeforeSignIn =>
      'आपका खाता बन गया है। यदि ईमेल पुष्टि आवश्यक है, तो साइन इन करने से पहले अपना इनबॉक्स देखें।';

  @override
  String get googleLoginUnavailable =>
      'Google लॉगिन अभी उपलब्ध नहीं है। कृपया रीफ़्रेश करके फिर प्रयास करें।';

  @override
  String get googleSignupUnavailable =>
      'Google साइन अप अभी उपलब्ध नहीं है। कृपया रीफ़्रेश करके फिर प्रयास करें।';

  @override
  String get googleSignInCancelled => 'Google साइन इन रद्द किया गया।';

  @override
  String get myOrders => 'मेरे ऑर्डर';

  @override
  String get ordersNav => 'ऑर्डर';

  @override
  String get refresh => 'रीफ़्रेश करें';

  @override
  String get wishlist => 'विशलिस्ट';

  @override
  String get cart => 'कार्ट';

  @override
  String get searchOrders => 'ऑर्डर आईडी, स्थिति या उत्पाद से खोजें…';

  @override
  String get noMatchingOrders => 'कोई मिलता-जुलता ऑर्डर नहीं मिला';

  @override
  String get noOrdersYet => 'अभी कोई ऑर्डर नहीं है';

  @override
  String get tryDifferentKeywords => 'अलग कीवर्ड आज़माएँ या खोज साफ़ करें।';

  @override
  String get orderAppearsAfterPlacement =>
      'ऑर्डर करने के बाद वह यहाँ दिखाई देगा।';

  @override
  String get clearSearch => 'खोज साफ़ करें';

  @override
  String get startShopping => 'खरीदारी शुरू करें';

  @override
  String get loadingOrders => 'ऑर्डर लोड हो रहे हैं...';

  @override
  String get couldNotLoadOrders => 'ऑर्डर लोड नहीं हो सके';

  @override
  String get reset => 'रीसेट करें';

  @override
  String get apply => 'लागू करें';

  @override
  String get pendingPayment => 'भुगतान लंबित';

  @override
  String get paymentFailedStatus => 'भुगतान विफल';

  @override
  String get processing => 'प्रोसेस हो रहा है';

  @override
  String get packed => 'पैक किया गया';

  @override
  String get shipped => 'भेज दिया गया';

  @override
  String get outForDelivery => 'डिलीवरी के लिए निकल गया';

  @override
  String get delivered => 'डिलीवर हो गया';

  @override
  String get cancellationPending => 'रद्द करने का अनुरोध लंबित है';

  @override
  String get cancelled => 'रद्द किया गया';

  @override
  String get cancelPending => 'रद्दीकरण लंबित';

  @override
  String get paid => 'भुगतान किया गया';

  @override
  String get pending => 'लंबित';

  @override
  String get refunded => 'रिफंड किया गया';

  @override
  String get orderItem => 'ऑर्डर आइटम';

  @override
  String orderNumber(Object id) {
    return 'ऑर्डर #$id';
  }

  @override
  String moreItems(Object count, Object label) {
    return '+$count और $label';
  }

  @override
  String orderDate(Object date) {
    return 'ऑर्डर की तारीख: $date';
  }

  @override
  String quantityAndAmount(Object amount, Object quantity) {
    return 'मात्रा: $quantity · $amount';
  }

  @override
  String get viewOrderDetails => 'ऑर्डर विवरण देखें';

  @override
  String get buyAgain => 'फिर से खरीदें';

  @override
  String get writeReview => 'समीक्षा लिखें';

  @override
  String get trackOrder => 'ऑर्डर ट्रैक करें';

  @override
  String get viewAccountDetails => 'खाते का विवरण देखें';

  @override
  String get customerDetails => 'ग्राहक विवरण';

  @override
  String get customerDetailsSection => 'ग्राहक विवरण';

  @override
  String get myOrdersSection => 'मेरे ऑर्डर';

  @override
  String get trackOrders => 'ऑर्डर ट्रैक करें';

  @override
  String get savedWishlist => 'विशलिस्ट';

  @override
  String get savedItems => 'सेव किए गए आइटम';

  @override
  String get support => 'सहायता';

  @override
  String get legalAndSupport => 'कानूनी और सहायता';

  @override
  String get accountOptions => 'खाता विकल्प';

  @override
  String get myProfile => 'मेरी प्रोफ़ाइल';

  @override
  String get editPersonalDetails => 'व्यक्तिगत विवरण संपादित करें';

  @override
  String get deliveryAddresses => 'डिलीवरी पते';

  @override
  String get manageSavedAddresses => 'सेव किए गए पते प्रबंधित करें';

  @override
  String get helpSupport => 'सहायता';

  @override
  String get faqsContact => 'अक्सर पूछे जाने वाले प्रश्न और संपर्क';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get goToSignIn => 'साइन इन पर जाएँ';

  @override
  String get accountLoadError =>
      'आपका खाता लोड नहीं हो सका। कृपया फिर से साइन इन करें।';

  @override
  String profileLoadError(Object error) {
    return 'प्रोफ़ाइल लोड नहीं हो सकी: $error';
  }

  @override
  String get loadingOrder => 'ऑर्डर लोड हो रहा है...';

  @override
  String get couldNotLoadOrder => 'ऑर्डर लोड नहीं हो सका';

  @override
  String get retryPaymentMessage =>
      'भुगतान विफल हुआ। आप फिर से भुगतान कर सकते हैं।';

  @override
  String get pendingPaymentMessage =>
      'भुगतान लंबित है। आप Razorpay से भुगतान पूरा कर सकते हैं।';

  @override
  String get created => 'बनाया गया';

  @override
  String get assigned => 'सौंपा गया';

  @override
  String get inTransit => 'रास्ते में';

  @override
  String get rtoInitiated => 'RTO शुरू किया गया';

  @override
  String get rto => 'RTO';

  @override
  String get home => 'होम';

  @override
  String get shop => 'शॉप';

  @override
  String get explore => 'एक्सप्लोर करें';

  @override
  String get popularProducts => 'लोकप्रिय उत्पाद';

  @override
  String get popular => 'लोकप्रिय';

  @override
  String get popularEmpty =>
      'जैसे-जैसे ग्राहक खरीदारी करेंगे, लोकप्रिय उत्पाद यहाँ दिखाई देंगे।';

  @override
  String get recommendedForYou => 'आपके लिए सुझाव';

  @override
  String get forYou => 'आपके लिए';

  @override
  String get recommendationsEmpty =>
      'अभी कोई सुझाव नहीं है। अधिक उत्पादों के लिए हमारा कैटलॉग देखें।';

  @override
  String get festivalSpecials => 'त्योहार विशेष';

  @override
  String get festival => 'त्योहार';

  @override
  String get festivalEmpty =>
      'त्योहार विशेष जल्द आ रहे हैं। कृपया थोड़ी देर बाद देखें।';

  @override
  String get newArrivals => 'नए उत्पाद';

  @override
  String get newLabel => 'नया';

  @override
  String get newArrivalsEmpty =>
      'अभी कोई नया उत्पाद नहीं है। हम जल्द ही नए उत्पाद जोड़ेंगे।';

  @override
  String get viewAll => 'सभी देखें >';

  @override
  String get quickPicks => 'त्वरित चयन';

  @override
  String get shopByCategory => 'श्रेणी के अनुसार खरीदारी करें';

  @override
  String get festivalPick => 'त्योहार चयन';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get privacyDataSubtitle => 'हम डेटा कैसे एकत्र और उपयोग करते हैं';

  @override
  String get termsConditions => 'नियम और शर्तें';

  @override
  String get termsSubtitle => 'ANJANAM सेवाओं का उपयोग';

  @override
  String get refundPolicy => 'रिफंड नीति';

  @override
  String get refundSubtitle => 'रिटर्न और रिफंड';

  @override
  String get supportLabel => 'सहायता';

  @override
  String get deleteAccount => 'खाता हटाएँ';

  @override
  String get deleteAccountSubtitle => 'खाता हटाने का अनुरोध कैसे करें';

  @override
  String get legalSupport => 'कानूनी और सहायता';

  @override
  String get privacy => 'गोपनीयता';

  @override
  String get terms => 'नियम';

  @override
  String get refunds => 'रिफंड';

  @override
  String get enterEmailToReset =>
      'पासवर्ड रीसेट करने के लिए अपना ईमेल दर्ज करें';

  @override
  String get resetInstructionsSent =>
      'यदि इस ईमेल का खाता मौजूद है, तो हमने रीसेट निर्देश भेजे हैं। सुरक्षा के लिए लिंक थोड़े समय बाद समाप्त हो जाते हैं।';

  @override
  String get retry => 'फिर प्रयास करें';

  @override
  String get unableToContinueGoogle => 'Google के साथ आगे नहीं बढ़ सके।';

  @override
  String get accountAlreadyExists => 'खाता पहले से मौजूद है';

  @override
  String get connectionProblem => 'कनेक्शन समस्या';

  @override
  String get pleaseTryLater => 'कृपया बाद में प्रयास करें';

  @override
  String get confirmationEmailDelayed => 'पुष्टि ईमेल में देरी हो रही है';

  @override
  String get registrationCouldNotComplete => 'पंजीकरण पूरा नहीं हो सका';

  @override
  String get signInUnsuccessful => 'साइन इन सफल नहीं हुआ';

  @override
  String get emailConfirmationRequired => 'ईमेल पुष्टि आवश्यक है';

  @override
  String get sessionEnded => 'सेशन समाप्त हो गया';

  @override
  String get pleaseWait => 'कृपया प्रतीक्षा करें';

  @override
  String get emailDelayed => 'ईमेल में देरी हो रही है';

  @override
  String get signInCouldNotComplete => 'साइन इन पूरा नहीं हो सका';

  @override
  String get passwordRequirements => 'पासवर्ड आवश्यकताएँ';

  @override
  String get couldNotUpdatePassword => 'पासवर्ड अपडेट नहीं हो सका';

  @override
  String get unableToSignOut => 'साइन आउट नहीं हो सका';

  @override
  String get closeDialog => 'बंद करें';
}
