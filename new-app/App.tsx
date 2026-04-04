import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { Provider as ReduxProvider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { Provider as PaperProvider } from 'react-native-paper';
import { ApolloProvider } from '@apollo/client';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

// DEV-ONLY: hide noisy Apollo canonizeResults warning
if (__DEV__) {
  const originalWarn = console.warn;
  console.warn = (...args) => {
    const first = args[0];
    if (
      typeof first === 'string' &&
      first.includes('[cache.diff]: `canonizeResults` is deprecated')
    ) {
      return;
    }
    originalWarn(...args);
  };
}

// Store and services
import { store, persistor } from './src/store';
import { apolloClient } from './src/services/apollo';

// Theme
import { lightTheme, darkTheme } from './src/theme';

// Navigation
import RootNavigator from './src/navigation/RootNavigator';

// Redux hooks and actions
import { useAppSelector } from './src/hooks/useTypedSelector';

function AppContent() {
  const theme = useAppSelector((state) => state.app.theme);
  const currentTheme = theme === 'dark' ? darkTheme : lightTheme;

  return (
    <PaperProvider theme={currentTheme}>
      <SafeAreaProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
          <RootNavigator />
          <StatusBar style={theme === 'dark' ? 'light' : 'dark'} />
        </GestureHandlerRootView>
      </SafeAreaProvider>
    </PaperProvider>
  );
}

export default function App() {
  return (
    <ReduxProvider store={store}>
      <PersistGate loading={null} persistor={persistor}>
        <ApolloProvider client={apolloClient}>
          <AppContent />
        </ApolloProvider>
      </PersistGate>
    </ReduxProvider>
  );
}
