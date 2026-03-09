import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '@react-navigation/native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function NearbyScreen() {
    const { colors, dark } = useTheme();

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <MaterialCommunityIcons name="radar" size={64} color={colors.text} style={{ opacity: 0.2 }} />
            <Text style={[styles.text, { color: colors.text }]}>Nearby Feature Coming Soon</Text>
            <Text style={[styles.subText, { color: colors.text }]}>Find who's chilling near you.</Text>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        padding: 20,
    },
    text: {
        fontSize: 24,
        fontFamily: 'Outfit-Black',
        marginTop: 20,
        textTransform: 'uppercase',
    },
    subText: {
        fontSize: 16,
        fontFamily: 'Inter-Regular',
        opacity: 0.6,
        marginTop: 10,
        textAlign: 'center',
    }
});
