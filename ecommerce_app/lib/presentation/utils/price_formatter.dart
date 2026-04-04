import 'package:ecommerce_app/core/formatting/inr_format.dart';

String formatRupee(num amount) => formatInrAmount(amount.toDouble());

/// Compact INR for dense UI (cards); keeps paise when non-zero.
String formatRupeeCompact(num amount) => formatInrCompact(amount.toDouble());
