import React, { useMemo } from 'react';
import {
  FlatList,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';

import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { clearFinishedPostTasks } from '@/store/slice/postUploads';

function formatTaskTime(value: number): string {
  if (!value) return '';
  const date = new Date(value);
  return date.toLocaleString();
}

export default function PendingTasksScreen() {
  const { colors, dark } = useTheme();
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
    () => sortedTasks.filter((task) => task.status !== 'uploading'),
    [sortedTasks]
  );

  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(15,23,42,0.08)';
  const cardBackground = dark ? 'rgba(255,255,255,0.04)' : '#FFFFFF';
  const mutedText = dark ? 'rgba(255,255,255,0.58)' : 'rgba(15,23,42,0.58)';

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <FlatList
        data={sortedTasks}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={false}
        ListHeaderComponent={
          <View style={styles.headerBlock}>
            <View style={[styles.summaryCard, { backgroundColor: cardBackground, borderColor }]}>
              <View style={styles.summaryRow}>
                <View>
                  <Text style={[styles.summaryTitle, { color: colors.text }]}>Background tasks</Text>
                  <Text style={[styles.summarySubtitle, { color: mutedText }]}>
                    Uploads continue while the user keeps using the app.
                  </Text>
                </View>
                <View style={[styles.summaryBadge, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : '#F1F5F9' }]}>
                  <Text style={[styles.summaryBadgeText, { color: colors.text }]}>
                    {activeTasks.length} active
                  </Text>
                </View>
              </View>

              <View style={styles.summaryFooter}>
                <Text style={[styles.summaryMeta, { color: mutedText }]}>
                  {completedTasks.length} completed or failed
                </Text>
                {completedTasks.length > 0 ? (
                  <TouchableOpacity
                    activeOpacity={0.82}
                    onPress={() => dispatch(clearFinishedPostTasks())}
                    style={[styles.clearButton, { borderColor }]}
                  >
                    <Text style={[styles.clearButtonText, { color: colors.text }]}>Clear finished</Text>
                  </TouchableOpacity>
                ) : null}
              </View>
            </View>
          </View>
        }
        ListEmptyComponent={
          <View style={[styles.emptyCard, { backgroundColor: cardBackground, borderColor }]}>
            <MaterialCommunityIcons name="clipboard-text-clock-outline" size={24} color={colors.text} />
            <Text style={[styles.emptyTitle, { color: colors.text }]}>No pending tasks</Text>
            <Text style={[styles.emptyText, { color: mutedText }]}>
              Background uploads will appear here.
            </Text>
          </View>
        }
        renderItem={({ item }) => {
          const isUploading = item.status === 'uploading';
          const isError = item.status === 'error';
          const iconName = isUploading
            ? 'cloud-upload-outline'
            : isError
              ? 'alert-circle-outline'
              : 'check-circle-outline';
          const iconColor = isUploading ? colors.text : isError ? '#B91C1C' : '#15803D';
          const statusLabel = isUploading ? 'Uploading' : isError ? 'Failed' : 'Completed';

          return (
            <View style={[styles.taskCard, { backgroundColor: cardBackground, borderColor }]}>
              <View style={styles.taskTopRow}>
                <View style={[styles.taskIconWrap, { backgroundColor: dark ? 'rgba(255,255,255,0.08)' : '#F8FAFC' }]}>
                  <MaterialCommunityIcons name={iconName} size={20} color={iconColor} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={[styles.taskTitle, { color: colors.text }]} numberOfLines={1}>
                    {item.title}
                  </Text>
                  <Text style={[styles.taskStatus, { color: mutedText }]}>
                    {statusLabel}
                  </Text>
                </View>
              </View>

              {!!item.description && (
                <Text style={[styles.taskDescription, { color: colors.text }]}>{item.description}</Text>
              )}

              {!!item.message && (
                <Text style={[styles.taskMessage, { color: mutedText }]}>{item.message}</Text>
              )}

              <Text style={[styles.taskTime, { color: mutedText }]}>
                Updated {formatTaskTime(item.updatedAt)}
              </Text>
            </View>
          );
        }}
        ItemSeparatorComponent={() => <View style={{ height: 14 }} />}
      />
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
    paddingBottom: 32,
  },
  headerBlock: {
    marginBottom: 16,
  },
  summaryCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 18,
    gap: 16,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  summaryTitle: {
    fontSize: 24,
    fontFamily: 'Outfit-Bold',
    letterSpacing: -0.5,
  },
  summarySubtitle: {
    marginTop: 6,
    fontSize: 13,
    lineHeight: 19,
    fontFamily: 'Inter-Regular',
  },
  summaryBadge: {
    minWidth: 84,
    height: 38,
    borderRadius: 19,
    paddingHorizontal: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  summaryBadgeText: {
    fontSize: 12,
    fontFamily: 'Inter-Bold',
  },
  summaryFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  summaryMeta: {
    flex: 1,
    fontSize: 13,
    fontFamily: 'Inter-Medium',
  },
  clearButton: {
    minHeight: 40,
    paddingHorizontal: 14,
    borderRadius: 14,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  clearButtonText: {
    fontSize: 13,
    fontFamily: 'Inter-Bold',
  },
  emptyCard: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 24,
    alignItems: 'center',
    gap: 10,
  },
  emptyTitle: {
    fontSize: 18,
    fontFamily: 'Outfit-Bold',
  },
  emptyText: {
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
    fontFamily: 'Inter-Regular',
  },
  taskCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 16,
    gap: 12,
  },
  taskTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  taskIconWrap: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  taskTitle: {
    fontSize: 15,
    fontFamily: 'Inter-Bold',
  },
  taskStatus: {
    marginTop: 3,
    fontSize: 12,
    fontFamily: 'Inter-Bold',
    textTransform: 'uppercase',
    letterSpacing: 0.7,
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
  taskTime: {
    fontSize: 12,
    fontFamily: 'Inter-Medium',
  },
});
