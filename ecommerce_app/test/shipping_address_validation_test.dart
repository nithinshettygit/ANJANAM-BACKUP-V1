import 'package:flutter_test/flutter_test.dart';
import 'package:ecommerce_app/features/checkout/domain/shipping_details.dart';

void main() {
  group('Shipping Address English/Latin Validation', () {
    test('Valid English addresses pass validation', () {
      final validAddresses = [
        'Nithin S',
        'Bendre House, 2nd Cross, Badiyadka',
        'Bendre House #12, Main Road',
        'Perne, Badiyadka - 574333',
        'Nithin S & Family, House No. 12/4',
      ];

      for (final addr in validAddresses) {
        expect(
          ShippingDetails.isEnglishAddressText(addr),
          isTrue,
          reason: 'Expected "$addr" to be valid English address text.',
        );
        expect(
          ShippingDetails.validateEnglishAddressText(addr),
          isNull,
          reason: 'Expected "$addr" validator result to be null (valid).',
        );
      }
    });

    test('Invalid Indic script addresses fail validation', () {
      final invalidAddresses = [
        'ಬೇಂದ್ರೆ ಹೌಸ್, ಬಂಟ್ವಾಳ',
        'ഹൗസ്, കാസർഗോഡ്',
        'बेंद्रे हाउस, कर्नाटक',
        'முக்கிய சாலை, கர்நாடகா',
        'ప్రధాన రహదారి',
      ];

      for (final addr in invalidAddresses) {
        expect(
          ShippingDetails.isEnglishAddressText(addr),
          isFalse,
          reason: 'Expected "$addr" to be invalid non-English address text.',
        );
        expect(
          ShippingDetails.validateEnglishAddressText(addr),
          equals(ShippingDetails.englishOnlyErrorMessage),
          reason: 'Expected "$addr" to return standard error message.',
        );
      }
    });

    test('Mixed language addresses fail validation', () {
      final mixedAddresses = [
        'Nithin S, ಬೇಂದ್ರೆ ಹೌಸ್',
        'Nithin, ഹൗസ്',
        'Bendre House, बंटवाल',
      ];

      for (final addr in mixedAddresses) {
        expect(
          ShippingDetails.isEnglishAddressText(addr),
          isFalse,
          reason: 'Expected mixed address "$addr" to be invalid.',
        );
        expect(
          ShippingDetails.validateEnglishAddressText(addr),
          equals(ShippingDetails.englishOnlyErrorMessage),
        );
      }
    });

    test('Pasted invalid input fails validation immediately', () {
      final pastedInputs = [
        'ಬೇಂದ್ರೆ ಹೌಸ್',
        'ഹൗസ്, കാസർഗോഡ്',
        'बेंद्रे हाउस',
      ];

      for (final pasted in pastedInputs) {
        expect(ShippingDetails.isEnglishAddressText(pasted), isFalse);
        expect(
          ShippingDetails.validateEnglishAddressText(pasted),
          equals(ShippingDetails.englishOnlyErrorMessage),
        );
      }
    });

    test('Correction test: invalid text replaced with English becomes valid', () {
      var input = 'ಬೇಂದ್ರെ ഹൗസ്';
      expect(ShippingDetails.isEnglishAddressText(input), isFalse);
      expect(
        ShippingDetails.validateEnglishAddressText(input),
        equals(ShippingDetails.englishOnlyErrorMessage),
      );

      input = 'Bendre House';
      expect(ShippingDetails.isEnglishAddressText(input), isTrue);
      expect(ShippingDetails.validateEnglishAddressText(input), isNull);
    });

    test('ShippingDetails.validationError blocks invalid addresses', () {
      final invalidDetails = ShippingDetails(
        fullName: 'Nithin S',
        phone: '9876543210',
        addressLine: 'ಬೇಂದ್ರೆ ಹೌಸ್, 2nd Cross',
        city: 'Badiyadka',
        postalCode: '574333',
      );

      expect(
        invalidDetails.validationError(),
        equals(ShippingDetails.englishOnlyErrorMessage),
      );

      final validDetails = ShippingDetails(
        fullName: 'Nithin S',
        phone: '9876543210',
        addressLine: 'Bendre House, 2nd Cross',
        city: 'Badiyadka',
        postalCode: '574333',
      );

      expect(validDetails.validationError(), isNull);
    });
  });
}
