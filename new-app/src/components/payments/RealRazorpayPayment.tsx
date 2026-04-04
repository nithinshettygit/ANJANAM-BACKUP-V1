import React, { useEffect, useState, useRef } from 'react';
import { View, Text, ActivityIndicator, StyleSheet, Modal } from 'react-native';
import { WebView } from 'react-native-webview';
import { useTheme } from 'react-native-paper';
import { RazorpayOptions } from '@/types';

interface RealRazorpayPaymentProps {
  options: RazorpayOptions | null;
  onSuccess: (payload: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    razorpaySignature: string;
  }) => void;
  onCancel: () => void;
  onError: (message: string) => void;
}

const RealRazorpayPayment: React.FC<RealRazorpayPaymentProps> = ({
  options,
  onSuccess,
  onCancel,
  onError,
}) => {
  const theme = useTheme();
  const [isLoading, setIsLoading] = useState(false);
  const [showWebView, setShowWebView] = useState(false);
  const webViewRef = useRef<WebView>(null);

  useEffect(() => {
    if (options) {
      openRazorpayCheckout();
    }
  }, [options]);

  const openRazorpayCheckout = () => {
    if (!options) return;
    setIsLoading(true);
    setShowWebView(true);
  };

  const generateRazorpayHTML = (razorpayOptions: RazorpayOptions) => {
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Razorpay Payment</title>
        <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
        <style>
          body {
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
          }
          .payment-container {
            max-width: 400px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          }
          .payment-header {
            text-align: center;
            margin-bottom: 20px;
            color: #333;
          }
          .payment-amount {
            font-size: 24px;
            font-weight: bold;
            color: #333;
            text-align: center;
            margin: 20px 0;
          }
          .payment-methods {
            margin: 20px 0;
          }
          .payment-method {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            margin-bottom: 10px;
            overflow: hidden;
          }
          .payment-method-header {
            padding: 15px;
            background: #e9ecef;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-weight: 500;
          }
          .payment-method-content {
            padding: 15px;
            display: none;
          }
          .payment-method.active .payment-method-content {
            display: block;
          }
          .input-group {
            margin-bottom: 15px;
          }
          .input-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
            color: #495057;
          }
          .input-group input, .input-group select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ced4da;
            border-radius: 4px;
            font-size: 16px;
            box-sizing: border-box;
          }
          .input-row {
            display: flex;
            gap: 10px;
          }
          .input-row .input-group {
            flex: 1;
          }
          .payment-button {
            width: 100%;
            padding: 15px;
            background-color: #B8860B;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            margin: 10px 0;
          }
          .payment-button:hover {
            opacity: 0.9;
          }
          .payment-button:disabled {
            background-color: #6c757d;
            cursor: not-allowed;
          }
          .cancel-button {
            background-color: #dc3545;
          }
          .loading {
            text-align: center;
            color: #666;
          }
          .error {
            color: #dc3545;
            font-size: 14px;
            margin-top: 5px;
          }
        </style>
      </head>
      <body>
        <div class="payment-container">
          <div class="payment-header">
            <h2>Complete Payment</h2>
            <p>${razorpayOptions.description || 'Order Payment'}</p>
          </div>
          <div class="payment-amount">
            ₹${(razorpayOptions.amount / 100).toFixed(2)}
          </div>
          
          <div class="payment-methods">
            <!-- UPI Payment -->
            <div class="payment-method" id="upi-method">
              <div class="payment-method-header" onclick="togglePaymentMethod('upi')">
                <span>UPI Payment</span>
                <span>▼</span>
              </div>
              <div class="payment-method-content">
                <div class="input-group">
                  <label>UPI ID</label>
                  <input type="text" id="upi-id" placeholder="Enter UPI ID (e.g., user@paytm)" />
                  <div class="error" id="upi-error"></div>
                </div>
                <button class="payment-button" onclick="processUPIPayment()">Pay with UPI</button>
              </div>
            </div>

            <!-- Card Payment -->
            <div class="payment-method" id="card-method">
              <div class="payment-method-header" onclick="togglePaymentMethod('card')">
                <span>Credit/Debit Card</span>
                <span>▼</span>
              </div>
              <div class="payment-method-content">
                <div class="input-group">
                  <label>Card Number</label>
                  <input type="text" id="card-number" placeholder="1234 5678 9012 3456" maxlength="19" />
                  <div class="error" id="card-number-error"></div>
                </div>
                <div class="input-row">
                  <div class="input-group">
                    <label>Expiry Date</label>
                    <input type="text" id="card-expiry" placeholder="MM/YY" maxlength="5" />
                    <div class="error" id="card-expiry-error"></div>
                  </div>
                  <div class="input-group">
                    <label>CVV</label>
                    <input type="text" id="card-cvv" placeholder="123" maxlength="3" />
                    <div class="error" id="card-cvv-error"></div>
                  </div>
                </div>
                <div class="input-group">
                  <label>Cardholder Name</label>
                  <input type="text" id="card-name" placeholder="John Doe" />
                  <div class="error" id="card-name-error"></div>
                </div>
                <button class="payment-button" onclick="processCardPayment()">Pay with Card</button>
              </div>
            </div>

            <!-- Net Banking -->
            <div class="payment-method" id="netbanking-method">
              <div class="payment-method-header" onclick="togglePaymentMethod('netbanking')">
                <span>Net Banking</span>
                <span>▼</span>
              </div>
              <div class="payment-method-content">
                <div class="input-group">
                  <label>Select Bank</label>
                  <select id="bank-select">
                    <option value="">-- Select Bank --</option>
                    <option value="sbi">State Bank of India</option>
                    <option value="hdfc">HDFC Bank</option>
                    <option value="icici">ICICI Bank</option>
                    <option value="axis">Axis Bank</option>
                    <option value="kotak">Kotak Bank</option>
                    <option value="pnb">Punjab National Bank</option>
                    <option value="bob">Bank of Baroda</option>
                    <option value="other">Other Bank</option>
                  </select>
                  <div class="error" id="bank-error"></div>
                </div>
                <button class="payment-button" onclick="processNetBankingPayment()">Pay with Net Banking</button>
              </div>
            </div>
          </div>

          <button class="payment-button cancel-button" onclick="cancelPayment()">Cancel Payment</button>
          
          <div id="loading" class="loading" style="display: none;">
            Processing payment...
          </div>
        </div>

        <script>
          console.log('Payment page loaded');
          
          const options = ${JSON.stringify(razorpayOptions)};
          console.log('Payment options:', options);
          
          let activePaymentMethod = null;
          
          function togglePaymentMethod(method) {
            const methodElement = document.getElementById(method + '-method');
            const allMethods = document.querySelectorAll('.payment-method');
            
            // Close all other methods
            allMethods.forEach(m => {
              if (m.id !== method + '-method') {
                m.classList.remove('active');
              }
            });
            
            // Toggle current method
            if (methodElement.classList.contains('active')) {
              methodElement.classList.remove('active');
              activePaymentMethod = null;
            } else {
              methodElement.classList.add('active');
              activePaymentMethod = method;
            }
          }
          
          function sendMessage(type, data) {
            console.log('Sending message:', type, data);
            if (window.ReactNativeWebView) {
              window.ReactNativeWebView.postMessage(JSON.stringify({
                type: type,
                data: data
              }));
            } else {
              console.error('ReactNativeWebView not available');
            }
          }
          
          function simulatePayment(method) {
            console.log('Simulating payment for:', method);
            document.getElementById('loading').style.display = 'block';
            
            // Hide all payment methods
            document.querySelectorAll('.payment-methods').forEach(el => {
              el.style.display = 'none';
            });
            
            setTimeout(() => {
              const mockResponse = {
                razorpay_order_id: options.order_id,
                razorpay_payment_id: 'pay_mock_' + Date.now(),
                razorpay_signature: 'mock_signature_' + Date.now()
              };
              
              console.log('Payment successful:', mockResponse);
              sendMessage('success', mockResponse);
            }, 2000);
          }
          
          function validateUPI() {
            const upiId = document.getElementById('upi-id').value.trim();
            const errorElement = document.getElementById('upi-error');
            
            if (!upiId) {
              errorElement.textContent = 'UPI ID is required';
              return false;
            }
            
            if (!/^[\\w.-]+@[\\w.-]+$/.test(upiId)) {
              errorElement.textContent = 'Invalid UPI ID format';
              return false;
            }
            
            errorElement.textContent = '';
            return true;
          }
          
          function validateCard() {
            const cardNumber = document.getElementById('card-number').value.trim();
            const expiry = document.getElementById('card-expiry').value.trim();
            const cvv = document.getElementById('card-cvv').value.trim();
            const name = document.getElementById('card-name').value.trim();
            
            let isValid = true;
            
            // Card number validation
            if (!cardNumber) {
              document.getElementById('card-number-error').textContent = 'Card number is required';
              isValid = false;
            } else if (!/^\\d{4}\\s?\\d{4}\\s?\\d{4}\\s?\\d{4}$/.test(cardNumber.replace(/\\s/g, ''))) {
              document.getElementById('card-number-error').textContent = 'Invalid card number';
              isValid = false;
            } else {
              document.getElementById('card-number-error').textContent = '';
            }
            
            // Expiry validation
            if (!expiry) {
              document.getElementById('card-expiry-error').textContent = 'Expiry date is required';
              isValid = false;
            } else if (!/^(0[1-9]|1[0-2])\\/\\d{2}$/.test(expiry)) {
              document.getElementById('card-expiry-error').textContent = 'Invalid expiry date (MM/YY)';
              isValid = false;
            } else {
              document.getElementById('card-expiry-error').textContent = '';
            }
            
            // CVV validation
            if (!cvv) {
              document.getElementById('card-cvv-error').textContent = 'CVV is required';
              isValid = false;
            } else if (!/^\\d{3}$/.test(cvv)) {
              document.getElementById('card-cvv-error').textContent = 'Invalid CVV';
              isValid = false;
            } else {
              document.getElementById('card-cvv-error').textContent = '';
            }
            
            // Name validation
            if (!name) {
              document.getElementById('card-name-error').textContent = 'Cardholder name is required';
              isValid = false;
            } else {
              document.getElementById('card-name-error').textContent = '';
            }
            
            return isValid;
          }
          
          function validateBank() {
            const bank = document.getElementById('bank-select').value;
            const errorElement = document.getElementById('bank-error');
            
            if (!bank) {
              errorElement.textContent = 'Please select a bank';
              return false;
            }
            
            errorElement.textContent = '';
            return true;
          }
          
          function processUPIPayment() {
            if (validateUPI()) {
              simulatePayment('upi');
            }
          }
          
          function processCardPayment() {
            if (validateCard()) {
              simulatePayment('card');
            }
          }
          
          function processNetBankingPayment() {
            if (validateBank()) {
              simulatePayment('netbanking');
            }
          }
          
          function cancelPayment() {
            console.log('Payment cancelled');
            sendMessage('cancel');
          }
          
          // Format card number input
          document.getElementById('card-number')?.addEventListener('input', function(e) {
            let value = e.target.value.replace(/\\s/g, '');
            let formattedValue = value.match(/.{1,4}/g)?.join(' ') || value;
            e.target.value = formattedValue;
          });
          
          // Format expiry input
          document.getElementById('card-expiry')?.addEventListener('input', function(e) {
            let value = e.target.value.replace(/\\D/g, '');
            if (value.length >= 2) {
              value = value.slice(0, 2) + '/' + value.slice(2, 4);
            }
            e.target.value = value;
          });
          
          // Only allow numbers for CVV
          document.getElementById('card-cvv')?.addEventListener('input', function(e) {
            e.target.value = e.target.value.replace(/\\D/g, '');
          });
        </script>
      </body>
      </html>
    `;
  };

  const handleWebViewMessage = (event: any) => {
    console.log('WebView message received:', event.nativeEvent.data);
    
    try {
      const message = JSON.parse(event.nativeEvent.data);
      console.log('Parsed message:', message);
      
      setShowWebView(false);
      setIsLoading(false);

      switch (message.type) {
        case 'success':
          console.log('Payment success, calling onSuccess');
          onSuccess(message.data);
          break;
        case 'error':
          console.log('Payment error, calling onError');
          onError(message.data);
          break;
        case 'cancel':
          console.log('Payment cancelled, calling onCancel');
          onCancel();
          break;
        default:
          console.log('Unknown message type:', message.type);
      }
    } catch (error) {
      console.error('Error parsing WebView message:', error);
      setShowWebView(false);
      setIsLoading(false);
      onError('Payment processing error');
    }
  };

  if (isLoading && !showWebView) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={theme.colors.primary} />
        <Text style={[styles.loadingText, { color: theme.colors.primary }]}>
          Initializing Payment...
        </Text>
      </View>
    );
  }

  return (
    <Modal
      visible={showWebView}
      animationType="slide"
      presentationStyle="fullScreen"
      onRequestClose={onCancel}
    >
      {options && (
        <WebView
          ref={webViewRef}
          source={{ html: generateRazorpayHTML(options) }}
          onMessage={handleWebViewMessage}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          startInLoadingState={true}
          renderLoading={() => (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={theme.colors.primary} />
              <Text style={[styles.loadingText, { color: theme.colors.primary }]}>
                Loading Payment...
              </Text>
            </View>
          )}
        />
      )}
    </Modal>
  );
};

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    fontWeight: '500',
  },
});

export default RealRazorpayPayment;
