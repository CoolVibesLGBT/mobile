import { StyleSheet, View, ScrollView, ImageBackground, TouchableOpacity, Linking, Platform, Text, StatusBar } from 'react-native';
import { useRoute, useNavigation, useTheme } from '@react-navigation/native';
import { LocalizedStringToString } from '@/utils/utils';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function PlaceDetail() {
  const route = useRoute();
  const navigation = useNavigation();
  const { colors, dark } = useTheme();
  const { item } = route.params as { item: any };

  const title = LocalizedStringToString(item.title);

  const handleGetDirections = () => {
    const { address, town, country } = item.extras.place;
    const fullAddress = `${address}, ${town}, ${country}`;
    const scheme = Platform.OS === 'ios' ? 'maps:0,0?q=' : 'geo:0,0?q=';
    const url = scheme + encodeURIComponent(fullAddress);
    Linking.openURL(url);
  };

  const ActionButton = ({ icon, label, count }: { icon: any, label: string, count?: number }) => (
    <TouchableOpacity style={styles.actionButton}>
      <MaterialCommunityIcons name={icon} size={24} color={dark ? '#CCC' : '#475569'} />
      <Text style={[styles.actionButtonLabel, { color: dark ? '#CCC' : '#475569' }]}>{label}</Text>
      {count && <Text style={[styles.actionButtonCount, { color: colors.text }]}>{count}</Text>}
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: colors.background }]} edges={['bottom', 'left', 'right']}>
      <StatusBar barStyle="light-content" />
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        <ImageBackground source={{ uri: item.image }} style={styles.headerImage}>
          <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
            <MaterialCommunityIcons name="arrow-left" size={24} color="white" />
          </TouchableOpacity>
        </ImageBackground>

        <View style={[styles.contentSheet, { backgroundColor: colors.background }]}>
          <View style={styles.titleSection}>
            {item.extras.place.tag && (
              <View style={[styles.tag, { backgroundColor: dark ? '#222' : '#F1F1F1' }]}>
                <Text style={[styles.tagText, { color: colors.text }]}>{item.extras.place.tag}</Text>
              </View>
            )}
            <Text style={[styles.title, { color: colors.text }]}>{title}</Text>
          </View>

          <View style={[styles.card, { backgroundColor: dark ? '#1C1C1E' : '#FFFFFF', borderColor: dark ? '#333' : '#E2E8F0' }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>Location Details</Text>
            <View style={styles.infoRow}>
              <MaterialCommunityIcons name="map-marker-outline" size={22} color={dark ? '#AAA' : "#64748B"} style={styles.infoIcon} />
              <Text style={[styles.infoText, { color: dark ? '#CCC' : '#475569' }]}>{item.extras.place.address}, {item.extras.place.town}, {item.extras.place.country}</Text>
            </View>
            <TouchableOpacity style={[styles.directionsButton, { backgroundColor: colors.text }]} onPress={handleGetDirections}>
              <Text style={[styles.directionsButtonText, { color: colors.background }]}>Get Directions</Text>
              <MaterialCommunityIcons name="arrow-right" size={20} color={colors.background} />
            </TouchableOpacity>
          </View>

          {item.note && (
            <View style={[styles.card, { backgroundColor: dark ? '#1C1C1E' : '#FFFFFF', borderColor: dark ? '#333' : '#E2E8F0' }]}>
              <Text style={[styles.cardTitle, { color: colors.text }]}>Notes</Text>
              <Text style={[styles.noteText, { color: dark ? '#CCC' : '#475569' }]}>{item.note}</Text>
            </View>
          )}

          <View style={[styles.card, { backgroundColor: dark ? '#1C1C1E' : '#FFFFFF', borderColor: dark ? '#333' : '#E2E8F0' }]}>
            <Text style={[styles.cardTitle, { color: colors.text }]}>Engagement</Text>
            <View style={styles.actionsContainer}>
              <ActionButton icon="heart-outline" label="Likes" count={123} />
              <ActionButton icon="comment-text-outline" label="Comments" count={45} />
              <ActionButton icon="share-variant-outline" label="Share" />
            </View>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  scrollContainer: {
    paddingBottom: 40,
  },
  headerImage: {
    width: '100%',
    height: 320,
    backgroundColor: '#E2E8F0',
    justifyContent: 'flex-end',
  },
  backButton: {
    position: 'absolute',
    top: 50, // Adjust for status bar
    left: 16,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    borderRadius: 20,
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  contentSheet: {
    backgroundColor: '#F8FAFC',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    marginTop: -24,
    paddingTop: 24,
    paddingHorizontal: 16,
    gap: 16,
  },
  titleSection: {
    marginBottom: 0,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1E293B',
  },
  tag: {
    backgroundColor: '#E0E7FF',
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 16,
    marginBottom: 8,
  },
  tagText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#4338CA',
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#334155',
    marginBottom: 12,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 16,
  },
  infoIcon: {
    marginRight: 12,
    marginTop: 2,
  },
  infoText: {
    fontSize: 16,
    color: '#475569',
    lineHeight: 24,
    flex: 1,
  },
  directionsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#3B82F6',
    borderRadius: 12,
    paddingVertical: 14,
    gap: 8,
  },
  directionsButtonText: {
    color: 'white',
    fontWeight: '600',
    fontSize: 16,
  },
  noteText: {
    fontSize: 16,
    lineHeight: 24,
    color: '#475569',
  },
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingTop: 8,
  },
  actionButton: {
    alignItems: 'center',
    gap: 8,
  },
  actionButtonLabel: {
    fontSize: 14,
    color: '#475569',
    fontWeight: '500',
  },
  actionButtonCount: {
    fontSize: 16,
    color: '#1E293B',
    fontWeight: '600',
  },
});
