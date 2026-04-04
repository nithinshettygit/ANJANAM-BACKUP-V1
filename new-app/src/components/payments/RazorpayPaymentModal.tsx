import React, { useEffect, useRef, useState } from 'react';
import { Modal, View, StyleSheet, ActivityIndicator } from 'react-native';
import { Appbar, useTheme } from 'react-native-paper';
import { WebView, WebViewMessageEvent } from 'react-native-webview';
import { RazorpayOptions } from '@/types';

type PaymentSuccessPayload = {
  razorpayOrderId: string;
  razorpayPaymentId: string;
  razorpaySignature: string;
};

interface RazorpayPaymentModalProps {
  visible: boolean;
  options: RazorpayOptions | null;
  onSuccess: (payload: PaymentSuccessPayload) => void;
  onCancel: () => void;
  onError: (message: string) => void;
}

const htmlContent = `
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
    <style>
      body { 
        margin: 0; 
        padding: 20px; 
        font-family: Arial, sans-serif; 
        background: #f5f5f5;
      }
      .container { 
        text-align: center; 
        padding: 20px;
        background: white;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      }
      .button {
        background: #3399cc;
        color: white;
        border: none;
        padding: 15px 30px;
        border-radius: 4px;
        font-size: 16px;
        cursor: pointer;
        margin: 10px;
      }
      .button:hover { background: #2288bb; }
      .button.cancel { background: #cc3333; }
      .button.cancel:hover { background: #bb2222; }
      .loading { color: #666; font-size: 18px; }
    </style>
  </head>
  <body>
    <div class="container">
      <h3>Mock Payment</h3>
      <p class="loading">Processing payment...</p>
      <div id="payment-options" style="display: none;">
        <p>Complete your mock payment:</p>
        <button class="button" onclick="completePayment()">Pay Now</button>
        <button class="button cancel" onclick="cancelPayment()">Cancel</button>
      </div>
    </div>
    
    <script>
      document.addEventListener("message", function(event) {
        try {
          var data = JSON.parse(event.data);
          if (data.type === "OPEN") {
            console.log('Opening payment with options:', data.options);
            // Show payment options after a short delay
            setTimeout(function() {
              document.querySelector('.loading').style.display = 'none';
              document.getElementById('payment-options').style.display = 'block';
            }, 1000);
            
            // Store options for payment completion
            window.paymentOptions = data.options;
          }
        } catch (e) {
          console.error('Error:', e);
          window.ReactNativeWebView.postMessage(JSON.stringify({
            event: "error",
            message: "Unable to start payment"
          }));
        }
      });
      
      function completePayment() {
        console.log('Payment completed');
        window.ReactNativeWebView.postMessage(JSON.stringify({
          event: "success",
          razorpayPaymentId: "pay_mock_" + Date.now(),
          razorpayOrderId: window.paymentOptions?.order_id || "order_mock",
          razorpaySignature: "mock_signature_" + Date.now()
        }));
      }
      
      function cancelPayment() {
        console.log('Payment cancelled');
        window.ReactNativeWebView.postMessage(JSON.stringify({
          event: "cancel"
        }));
      }
    </script>
  </body>
</html>
`;

const RazorpayPaymentModal: React.FC<RazorpayPaymentModalProps> = ({
  visible,
  options,
  onSuccess,
  onCancel,
  onError,
}) => {
  const theme = useTheme();
  const webViewRef = useRef<WebView | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (visible && options && ready && webViewRef.current) {
      const payload = { type: 'OPEN', options };
      webViewRef.current.postMessage(JSON.stringify(payload));
    }
  }, [visible, options, ready]);

  const handleMessage = (event: WebViewMessageEvent) => {
    let data: any;
    try {
      data = JSON.parse(event.nativeEvent.data);
    } catch {
      return;
    }

    if (data.event === 'success') {
      onSuccess({
        razorpayOrderId: data.razorpayOrderId,
        razorpayPaymentId: data.razorpayPaymentId,
        razorpaySignature: data.razorpaySignature,
      });
    } else if (data.event === 'cancel') {
      onCancel();
    } else if (data.event === 'error') {
      const message = typeof data.message === 'string' ? data.message : 'Payment failed';
      onError(message);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={styles.backdrop}>
        <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
          <Appbar.Header>
            <Appbar.BackAction onPress={onCancel} />
            <Appbar.Content title="Complete Payment" />
          </Appbar.Header>
          {!options ? (
            <View style={styles.loaderContainer}>
              <ActivityIndicator size="large" color={theme.colors.primary} />
            </View>
          ) : (
            <WebView
              ref={(ref) => {
                webViewRef.current = ref;
              }}
              originWhitelist={["*"]}
              source={{ html: htmlContent, baseUrl: 'https://checkout.razorpay.com' }}
              onMessage={handleMessage}
              onLoadEnd={() => setReady(true)}
            />
          )}
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  container: {
    height: '80%',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    overflow: 'hidden',
  },
  loaderContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
});

export default RazorpayPaymentModal;
