import { VALIDATION } from '@/constants';

// Email validation
export const validateEmail = (email: string): boolean => {
  return VALIDATION.EMAIL_REGEX.test(email.trim());
};

// Phone validation (Indian format)
export const validatePhone = (phone: string): boolean => {
  return VALIDATION.PHONE_REGEX.test(phone.trim());
};

// Pincode validation (Indian format)
export const validatePincode = (pincode: string): boolean => {
  return VALIDATION.PINCODE_REGEX.test(pincode.trim());
};

// Password validation
export const validatePassword = (password: string): boolean => {
  return password.length >= VALIDATION.MIN_PASSWORD_LENGTH;
};

// Required field validation
export const validateRequired = (value: string): boolean => {
  return value.trim().length > 0;
};

// Form validation helper
export interface ValidationError {
  field: string;
  message: string;
}

export const validateForm = (
  values: Record<string, any>,
  rules: Record<string, (value: any) => string | null>
): ValidationError[] => {
  const errors: ValidationError[] = [];

  Object.keys(rules).forEach((field) => {
    const error = rules[field](values[field]);
    if (error) {
      errors.push({ field, message: error });
    }
  });

  return errors;
};
