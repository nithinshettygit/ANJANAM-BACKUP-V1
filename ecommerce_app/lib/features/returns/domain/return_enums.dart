/// DB value: `returns.return_reason`
enum ReturnReason {
  damagedItem('damaged_item', 'Damaged item'),
  wrongProduct('wrong_product', 'Wrong product received'),
  sizeIssue('size_issue', 'Size issue'),
  notSatisfied('not_satisfied', 'Not satisfied with product');

  final String dbValue;
  final String displayLabel;

  const ReturnReason(this.dbValue, this.displayLabel);

  static ReturnReason? tryParse(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    for (final e in ReturnReason.values) {
      if (e.dbValue == v) return e;
    }
    return null;
  }
}

/// DB value: `returns.return_type`
enum ReturnType {
  returnItem('return', 'Return'),
  replacement('replacement', 'Replacement');

  final String dbValue;
  final String displayLabel;

  const ReturnType(this.dbValue, this.displayLabel);

  static ReturnType? tryParse(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    for (final e in ReturnType.values) {
      if (e.dbValue == v) return e;
    }
    return null;
  }
}

/// DB value: `returns.return_status`
enum ReturnWorkflowStatus {
  none('none', 'No return'),
  requested('requested', 'Requested'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  pickedUp('picked_up', 'Picked up'),
  returned('returned', 'Returned'),
  refundCompleted('refund_completed', 'Refund completed');

  final String dbValue;
  final String displayLabel;

  const ReturnWorkflowStatus(this.dbValue, this.displayLabel);

  static ReturnWorkflowStatus? tryParse(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    for (final e in ReturnWorkflowStatus.values) {
      if (e.dbValue == v) return e;
    }
    return null;
  }
}

/// DB value: `refunds.refund_method`
enum RefundMethod {
  originalPayment('original_payment', 'Original payment method'),
  walletCredit('wallet_credit', 'Wallet credit'),
  bankTransfer('bank_transfer', 'Bank transfer');

  final String dbValue;
  final String displayLabel;

  const RefundMethod(this.dbValue, this.displayLabel);

  static RefundMethod? tryParse(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    for (final e in RefundMethod.values) {
      if (e.dbValue == v) return e;
    }
    return null;
  }
}

/// DB value: `refunds.refund_status`
enum RefundWorkflowStatus {
  refundInitiated('refund_initiated', 'Refund initiated'),
  refundProcessed('refund_processed', 'Refund processed'),
  refundCompleted('refund_completed', 'Refund completed');

  final String dbValue;
  final String displayLabel;

  const RefundWorkflowStatus(this.dbValue, this.displayLabel);

  static RefundWorkflowStatus? tryParse(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    for (final e in RefundWorkflowStatus.values) {
      if (e.dbValue == v) return e;
    }
    return null;
  }
}
