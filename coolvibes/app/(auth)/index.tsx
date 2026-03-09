import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import AuthWizard from '@/components/AuthWizard';
import { useTheme } from '@react-navigation/native';

export default function AuthIndexScreen() {
    const router = useRouter();
    const { colors } = useTheme();

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <AuthWizard 
                isOpen={true} 
                onClose={() => router.replace('/(tabs)')} 
                mode="standalone"
            />
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
});
