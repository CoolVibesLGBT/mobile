import React, { useMemo } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { LinearGradient } from 'expo-linear-gradient';

import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { BackgroundTask, clearFinishedPostTasks } from '@/store/slice/postUploads';

function formatTaskTime(value: number): string {
  if (!value) return '';

  const now = Date.now();
  const diffMs = Math.max(0, now - value);
  const diffMinutes = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMinutes < 1) return 'Updated just now';
  if (diffMinutes < 60) return `Updated ${diffMinutes}m ago`;
  if (diffHours < 24) return `Updated ${diffHours}h ago`;
  if (diffDays < 7) return `Updated ${diffDays}d ago`;

  const date = new Date(value);
  return `Updated ${date.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
  })}`;
}

function getTaskKindLabel(kind: BackgroundTask['kind']): string {
  if (kind === 'classified.create') return 'Classified';
  return 'Post';
}

function getStatusMeta(status: BackgroundTask['status']) {
  if (status === 'uploading') {
    return {
      label: 'In progress',
      icon: 'progress-upload',
      accent: '#7C3AED',
      background: 'rgba(124,58,237,0.10)',
    };
  }

  if (status === 'error') {
    return {
      label: 'Needs attention',
      icon: 'alert-circle-outline',
      accent: '#DC2626',
      background: 'rgba(220,38,38,0.10)',
    };
  }

  return {
    label: 'Completed',
    icon: 'check-circle-outline',
    accent: '#059669',
    background: 'rgba(5,150,105,0.10)',
  };
}

function TaskCard({
  task,
  dark,
  textColor,
  mutedText,
  borderColor,
  surface,
  secondarySurface,
}: {
  task: BackgroundTask;
  dark: boolean;
  textColor: string;
  mutedText: string;
  borderColor: string;
  surface: string;
  secondarySurface: string;
}) {
  const statusMeta = getStatusMeta(task.status);

  return (
    <View
      style={[
        styles.taskCard,
        {
          backgroundColor: surface,
          borderColor,
        },
      ]}
    >
      <View style={styles.taskHeader}>
        <View
          style={[
            styles.taskIconWrap,
            {
              backgroundColor: dark ? 'rgba(255,255,255,0.06)' : secondarySurface,
            },
          ]}
        >
          <MaterialCommunityIcons
            name={statusMeta.icon as any}
            size={20}
            color={statusMeta.accent}
          />
        </View>

        <View style={styles.taskBody}>
          <View style={styles.taskTitleRow}>
            <Text style={[styles.taskTitle, { color: textColor }]} numberOfLines={2}>
              {task.title}
            </Text>

            <View
              style={[
                styles.statusPill,
                {
                  backgroundColor: statusMeta.background,
                  borderColor: dark ? 'rgba(255,255,255,0.05)' : 'rgba(15,23,42,0.06)',
                },
              ]}
            >
              <Text style={[styles.statusPillText, { color: statusMeta.accent }]}>
                {statusMeta.label}
              </Text>
            </View>
          </View>

          {!!task.description ? (
            <Text style={[styles.taskDescription, { color: textColor }]}>
              {task.description}
            </Text>
          ) : null}

          {!!task.message ? (
            <Text style={[styles.taskMessage, { color: mutedText }]}>
              {task.message}
            </Text>
          ) : null}

          <View style={styles.taskMetaRow}>
            <View
              style={[
                styles.kindPill,
                {
                  backgroundColor: dark ? 'rgba(255,255,255,0.05)' : secondarySurface,
                  borderColor,
                },
              ]}
            >
              <Text style={[styles.kindPillText, { color: textColor }]}>
                {getTaskKindLabel(task.kind)}
              </Text>
            </View>

            <Text style={[styles.taskTime, { color: mutedText }]}>
              {formatTaskTime(task.updatedAt)}
            </Text>
          </View>
        </View>
      </View>
    </View>
  );
}

function Section({
  title,
  subtitle,
  children,
  textColor,
  mutedText,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
  textColor: string;
  mutedText: string;
}) {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Text style={[styles.sectionTitle, { color: textColor }]}>{title}</Text>
        <Text style={[styles.sectionSubtitle, { color: mutedText }]}>{subtitle}</Text>
      </View>
      <View style={styles.sectionContent}>{children}</View>
    </View>
  );
}

export default function PendingTasksScreen() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const dispatch = useAppDispatch();
  const tasks = useAppSelector((state) => state.postUploads.tasks);

  const sortedTasks = useMemo(
    () => [...tasks].sort((a, b) => b.updatedAt - a.updatedAt),
    [tasks]
  );

  const activeTasks = useMemo(
    () => sortedTasks.filter((task) => task.status === 'uploading'),
    [sortedTasks]
  );

  const completedTasks = useMemo(
    () => sortedTasks.filter((task) => task.status === 'success'),
    [sortedTasks]
  );

  const failedTasks = useMemo(
    () => sortedTasks.filter((task) => task.status === 'error'),
    [sortedTasks]
  );

  const archivedTasks = useMemo(
    () => sortedTasks.filter((task) => task.status !== 'uploading'),
    [sortedTasks]
  );

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const cardBackground = dark ? '#0E1628' : '#FFFFFF';
  const secondarySurface = dark ? 'rgba(255,255,255,0.06)' : '#F8FAFC';
  const mutedText = dark ? 'rgba(255,255,255,0.64)' : '#64748B';
  const heroGradient = dark
    ? ['#090B14', '#111827', '#172554']
    : ['#0F172A', '#1E293B', '#334155'];

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <ScrollView
        contentContainerStyle={[
          styles.contentContainer,
          { paddingBottom: insets.bottom + 32 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        <LinearGradient
          colors={heroGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.heroCard}
        >
          <View style={styles.heroTopRow}>
            <View style={styles.heroTitleWrap}>
              <Text style={styles.heroEyebrow}>TASK CENTER</Text>
              <Text style={styles.heroTitle}>Background tasks</Text>
              <Text style={styles.heroSubtitle}>
                Uploads and queued actions stay here while the user keeps using the app.
              </Text>
            </View>

            {archivedTasks.length > 0 ? (
              <Pressable
                onPress={() => dispatch(clearFinishedPostTasks())}
                style={({ pressed }) => [
                  styles.clearButton,
                  {
                    opacity: pressed ? 0.92 : 1,
                  },
                ]}
              >
                <Text style={styles.clearButtonText}>Clear finished</Text>
              </Pressable>
            ) : null}
          </View>

          <View style={styles.statsGrid}>
            <View style={styles.statCard}>
              <Text
                style={styles.statValue}
                numberOfLines={1}
                adjustsFontSizeToFit
                minimumFontScale={0.7}
              >
                {activeTasks.length}
              </Text>
              <Text style={styles.statLabel}>Active</Text>
            </View>

            <View style={styles.statCard}>
              <Text
                style={styles.statValue}
                numberOfLines={1}
                adjustsFontSizeToFit
                minimumFontScale={0.7}
              >
                {completedTasks.length}
              </Text>
              <Text style={styles.statLabel}>Completed</Text>
            </View>

            <View style={styles.statCard}>
              <Text
                style={styles.statValue}
                numberOfLines={1}
                adjustsFontSizeToFit
                minimumFontScale={0.7}
              >
                {failedTasks.length}
              </Text>
              <Text style={styles.statLabel}>Failed</Text>
            </View>
          </View>
        </LinearGradient>

        {sortedTasks.length === 0 ? (
          <View
            style={[
              styles.emptyCard,
              {
                backgroundColor: cardBackground,
                borderColor,
              },
            ]}
          >
            <View
              style={[
                styles.emptyIconWrap,
                { backgroundColor: secondarySurface },
              ]}
            >
              <MaterialCommunityIcons
                name="clipboard-text-clock-outline"
                size={24}
                color={colors.text}
              />
            </View>
            <Text style={[styles.emptyTitle, { color: colors.text }]}>No active background work</Text>
            <Text style={[styles.emptyText, { color: mutedText }]}>
              New uploads and queued tasks will appear here automatically.
            </Text>
          </View>
        ) : (
          <>
            {activeTasks.length > 0 ? (
              <Section
                title="Running now"
                subtitle="These tasks are still working in the background."
                textColor={colors.text}
                mutedText={mutedText}
              >
                {activeTasks.map((task) => (
                  <TaskCard
                    key={task.id}
                    task={task}
                    dark={dark}
                    textColor={colors.text}
                    mutedText={mutedText}
                    borderColor={borderColor}
                    surface={cardBackground}
                    secondarySurface={secondarySurface}
                  />
                ))}
              </Section>
            ) : null}

            {archivedTasks.length > 0 ? (
              <Section
                title="Recent results"
                subtitle="Completed and failed tasks stay here until they are cleared."
                textColor={colors.text}
                mutedText={mutedText}
              >
                {archivedTasks.map((task) => (
                  <TaskCard
                    key={task.id}
                    task={task}
                    dark={dark}
                    textColor={colors.text}
                    mutedText={mutedText}
                    borderColor={borderColor}
                    surface={cardBackground}
                    secondarySurface={secondarySurface}
                  />
                ))}
              </Section>
            ) : null}
          </>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    paddingHorizontal: 20,
    paddingTop: 24,
    gap: 20,
  },
  heroCard: {
    borderRadius: 28,
    padding: 20,
    gap: 18,
    overflow: 'hidden',
  },
  heroTopRow: {
    gap: 16,
  },
  heroTitleWrap: {
    gap: 6,
  },
  heroEyebrow: {
    color: 'rgba(255,255,255,0.62)',
    fontSize: 12,
    fontFamily: 'Inter-Bold',
    letterSpacing: 1,
  },
  heroTitle: {
    color: '#FFFFFF',
    fontSize: 28,
    lineHeight: 32,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.7,
  },
  heroSubtitle: {
    color: 'rgba(255,255,255,0.76)',
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-Medium',
    maxWidth: '92%',
  },
  clearButton: {
    alignSelf: 'flex-start',
    minHeight: 40,
    paddingHorizontal: 14,
    borderRadius: 14,
    backgroundColor: 'rgba(255,255,255,0.10)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    justifyContent: 'center',
  },
  clearButtonText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  statsGrid: {
    flexDirection: 'row',
    gap: 10,
  },
  statCard: {
    flex: 1,
    minWidth: 0,
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 14,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.10)',
    alignItems: 'center',
  },
  statValue: {
    color: '#FFFFFF',
    fontSize: 28,
    lineHeight: 32,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.6,
    width: '100%',
    textAlign: 'center',
  },
  statLabel: {
    marginTop: 4,
    color: 'rgba(255,255,255,0.72)',
    fontSize: 12,
    fontFamily: 'Inter-Bold',
    textAlign: 'center',
  },
  emptyCard: {
    borderWidth: 1,
    borderRadius: 24,
    paddingHorizontal: 22,
    paddingVertical: 28,
    alignItems: 'center',
    gap: 12,
  },
  emptyIconWrap: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTitle: {
    fontSize: 18,
    lineHeight: 22,
    fontFamily: 'Outfit-Bold',
    textAlign: 'center',
  },
  emptyText: {
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
    fontFamily: 'Inter-Regular',
    maxWidth: 300,
  },
  section: {
    gap: 12,
  },
  sectionHeader: {
    gap: 4,
  },
  sectionTitle: {
    fontSize: 18,
    lineHeight: 22,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.3,
  },
  sectionSubtitle: {
    fontSize: 13,
    lineHeight: 18,
    fontFamily: 'Inter-Medium',
  },
  sectionContent: {
    gap: 12,
  },
  taskCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 16,
  },
  taskHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
  },
  taskIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  taskBody: {
    flex: 1,
    minWidth: 0,
    gap: 10,
  },
  taskTitleRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  taskTitle: {
    flex: 1,
    minWidth: 0,
    fontSize: 15,
    lineHeight: 20,
    fontFamily: 'Inter-Bold',
  },
  statusPill: {
    maxWidth: '44%',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statusPillText: {
    fontSize: 11,
    lineHeight: 13,
    fontFamily: 'Inter-Bold',
    textAlign: 'center',
  },
  taskDescription: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'Inter-SemiBold',
  },
  taskMessage: {
    fontSize: 13,
    lineHeight: 19,
    fontFamily: 'Inter-Regular',
  },
  taskMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 10,
    flexWrap: 'wrap',
  },
  kindPill: {
    minHeight: 32,
    paddingHorizontal: 10,
    borderRadius: 999,
    borderWidth: 1,
    justifyContent: 'center',
  },
  kindPillText: {
    fontSize: 12,
    fontFamily: 'Inter-Bold',
  },
  taskTime: {
    flexShrink: 1,
    fontSize: 12,
    lineHeight: 16,
    fontFamily: 'Inter-Medium',
  },
});
