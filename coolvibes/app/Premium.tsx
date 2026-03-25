import React, { useMemo, useState } from 'react';
import {
  Alert,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';

import { usePremiumAccess } from '@/hooks/usePremiumAccess';

type BillingCycle = 'monthly' | 'yearly';

type PlanDefinition = {
  cycle: BillingCycle;
  label: string;
  badge?: string;
  price: string;
  period: string;
  summary: string;
  note: string;
};

type BenefitDefinition = {
  icon: React.ComponentProps<typeof MaterialCommunityIcons>['name'];
  title: string;
  description: string;
};

const YEARLY_PRICE = 89.99;
const MONTHLY_PRICE = 11.99;
const YEARLY_EQUIVALENT = (YEARLY_PRICE / 12).toFixed(2);
const YEARLY_SAVINGS = (MONTHLY_PRICE * 12 - YEARLY_PRICE).toFixed(2);

const PLAN_DEFINITIONS: PlanDefinition[] = [
  {
    cycle: 'yearly',
    label: 'Yearly',
    badge: 'Best value',
    price: `$${YEARLY_PRICE.toFixed(2)}`,
    period: '/year',
    summary: `Only $${YEARLY_EQUIVALENT}/month billed yearly`,
    note: `Save $${YEARLY_SAVINGS} compared with paying monthly`,
  },
  {
    cycle: 'monthly',
    label: 'Monthly',
    price: `$${MONTHLY_PRICE.toFixed(2)}`,
    period: '/month',
    summary: 'Full Premium access with monthly billing',
    note: 'More flexible, higher effective price',
  },
];

const BENEFITS: BenefitDefinition[] = [
  {
    icon: 'eye-outline',
    title: 'More visibility',
    description: 'Show up with a stronger presence where meaningful connections begin.',
  },
  {
    icon: 'heart-multiple-outline',
    title: 'Better dating signals',
    description: 'See more useful engagement context before you decide who to invest in.',
  },
  {
    icon: 'tune-variant',
    title: 'More control',
    description: 'Shape a cleaner, more intentional dating experience around your preferences.',
  },
];

const PRIDE_COLORS = ['#E40303', '#FF8C00', '#FFED00', '#008026', '#24408E', '#732982'];

const getStoreLabel = (provider: string | null) => {
  if (provider === 'app_store') return 'App Store';
  if (provider === 'play_store') return 'Google Play';
  return Platform.OS === 'ios'
    ? 'App Store'
    : Platform.OS === 'android'
      ? 'Google Play'
      : 'store billing';
};

function PrideStrip({ compact = false }: { compact?: boolean }) {
  return (
    <View style={[styles.prideStrip, compact ? styles.prideStripCompact : null]}>
      {PRIDE_COLORS.map((color) => (
        <View key={color} style={[styles.prideSegment, { backgroundColor: color }]} />
      ))}
    </View>
  );
}

export default function PremiumScreen() {
  const { dark } = useTheme();
  const insets = useSafeAreaInsets();
  const [selectedCycle, setSelectedCycle] = useState<BillingCycle>('yearly');
  const {
    billingEnabled,
    billingProvider,
    isPremiumUser,
    premiumEntitlement,
    premiumPaywallEnabled,
  } = usePremiumAccess();

  const selectedPlan = useMemo(
    () => PLAN_DEFINITIONS.find((plan) => plan.cycle === selectedCycle) ?? PLAN_DEFINITIONS[0],
    [selectedCycle]
  );

  const storeLabel = getStoreLabel(billingProvider);
  const screenBackground = dark ? '#070B14' : '#F6F7FB';
  const surface = dark ? '#101826' : '#FFFFFF';
  const mutedSurface = dark ? 'rgba(255,255,255,0.05)' : '#F2F4F8';
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const selectedBorder = dark ? '#FFFFFF' : '#111827';
  const textPrimary = dark ? '#F8FAFC' : '#0F172A';
  const textMuted = dark ? 'rgba(248,250,252,0.72)' : '#64748B';
  const textSoft = dark ? 'rgba(248,250,252,0.56)' : '#94A3B8';
  const buttonBackground = dark ? '#F8FAFC' : '#111827';
  const buttonText = dark ? '#111827' : '#FFFFFF';

  const handlePurchasePress = () => {
    if (isPremiumUser) {
      Alert.alert('Premium active', 'This account already has Premium access.');
      return;
    }

    if (!premiumPaywallEnabled || !billingEnabled) {
      Alert.alert('Billing unavailable', 'Premium purchases are not enabled in this build yet.');
      return;
    }

    Alert.alert(
      'Purchase flow placeholder',
      `Start the ${selectedPlan.label.toLowerCase()} plan through ${storeLabel}.`
    );
  };

  const handleRestorePress = () => {
    Alert.alert('Restore purchases', `Restore flow for ${storeLabel} should be connected here.`);
  };

  const primaryCta = isPremiumUser
    ? 'Premium active'
    : selectedCycle === 'yearly'
      ? 'Continue with yearly'
      : 'Continue with monthly';

  return (
    <View style={[styles.container, { backgroundColor: screenBackground }]}> 
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: insets.bottom + 166 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        <View
          style={[
            styles.heroCard,
            {
              backgroundColor: surface,
              borderColor,
            },
          ]}
        >
          <PrideStrip />

          <View style={styles.heroBody}>
            <View
              style={[
                styles.heroBadge,
                {
                  backgroundColor: mutedSurface,
                  borderColor,
                },
              ]}
            >
              <MaterialCommunityIcons name="crown-outline" size={14} color={PRIDE_COLORS[5]} />
              <Text style={[styles.heroBadgeText, { color: textPrimary }]}>COOLVIBES PREMIUM</Text>
            </View>

            <Text style={[styles.heroTitle, { color: textPrimary }]}>Upgrade in two steps.</Text>
            <Text style={[styles.heroSubtitle, { color: textMuted }]}> 
              Choose a plan below, continue securely in {storeLabel}, and unlock a more refined LGBTQIA+ dating experience.
            </Text>

            <View style={styles.stepList}>
              <View style={styles.stepRow}>
                <View style={[styles.stepNumber, { backgroundColor: mutedSurface, borderColor }]}>
                  <Text style={[styles.stepNumberText, { color: textPrimary }]}>1</Text>
                </View>
                <Text style={[styles.stepText, { color: textPrimary }]}>Select the plan that fits you.</Text>
              </View>
              <View style={styles.stepRow}>
                <View style={[styles.stepNumber, { backgroundColor: mutedSurface, borderColor }]}>
                  <Text style={[styles.stepNumberText, { color: textPrimary }]}>2</Text>
                </View>
                <Text style={[styles.stepText, { color: textPrimary }]}>Confirm securely in {storeLabel}.</Text>
              </View>
            </View>

            <View style={styles.heroMetaRow}>
              <View
                style={[
                  styles.metaPill,
                  {
                    backgroundColor: mutedSurface,
                    borderColor,
                  },
                ]}
              >
                <Text style={[styles.metaPillText, { color: textPrimary }]}>Yearly saves ${YEARLY_SAVINGS}</Text>
              </View>
              <Text style={[styles.metaHint, { color: textMuted }]}>Cancel anytime</Text>
            </View>
          </View>
        </View>

        {isPremiumUser ? (
          <View
            style={[
              styles.statusCard,
              {
                backgroundColor: dark ? 'rgba(16,185,129,0.10)' : '#ECFDF5',
                borderColor: dark ? 'rgba(16,185,129,0.20)' : '#BBF7D0',
              },
            ]}
          >
            <MaterialCommunityIcons name="check-decagram" size={18} color="#10B981" />
            <View style={styles.statusContent}>
              <Text style={[styles.statusTitle, { color: textPrimary }]}>Premium is already active</Text>
              <Text style={[styles.statusText, { color: textMuted }]}> 
                Status: {premiumEntitlement.status || 'active'}
                {premiumEntitlement.provider ? ` via ${getStoreLabel(premiumEntitlement.provider)}` : ''}
              </Text>
            </View>
          </View>
        ) : null}

        <View style={styles.sectionHeader}>
          <Text style={[styles.sectionLabel, { color: textSoft }]}>1. Select a plan</Text>
          <Text style={[styles.sectionTitle, { color: textPrimary }]}>Choose the plan you want to start with.</Text>
        </View>

        <View style={styles.planList}>
          {PLAN_DEFINITIONS.map((plan) => {
            const selected = plan.cycle === selectedCycle;
            return (
              <Pressable
                key={plan.cycle}
                onPress={() => setSelectedCycle(plan.cycle)}
                style={({ pressed }) => [
                  styles.planCard,
                  {
                    backgroundColor: surface,
                    borderColor: selected ? selectedBorder : borderColor,
                    opacity: pressed ? 0.97 : 1,
                  },
                ]}
              >
                {selected ? <PrideStrip compact /> : null}

                <View style={styles.planCardBody}>
                  <View style={styles.planHeaderRow}>
                    <View style={styles.planHeaderCopy}>
                      <View style={styles.planTitleRow}>
                        <Text style={[styles.planTitle, { color: textPrimary }]}>{plan.label}</Text>
                        {plan.badge ? (
                          <View style={[styles.planBadge, { backgroundColor: mutedSurface, borderColor }]}>
                            <Text style={[styles.planBadgeText, { color: PRIDE_COLORS[5] }]}>{plan.badge}</Text>
                          </View>
                        ) : null}
                      </View>
                      <Text style={[styles.planSummary, { color: textMuted }]}>{plan.summary}</Text>
                    </View>

                    <View
                      style={[
                        styles.planIndicator,
                        {
                          borderColor: selected ? selectedBorder : borderColor,
                          backgroundColor: selected ? selectedBorder : 'transparent',
                        },
                      ]}
                    >
                      {selected ? <MaterialCommunityIcons name="check" size={14} color={dark ? '#111827' : '#FFFFFF'} /> : null}
                    </View>
                  </View>

                  <View style={styles.planPriceRow}>
                    <Text style={[styles.planPrice, { color: textPrimary }]}>{plan.price}</Text>
                    <Text style={[styles.planPeriod, { color: textMuted }]}>{plan.period}</Text>
                  </View>

                  <Text style={[styles.planNote, { color: textPrimary }]}>{plan.note}</Text>
                </View>
              </Pressable>
            );
          })}
        </View>

        <View style={styles.sectionHeader}>
          <Text style={[styles.sectionLabel, { color: textSoft }]}>Included with Premium</Text>
          <Text style={[styles.sectionTitle, { color: textPrimary }]}>Clear value, without extra noise.</Text>
        </View>

        <View
          style={[
            styles.benefitsCard,
            {
              backgroundColor: surface,
              borderColor,
            },
          ]}
        >
          {BENEFITS.map((item, index) => (
            <View
              key={item.title}
              style={[
                styles.benefitRow,
                index < BENEFITS.length - 1
                  ? { borderBottomWidth: 1, borderBottomColor: borderColor }
                  : null,
              ]}
            >
              <View style={[styles.benefitIconWrap, { backgroundColor: mutedSurface }]}>
                <MaterialCommunityIcons name={item.icon} size={18} color={PRIDE_COLORS[index % PRIDE_COLORS.length]} />
              </View>
              <View style={styles.benefitCopy}>
                <Text style={[styles.benefitTitle, { color: textPrimary }]}>{item.title}</Text>
                <Text style={[styles.benefitDescription, { color: textMuted }]}>{item.description}</Text>
              </View>
            </View>
          ))}
        </View>

        {!billingEnabled ? (
          <View
            style={[
              styles.noticeCard,
              {
                backgroundColor: dark ? 'rgba(245,158,11,0.10)' : '#FFF8EB',
                borderColor: dark ? 'rgba(245,158,11,0.18)' : '#F4D08C',
              },
            ]}
          >
            <MaterialCommunityIcons name="alert-circle-outline" size={18} color="#F59E0B" />
            <Text style={[styles.noticeText, { color: textPrimary }]}>Premium billing is not enabled in this build yet.</Text>
          </View>
        ) : (
          <View
            style={[
              styles.noticeCard,
              {
                backgroundColor: surface,
                borderColor,
              },
            ]}
          >
            <MaterialCommunityIcons name="shield-check-outline" size={18} color={PRIDE_COLORS[4]} />
            <Text style={[styles.noticeText, { color: textMuted }]}>Billing is handled securely by {storeLabel}. You can manage or cancel anytime in store settings.</Text>
          </View>
        )}
      </ScrollView>

      <View
        style={[
          styles.footer,
          {
            paddingBottom: insets.bottom + 14,
            backgroundColor: dark ? 'rgba(7,11,20,0.97)' : 'rgba(246,247,251,0.98)',
            borderTopColor: borderColor,
          },
        ]}
      >
        <View style={styles.footerHeader}>
          <View style={styles.footerCopy}>
            <Text style={[styles.footerLabel, { color: textSoft }]}>2. Continue securely</Text>
            <Text style={[styles.footerTitle, { color: textPrimary }]}>{selectedPlan.label} plan</Text>
            <Text style={[styles.footerMeta, { color: textMuted }]}>{selectedPlan.summary}</Text>
          </View>
          {selectedCycle === 'yearly' ? (
            <View style={[styles.footerSavePill, { backgroundColor: surface, borderColor }]}>
              <Text style={[styles.footerSaveText, { color: PRIDE_COLORS[0] }]}>Save ${YEARLY_SAVINGS}</Text>
            </View>
          ) : null}
        </View>

        <Pressable
          disabled={isPremiumUser}
          onPress={handlePurchasePress}
          style={({ pressed }) => [styles.primaryButtonWrap, { opacity: pressed || isPremiumUser ? 0.94 : 1 }]}
        >
          <View style={[styles.primaryButton, { backgroundColor: buttonBackground }]}> 
            <PrideStrip compact />
            <Text style={[styles.primaryButtonText, { color: buttonText }]}>{primaryCta}</Text>
            <Text style={[styles.primaryButtonSubtext, { color: dark ? '#475569' : 'rgba(255,255,255,0.82)' }]}> 
              {isPremiumUser ? 'You already have access' : `Checkout handled by ${storeLabel}`}
            </Text>
          </View>
        </Pressable>

        <View style={styles.footerBottomRow}>
          <Pressable onPress={handleRestorePress} style={styles.restoreButton}>
            <Text style={[styles.restoreButtonText, { color: textPrimary }]}>Restore purchases</Text>
          </Pressable>
          <Text style={[styles.footerFootnote, { color: textSoft }]}>No hidden fees</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: 20,
    gap: 18,
  },
  prideStrip: {
    flexDirection: 'row',
    height: 6,
    overflow: 'hidden',
  },
  prideStripCompact: {
    height: 4,
    borderRadius: 999,
  },
  prideSegment: {
    flex: 1,
  },
  heroCard: {
    borderWidth: 1,
    borderRadius: 28,
    overflow: 'hidden',
  },
  heroBody: {
    paddingHorizontal: 20,
    paddingVertical: 20,
    gap: 14,
  },
  heroBadge: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 999,
    borderWidth: 1,
  },
  heroBadgeText: {
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 0.7,
  },
  heroTitle: {
    fontSize: 30,
    lineHeight: 36,
    fontWeight: '900',
    letterSpacing: -0.8,
  },
  heroSubtitle: {
    fontSize: 15,
    lineHeight: 23,
    fontWeight: '500',
  },
  stepList: {
    gap: 10,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  stepNumber: {
    width: 30,
    height: 30,
    borderRadius: 15,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepNumberText: {
    fontSize: 14,
    fontWeight: '800',
  },
  stepText: {
    flex: 1,
    fontSize: 15,
    fontWeight: '700',
    lineHeight: 20,
  },
  heroMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
    flexWrap: 'wrap',
  },
  metaPill: {
    paddingHorizontal: 12,
    paddingVertical: 9,
    borderRadius: 999,
    borderWidth: 1,
  },
  metaPillText: {
    fontSize: 13,
    fontWeight: '800',
  },
  metaHint: {
    fontSize: 13,
    fontWeight: '600',
  },
  statusCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderRadius: 20,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  statusContent: {
    flex: 1,
    gap: 4,
  },
  statusTitle: {
    fontSize: 15,
    fontWeight: '800',
  },
  statusText: {
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '500',
    textTransform: 'capitalize',
  },
  sectionHeader: {
    gap: 6,
    marginTop: 2,
  },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
  },
  sectionTitle: {
    fontSize: 24,
    lineHeight: 30,
    fontWeight: '900',
    letterSpacing: -0.7,
  },
  planList: {
    gap: 12,
  },
  planCard: {
    borderRadius: 24,
    borderWidth: 1.5,
    overflow: 'hidden',
  },
  planCardBody: {
    paddingHorizontal: 18,
    paddingVertical: 18,
    gap: 12,
  },
  planHeaderRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: 12,
  },
  planHeaderCopy: {
    flex: 1,
    gap: 6,
  },
  planTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 8,
  },
  planTitle: {
    fontSize: 18,
    fontWeight: '900',
    letterSpacing: -0.4,
  },
  planBadge: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 999,
    borderWidth: 1,
  },
  planBadgeText: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.3,
    textTransform: 'uppercase',
  },
  planSummary: {
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
  },
  planIndicator: {
    width: 26,
    height: 26,
    borderRadius: 13,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  planPriceRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 6,
  },
  planPrice: {
    fontSize: 34,
    lineHeight: 38,
    fontWeight: '900',
    letterSpacing: -1,
  },
  planPeriod: {
    fontSize: 15,
    fontWeight: '700',
  },
  planNote: {
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '700',
  },
  benefitsCard: {
    borderRadius: 24,
    borderWidth: 1,
    overflow: 'hidden',
  },
  benefitRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 14,
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  benefitIconWrap: {
    width: 40,
    height: 40,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  benefitCopy: {
    flex: 1,
    gap: 4,
  },
  benefitTitle: {
    fontSize: 15,
    fontWeight: '800',
    letterSpacing: -0.2,
  },
  benefitDescription: {
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '500',
  },
  noticeCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 14,
    borderRadius: 18,
    borderWidth: 1,
  },
  noticeText: {
    flex: 1,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
  },
  footer: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    paddingHorizontal: 20,
    paddingTop: 14,
    gap: 12,
    borderTopWidth: 1,
  },
  footerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  footerCopy: {
    flex: 1,
    gap: 2,
  },
  footerLabel: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
  },
  footerTitle: {
    fontSize: 18,
    fontWeight: '900',
    letterSpacing: -0.3,
  },
  footerMeta: {
    fontSize: 13,
    fontWeight: '500',
  },
  footerSavePill: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 999,
    borderWidth: 1,
  },
  footerSaveText: {
    fontSize: 12,
    fontWeight: '800',
  },
  primaryButtonWrap: {
    borderRadius: 22,
  },
  primaryButton: {
    borderRadius: 22,
    paddingHorizontal: 18,
    paddingVertical: 14,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.16,
    shadowRadius: 18,
    elevation: 5,
  },
  primaryButtonText: {
    fontSize: 16,
    fontWeight: '900',
    letterSpacing: -0.2,
  },
  primaryButtonSubtext: {
    fontSize: 12,
    fontWeight: '700',
  },
  footerBottomRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  restoreButton: {
    paddingVertical: 4,
  },
  restoreButtonText: {
    fontSize: 14,
    fontWeight: '700',
  },
  footerFootnote: {
    flex: 1,
    textAlign: 'right',
    fontSize: 12,
    fontWeight: '500',
  },
});
