import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet, ActivityIndicator } from 'react-native';
import {
  NavigationContainer,
  NavigationContainerRef,
  CommonActions,
} from '@react-navigation/native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import RootTabNavigator from './src/navigation/RootTabNavigator';
import FloatingSosButton from './src/components/FloatingSosButton';
import OnboardingScreen from './src/screens/OnboardingScreen';
import { colors } from './src/theme/colors';
import { Trip } from './src/types';

const ONBOARDING_KEY = 'angotour:has_onboarded';
const HIDDEN_ROUTES = ['Sos', 'DriverFound', 'DuringTrip'];

export default function App() {
  const navigationRef = useRef<NavigationContainerRef<any>>(null);
  const [currentRouteName, setCurrentRouteName] = useState<string | undefined>();
  const [isCheckingOnboarding, setIsCheckingOnboarding] = useState(true);
  const [hasOnboarded, setHasOnboarded] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem(ONBOARDING_KEY)
      .then((value) => setHasOnboarded(value === 'true'))
      .finally(() => setIsCheckingOnboarding(false));
  }, []);

  const handleFinishOnboarding = async () => {
    await AsyncStorage.setItem(ONBOARDING_KEY, 'true');
    setHasOnboarded(true);
  };

  const updateCurrentRoute = () => {
    setCurrentRouteName(navigationRef.current?.getCurrentRoute()?.name);
  };

  const handleSosPress = (trip: Trip | null) => {
    navigationRef.current?.dispatch(
      CommonActions.navigate({
        name: 'HomeStack',
        params: { screen: 'Sos', params: { trip: trip ?? undefined } },
      })
    );
  };

  const showFloatingButton =
    currentRouteName !== undefined && !HIDDEN_ROUTES.includes(currentRouteName);

  if (isCheckingOnboarding) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator color={colors.primary} size="large" />
      </View>
    );
  }

  if (!hasOnboarded) {
    return (
      <SafeAreaProvider>
        <OnboardingScreen onFinish={handleFinishOnboarding} />
      </SafeAreaProvider>
    );
  }

  return (
    <SafeAreaProvider>
      <NavigationContainer
        ref={navigationRef}
        onReady={updateCurrentRoute}
        onStateChange={updateCurrentRoute}
      >
        <View style={styles.root}>
          <RootTabNavigator />
          {showFloatingButton && <FloatingSosButton onPress={handleSosPress} />}
        </View>
      </NavigationContainer>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.background,
  },
});