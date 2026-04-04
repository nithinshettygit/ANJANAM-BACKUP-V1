import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  Modal,
  Animated,
  Dimensions,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  ScrollView,
  Image,
} from 'react-native';
import { Appbar, useTheme, Button, Card, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { RazorpayOptions } from '@/types';

const { width, height } = Dimensions.get('window');

interface ProfessionalPaymentModalProps {
  visible: boolean;
  options: RazorpayOptions | null;
  onSuccess: (payload: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    razorpaySignature: string;
  }) => void;
  onCancel: () => void;
  onError: (message: string) => void;
}

const ProfessionalPaymentModal: React.FC<ProfessionalPaymentModalProps> = ({
  visible,
  options,
  onSuccess,
  onCancel,
  onError,
}) => {
  const theme = useTheme();
  const [paymentState, setPaymentState] = useState<'loading' | 'ready' | 'processing' | 'success' | 'error'>('loading');
  const [animatedValue] = useState(new Animated.Value(0));
  const webViewRef = useRef<any>(null);

  useEffect(() => {
    if (visible && options) {
      setPaymentState('ready');
      Animated.timing(animatedValue, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }).start();
    } else if (!visible) {
      animatedValue.setValue(0);
      setPaymentState('loading');
    }
  }, [visible, options]);

  const handlePayNow = () => {
    setPaymentState('processing');
    
    // Simulate payment processing
    setTimeout(() => {
      // Generate mock payment data
      const mockPaymentData = {
        razorpayOrderId: options?.order_id || `order_mock_${Date.now()}`,
        razorpayPaymentId: `pay_mock_${Date.now()}`,
        razorpaySignature: `mock_signature_${Date.now()}`,
      };
      
      setPaymentState('success');
      setTimeout(() => {
        onSuccess(mockPaymentData);
      }, 1500);
    }, 2000);
  };

  const handleCancel = () => {
    Animated.timing(animatedValue, {
      toValue: 0,
      duration: 200,
      useNativeDriver: true,
    }).start(() => {
      onCancel();
    });
  };

  const renderPaymentContent = () => {
    switch (paymentState) {
      case 'loading':
        return (
          <View style={styles.centerContainer}>
            <ActivityIndicator size="large" color={theme.colors.primary} />
            <Text style={[styles.loadingText, { color: theme.colors.onSurface }]}>
              Initializing payment...
            </Text>
          </View>
        );

      case 'ready':
        return (
          <ScrollView style={styles.paymentContent} showsVerticalScrollIndicator={false}>
            {/* Header */}
            <View style={styles.header}>
              <View style={styles.headerContent}>
                <View style={[styles.iconContainer, { backgroundColor: theme.colors.primary }]}>
                  <MaterialCommunityIcons name="shield-check" size={32} color="white" />
                </View>
                <Text style={[styles.headerTitle, { color: theme.colors.onSurface }]}>
                  Secure Payment
                </Text>
                <Text style={[styles.headerSubtitle, { color: theme.colors.onSurfaceVariant }]}>
                  Powered by Razorpay
                </Text>
              </View>
            </View>

            {/* Order Summary */}
            <Card style={styles.card}>
              <Card.Content>
                <Text style={[styles.sectionTitle, { color: theme.colors.onSurface }]}>
                  Order Summary
                </Text>
                <Divider style={styles.divider} />
                
                <View style={styles.summaryRow}>
                  <Text style={[styles.summaryLabel, { color: theme.colors.onSurfaceVariant }]}>
                    Order ID
                  </Text>
                  <Text style={[styles.summaryValue, { color: theme.colors.onSurface }]}>
                    {options?.description?.replace('Order ', '') || 'N/A'}
                  </Text>
                </View>
                
                <View style={styles.summaryRow}>
                  <Text style={[styles.summaryLabel, { color: theme.colors.onSurfaceVariant }]}>
                    Amount
                  </Text>
                  <Text style={[styles.summaryValue, { color: theme.colors.primary, fontWeight: 'bold' }]}>
                    ₹{(options?.amount || 0) / 100}
                  </Text>
                </View>

                <View style={styles.summaryRow}>
                  <Text style={[styles.summaryLabel, { color: theme.colors.onSurfaceVariant }]}>
                    Payment Method
                  </Text>
                  <Text style={[styles.summaryValue, { color: theme.colors.onSurface }]}>
                    Razorpay
                  </Text>
                </View>
              </Card.Content>
            </Card>

            {/* Payment Methods */}
            <Card style={styles.card}>
              <Card.Content>
                <Text style={[styles.sectionTitle, { color: theme.colors.onSurface }]}>
                  Payment Methods
                </Text>
                <Divider style={styles.divider} />
                
                <TouchableOpacity style={styles.paymentMethod}>
                  <View style={styles.paymentMethodContent}>
                    <View style={[styles.paymentIcon, { backgroundColor: '#2C2E2E' }]}>
                      <MaterialCommunityIcons name="credit-card" size={20} color="white" />
                    </View>
                    <View style={styles.paymentDetails}>
                      <Text style={[styles.paymentName, { color: theme.colors.onSurface }]}>
                        Credit/Debit Card
                      </Text>
                      <Text style={[styles.paymentDesc, { color: theme.colors.onSurfaceVariant }]}>
                        Visa, Mastercard, Rupay
                      </Text>
                    </View>
                    <MaterialCommunityIcons 
                      name="chevron-right" 
                      size={20} 
                      color={theme.colors.onSurfaceVariant} 
                    />
                  </View>
                </TouchableOpacity>

                <TouchableOpacity style={styles.paymentMethod}>
                  <View style={styles.paymentMethodContent}>
                    <View style={[styles.paymentIcon, { backgroundColor: '#535353' }]}>
                      <MaterialCommunityIcons name="bank" size={20} color="white" />
                    </View>
                    <View style={styles.paymentDetails}>
                      <Text style={[styles.paymentName, { color: theme.colors.onSurface }]}>
                        Net Banking
                      </Text>
                      <Text style={[styles.paymentDesc, { color: theme.colors.onSurfaceVariant }]}>
                        All major banks
                      </Text>
                    </View>
                    <MaterialCommunityIcons 
                      name="chevron-right" 
                      size={20} 
                      color={theme.colors.onSurfaceVariant} 
                    />
                  </View>
                </TouchableOpacity>

                <TouchableOpacity style={styles.paymentMethod}>
                  <View style={styles.paymentMethodContent}>
                    <View style={[styles.paymentIcon, { backgroundColor: '#00C896' }]}>
                      <MaterialCommunityIcons name="wallet" size={20} color="white" />
                    </View>
                    <View style={styles.paymentDetails}>
                      <Text style={[styles.paymentName, { color: theme.colors.onSurface }]}>
                        UPI
                      </Text>
                      <Text style={[styles.paymentDesc, { color: theme.colors.onSurfaceVariant }]}>
                        Google Pay, PhonePe, Paytm
                      </Text>
                    </View>
                    <MaterialCommunityIcons 
                      name="chevron-right" 
                      size={20} 
                      color={theme.colors.onSurfaceVariant} 
                    />
                  </View>
                </TouchableOpacity>

                <TouchableOpacity style={styles.paymentMethod}>
                  <View style={styles.paymentMethodContent}>
                    <View style={[styles.paymentIcon, { backgroundColor: '#FF6B35' }]}>
                      <MaterialCommunityIcons name="cash" size={20} color="white" />
                    </View>
                    <View style={styles.paymentDetails}>
                      <Text style={[styles.paymentName, { color: theme.colors.onSurface }]}>
                        Cash on Delivery
                      </Text>
                      <Text style={[styles.paymentDesc, { color: theme.colors.onSurfaceVariant }]}>
                        Pay when you receive
                      </Text>
                    </View>
                    <MaterialCommunityIcons 
                      name="chevron-right" 
                      size={20} 
                      color={theme.colors.onSurfaceVariant} 
                    />
                  </View>
                </TouchableOpacity>
              </Card.Content>
            </Card>

            {/* Security Badge */}
            <View style={styles.securitySection}>
              <View style={styles.securityContent}>
                <MaterialCommunityIcons name="lock" size={16} color={theme.colors.primary} />
                <Text style={[styles.securityText, { color: theme.colors.onSurfaceVariant }]}>
                  Your payment information is secure and encrypted
                </Text>
              </View>
            </View>
          </ScrollView>
        );

      case 'processing':
        return (
          <View style={styles.centerContainer}>
            <ActivityIndicator size="large" color={theme.colors.primary} />
            <Text style={[styles.loadingText, { color: theme.colors.onSurface }]}>
              Processing payment...
            </Text>
            <Text style={[styles.loadingSubtext, { color: theme.colors.onSurfaceVariant }]}>
              Please don't close this window
            </Text>
          </View>
        );

      case 'success':
        return (
          <View style={styles.centerContainer}>
            <View style={[styles.successIcon, { backgroundColor: '#4CAF50' }]}>
              <MaterialCommunityIcons name="check" size={48} color="white" />
            </View>
            <Text style={[styles.successTitle, { color: theme.colors.onSurface }]}>
              Payment Successful!
            </Text>
            <Text style={[styles.successMessage, { color: theme.colors.onSurfaceVariant }]}>
              Your order has been placed successfully
            </Text>
          </View>
        );

      case 'error':
        return (
          <View style={styles.centerContainer}>
            <View style={[styles.errorIcon, { backgroundColor: '#F44336' }]}>
              <MaterialCommunityIcons name="close" size={48} color="white" />
            </View>
            <Text style={[styles.errorTitle, { color: theme.colors.onSurface }]}>
              Payment Failed
            </Text>
            <Text style={[styles.errorMessage, { color: theme.colors.onSurfaceVariant }]}>
              Something went wrong. Please try again.
            </Text>
            <Button 
              mode="contained" 
              onPress={() => setPaymentState('ready')}
              style={styles.retryButton}
            >
              Try Again
            </Button>
          </View>
        );

      default:
        return null;
    }
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent
      statusBarTranslucent
    >
      <View style={styles.overlay}>
        <Animated.View
          style={[
            styles.modalContainer,
            {
              backgroundColor: theme.colors.surface,
              transform: [
                {
                  translateY: animatedValue.interpolate({
                    inputRange: [0, 1],
                    outputRange: [height, 0],
                  }),
                },
              ],
            },
          ]}
        >
          {/* Header */}
          <Appbar.Header style={[styles.headerBar, { backgroundColor: theme.colors.surface }]}>
            <Appbar.BackAction onPress={handleCancel} />
            <Appbar.Content title="Complete Payment" />
          </Appbar.Header>

          {/* Content */}
          <View style={styles.content}>
            {renderPaymentContent()}
          </View>

          {/* Bottom Action */}
          {paymentState === 'ready' && (
            <View style={[styles.bottomAction, { borderTopColor: theme.colors.outline }]}>
              <Button
                mode="contained"
                onPress={handlePayNow}
                style={[styles.payButton, { backgroundColor: theme.colors.primary }]}
                contentStyle={styles.payButtonContent}
                labelStyle={styles.payButtonLabel}
              >
                Pay ₹{(options?.amount || 0) / 100}
              </Button>
            </View>
          )}
        </Animated.View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContainer: {
    flex: 1,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    overflow: 'hidden',
  },
  headerBar: {
    elevation: 0,
    shadowOpacity: 0,
  },
  content: {
    flex: 1,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  loadingText: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 16,
  },
  loadingSubtext: {
    fontSize: 14,
    marginTop: 8,
  },
  paymentContent: {
    flex: 1,
    padding: 16,
  },
  header: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  headerContent: {
    alignItems: 'center',
  },
  iconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 14,
  },
  card: {
    marginBottom: 16,
    elevation: 2,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 12,
  },
  divider: {
    marginBottom: 12,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  summaryLabel: {
    fontSize: 14,
  },
  summaryValue: {
    fontSize: 14,
    fontWeight: '500',
  },
  paymentMethod: {
    paddingVertical: 12,
  },
  paymentMethodContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  paymentIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  paymentDetails: {
    flex: 1,
  },
  paymentName: {
    fontSize: 16,
    fontWeight: '500',
  },
  paymentDesc: {
    fontSize: 12,
    marginTop: 2,
  },
  securitySection: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  securityContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  securityText: {
    fontSize: 12,
    marginLeft: 8,
    flex: 1,
    textAlign: 'center',
  },
  successIcon: {
    width: 80,
    height: 80,
    borderRadius: 40,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  successTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  successMessage: {
    fontSize: 14,
    textAlign: 'center',
  },
  errorIcon: {
    width: 80,
    height: 80,
    borderRadius: 40,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  errorMessage: {
    fontSize: 14,
    textAlign: 'center',
    marginBottom: 16,
  },
  retryButton: {
    marginTop: 16,
  },
  bottomAction: {
    padding: 16,
    borderTopWidth: 1,
  },
  payButton: {
    borderRadius: 8,
  },
  payButtonContent: {
    paddingVertical: 12,
  },
  payButtonLabel: {
    fontSize: 16,
    fontWeight: '600',
  },
});

export default ProfessionalPaymentModal;
