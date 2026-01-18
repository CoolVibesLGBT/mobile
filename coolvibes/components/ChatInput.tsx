import React, { useState, useEffect, useRef, useCallback } from "react";
import { Modal, Pressable } from "react-native";
import * as Haptics from "expo-haptics";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  FlatList,
  Image,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  ActivityIndicator,
  Keyboard,
  Animated,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Entypo from "@expo/vector-icons/Entypo";
import Ionicons from "@expo/vector-icons/Ionicons";
import MaterialCommunityIcons from "@expo/vector-icons/MaterialCommunityIcons";
import * as ImagePicker from "expo-image-picker";
import * as DocumentPicker from 'expo-document-picker';
import {
  useAudioRecorder,
  useAudioPlayer,
  AudioModule,
  RecordingPresets,
  setAudioModeAsync,
} from 'expo-audio';
import { useVideoPlayer, VideoView } from 'expo-video';
import * as Location from "expo-location";
import MapView, { Marker, PROVIDER_GOOGLE } from "react-native-maps";
import BottomSheet, {
  BottomSheetModal,
  BottomSheetModalProvider,
  BottomSheetFlatList,
  BottomSheetView,
} from "@gorhom/bottom-sheet";
import { GOOGLE_PLACES_KEY } from "@/config";

// --- Types & Interfaces ---
interface Media {
  uri?: string;
  type: "image" | "video" | "document" | "audio" | "location" | "live_location";
  name?: string;
  data?: any;
}

interface Message {
  id: string;
  text: string;
  sender: "me" | "them";
  timestamp: string;
  status?: "sent" | "delivered" | "read";
  replyTo?: {
    user: string;
    text: string;
    type: "story" | "text";
  };
}

interface User {
  id: string;
  name: string;
}

interface ChatInputProps {
  currentUser: any;
  replyingTo: Message | null;
  editingMessage: Message | null;
  onCancelReply: () => void;
  onCancelEdit: () => void;
  onSendMessage: (text: string, media: Media[], replyToId?: string, editingId?: string) => void;
}

const VideoPreview = ({ uri }: { uri: string }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const player = useVideoPlayer(uri, (player) => {
    player.loop = true;
    player.muted = true;
  });

  return (
    <Pressable
      style={styles.mediaPreview}
      onPress={() => {
        if (isPlaying) {
          player.pause();
        } else {
          player.play();
        }
        setIsPlaying(!isPlaying);
      }}
    >
      <VideoView
        style={{ flex: 1, borderRadius: 8 }}
        player={player}
        contentFit="cover"
        nativeControls={false}
      />
      {!isPlaying && (
        <View style={styles.videoOverlay}>
          <Ionicons name="play" size={30} color="white" />
        </View>
      )}
    </Pressable>
  );
};

const AudioPreview = ({ item }: { item: any }) => {
  const player = useAudioPlayer(item.uri);
  const [isPlaying, setIsPlaying] = useState(false);

  useEffect(() => {
    const subscription = player.addListener('playbackStatusUpdate', (status) => {
      if (status.didJustFinish) {
        setIsPlaying(false);
        player.seekTo(0);
      }
    });
    return () => subscription.remove();
  }, [player]);

  return (
    <View
      style={[
        styles.mediaPreview,
        {
          backgroundColor: "#FFF4E5",
          alignItems: "center",
          justifyContent: "center",
        },
      ]}
    >
      <TouchableOpacity onPress={() => {
        if (isPlaying) {
          player.pause();
        } else {
          player.play();
        }
        setIsPlaying(!isPlaying);
      }}>
        <MaterialCommunityIcons
          name={isPlaying ? "pause-circle" : "play-circle"}
          size={32}
          color="#FF9500"
        />
      </TouchableOpacity>
      {item.name && (
        <Text
          numberOfLines={1}
          style={{ fontSize: 10, maxWidth: 70, marginTop: 4, color: "#333" }}
        >
          {item.name}
        </Text>
      )}
    </View>
  );
};

export default function ChatInput({
  currentUser,
  replyingTo,
  editingMessage,
  onCancelReply,
  onCancelEdit,
  onSendMessage,
}: ChatInputProps) {
  const insets = useSafeAreaInsets();
  const [inputText, setInputText] = useState("");
  const [inputHeight, setInputHeight] = useState(40);
  const [selectedMedia, setSelectedMedia] = useState<Media[]>([]);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [activePickerTab, setActivePickerTab] = useState<'emoji' | 'gif' | 'sticker'>('emoji');

  const [isRecording, setIsRecording] = useState(false);
  const [recordingDuration, setRecordingDuration] = useState(0);
  const recordingTimerRef = useRef<NodeJS.Timeout | null>(null);
  const recordingOpacity = useRef(new Animated.Value(1)).current;
  const audioRecorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);

  const [showLocationPicker, setShowLocationPicker] = useState(false);
  const [currentLocation, setCurrentLocation] = useState<any>(null);
  const [selectedLocationMap, setSelectedLocationMap] = useState<any>(null);
  const [places, setPlaces] = useState<any[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [isSearching, setIsSearching] = useState(false);
  const [nextPageToken, setNextPageToken] = useState<string | null>(null);
  const [isLoadingPlaces, setIsLoadingPlaces] = useState(false);

  const inputRef = useRef<TextInput>(null);
  const bottomSheetModalRef = useRef<BottomSheetModal>(null);
  const bottomSheetFlatListRef = useRef<any>(null);

  useEffect(() => {
    const showSubscription = Keyboard.addListener("keyboardDidShow", () => {
      setShowEmojiPicker(false);
    });
    return () => showSubscription.remove();
  }, []);

  useEffect(() => {
    if (editingMessage) {
      setInputText(editingMessage.text);
      inputRef.current?.focus();
    }
  }, [editingMessage]);

  useEffect(() => {
    if (replyingTo) {
      inputRef.current?.focus();
    }
  }, [replyingTo]);

  useEffect(() => {
    if (isRecording) {
      Animated.loop(
        Animated.sequence([
          Animated.timing(recordingOpacity, { toValue: 0.2, duration: 500, useNativeDriver: true }),
          Animated.timing(recordingOpacity, { toValue: 1, duration: 500, useNativeDriver: true }),
        ])
      ).start();
    } else {
      recordingOpacity.stopAnimation();
      recordingOpacity.setValue(1);
    }
  }, [isRecording]);

  useEffect(() => {
    const getLocation = async () => {
      if (showLocationPicker) {
        let { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== "granted") {
          console.error("Permission to access location was denied");
          return;
        }

        try {
          let location = await Location.getCurrentPositionAsync({});
          setCurrentLocation(location.coords);
          fetchNearbyPlaces(
            location.coords.latitude,
            location.coords.longitude,
            searchQuery
          );
        } catch (error) {
          console.error("Failed to get location", error);
        }
      }
    };

    getLocation();
  }, [showLocationPicker]);

  useEffect(() => {
    if (!showLocationPicker) return;
    const timer = setTimeout(() => {
      const lat = selectedLocationMap?.latitude || currentLocation?.latitude;
      const lon = selectedLocationMap?.longitude || currentLocation?.longitude;
      if (lat && lon) {
        fetchNearbyPlaces(lat, lon, searchQuery, "");
      }
    }, 600);
    return () => clearTimeout(timer);
  }, [searchQuery, showLocationPicker, selectedLocationMap, currentLocation]);

  const fetchNearbyPlaces = async (lat: number, lon: number, query: string = "", pageToken: string = "") => {
    if (isLoadingPlaces && !pageToken) return;
    setIsLoadingPlaces(true);
    try {
      const API_KEY = GOOGLE_PLACES_KEY;
      let url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lon}&radius=2000&key=${API_KEY}`;

      if (query.trim()) {
        url += `&keyword=${encodeURIComponent(query)}`;
      } else {
        url += `&type=point_of_interest`;
      }

      if (pageToken) {
        url += `&pagetoken=${pageToken}`;
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }

      const response = await fetch(url);
      const data = await response.json();

      if (data.status === "OK" || data.status === "ZERO_RESULTS") {
        const newPlaces = (data.results || []).map((p: any) => ({
          name: p.name || "",
          address: p.vicinity || "",
          lat: p.geometry?.location?.lat,
          lng: p.geometry?.location?.lng,
        }));

        if (pageToken) {
          setPlaces((prev) => [...prev, ...newPlaces]);
        } else {
          setPlaces(newPlaces);
        }
        setNextPageToken(data.next_page_token || null);
      }
    } catch (e) {
      console.log("NearbySearch error", e);
    } finally {
      setIsLoadingPlaces(false);
    }
  };

  const stringToColor = (str: string) => {
    let hash = 0;

    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }

    let color = "#";

    for (let i = 0; i < 3; i++) {
      const value = (hash >> (i * 8)) & 0xff;
      color += ("00" + value.toString(16)).slice(-2);
    }

    return color;
  };

  const getPlaceIcon = (name: string) => {
    return {
      name: "map-marker",
      color: stringToColor(name),
    };
  };

  const handleSendMessagePress = () => {
    console.log("press1")
    if (!inputText.trim() && selectedMedia.length === 0) return;

    onSendMessage(inputText.trim(), selectedMedia, replyingTo?.id, editingMessage?.id);
    console.log("press2")

    setInputText("");
    setInputHeight(40);
    setSelectedMedia([]);
    onCancelReply();
    onCancelEdit();
  };

  const handlePresentModalPress = useCallback(() => {
    Keyboard.dismiss();
    bottomSheetModalRef.current?.present();
  }, []);

  // Media & File Picking Logic
  const openCamera = async () => {


    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchCameraAsync({
      quality: 1,
      allowsEditing: true,
      mediaTypes: ['images', 'videos'],
      allowsMultipleSelection: true
    });
    if (!result.canceled) {
      setSelectedMedia((prev) => [
        ...prev,
        {
          uri: result.assets[0].uri,
          type: result.assets[0].type === "video" ? "video" : "image",
        },
      ]);
      bottomSheetModalRef.current?.dismiss();
    }
  };

  const openDocuments = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        multiple: true,
        copyToCacheDirectory: true,
        type: "*/*",
      });
      if (result.canceled) return;
      const newDocs = result.assets.map((asset) => ({
        uri: asset.uri,
        type: "document" as const,
        name: asset.name,
      }));
      setSelectedMedia((prev) => [...prev, ...newDocs]);
      bottomSheetModalRef.current?.dismiss();
    } catch (e) {
      console.log("Document pick error:", e);
    }
  };

  const pickImage = async () => {
    const permissionResult = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permissionResult.granted) return;
    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images', 'videos'],
      allowsMultipleSelection: true,
      quality: 1,
    });
    if (!result.canceled) {
      const newItems = result.assets.map((a) => ({ uri: a.uri, type: "image" as const }));
      setSelectedMedia((prev) => [...prev, ...newItems]);
      bottomSheetModalRef.current?.dismiss();
    }
  };

  const pickVideo = async () => {
    const permissionResult = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permissionResult.granted) return;
    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['videos'],
      allowsMultipleSelection: true,
      quality: 1,
    });
    if (!result.canceled) {
      const newItems = result.assets.map((a) => ({ uri: a.uri, type: "video" as const }));
      setSelectedMedia((prev) => [...prev, ...newItems]);
      bottomSheetModalRef.current?.dismiss();
    }
  };

  // Audio Recording Logic
  const startRecording = async () => {
    try {
      const permission = await AudioModule.requestRecordingPermissionsAsync();
      if (permission.status === 'granted') {
        setAudioModeAsync({
          playsInSilentMode: true,
          allowsRecording: true,
        });
        setIsRecording(true);
        await audioRecorder.prepareToRecordAsync(RecordingPresets.HIGH_QUALITY);
        audioRecorder.record();

        setRecordingDuration(0);
        recordingTimerRef.current = setInterval(() => {
          setRecordingDuration((prev) => prev + 1);
        }, 1000);
      }
    } catch (e) {
      console.error("Failed to start recording", e);
    }
  };

  const stopRecording = async () => {
    if (recordingTimerRef.current) {
      clearInterval(recordingTimerRef.current);
      recordingTimerRef.current = null;
    }
    setIsRecording(false);
    try {
      await audioRecorder.stop();
      if (audioRecorder.uri) {
        setSelectedMedia((prev) => [
          ...prev,
          { type: "audio", name: `Ses Kaydı (${formatDuration(recordingDuration)})`, uri: audioRecorder.uri ?? "" },
        ]);
      }
    } catch (e) {
      console.error("Failed to stop recording", e);
    }
  };

  const cancelRecording = async () => {
    if (recordingTimerRef.current) {
      clearInterval(recordingTimerRef.current);
      recordingTimerRef.current = null;
    }
    setIsRecording(false);
    setRecordingDuration(0);
    try {
      if (audioRecorder.isRecording) {
        await audioRecorder.stop();
      }
    } catch (e) {
      console.error("Failed to cancel recording", e);
    }
  };

  const formatDuration = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s < 10 ? "0" : ""}${s}`;
  };

  const handleEmojiToggle = () => {
    if (showEmojiPicker) {
      inputRef.current?.focus();
    } else {
      Keyboard.dismiss();
    }
    setShowEmojiPicker(!showEmojiPicker);
  };

  const isMultiline =
    inputText.includes("\n") ||
    inputHeight > 45 ||
    replyingTo ||
    editingMessage ||
    (selectedMedia.length > 0 && !isRecording);

  return (

      <>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          keyboardVerticalOffset={Platform.OS === "ios" ? 0 : 0}
        >
          <View style={styles.footerContainer}>
            <View style={styles.inputRow}>
              <TouchableOpacity
                onPress={isRecording ? cancelRecording : handlePresentModalPress}
                style={styles.externalButton}
              >
                {isRecording ? (
                  <MaterialCommunityIcons name="trash-can-outline" size={24} color="#FF3B30" />
                ) : (
                  <Entypo name="attachment" size={24} color="black" />
                )}
              </TouchableOpacity>

              <View style={[styles.inputPillContainer, isMultiline ? styles.pillMultiline : styles.pillSingleLine]}>
                {isRecording ? (
                  <View style={styles.recordingContainer}>
                    <Animated.View style={[styles.recordingIndicator, { opacity: recordingOpacity }]} />
                    <Text style={styles.recordingText}>
                      Kaydediliyor... {formatDuration(recordingDuration)}
                    </Text>
                  </View>
                ) : (
                  <>
                    {(replyingTo || editingMessage) && (
                      <View style={[styles.previewBar, editingMessage ? styles.previewEdit : styles.previewReply]}>
                        <View style={styles.previewContent}>
                          <Text style={styles.previewLabel}>
                            {editingMessage ? "Mesajı Düzenle" : `${replyingTo?.sender === "me" ? "Sen" : currentUser.name} yanıtlanıyor`}
                          </Text>
                          <Text style={styles.previewText} numberOfLines={1}>
                            {editingMessage?.text || replyingTo?.text}
                          </Text>
                        </View>
                        <TouchableOpacity onPress={editingMessage ? onCancelEdit : onCancelReply}>
                          <Entypo name="cross" size={24} color="black" />
                        </TouchableOpacity>
                      </View>
                    )}

                    {selectedMedia.length > 0 && (
                      <ScrollView horizontal style={styles.mediaPreviewContainer} showsHorizontalScrollIndicator={false}>
                        {selectedMedia.map((media, index) => (
                          <View key={index} style={{ marginRight: 8 }}>
                            {media.type === "image" ? (
                              <Image source={{ uri: media.uri }} style={styles.mediaPreview} />
                            ) : media.type === "video" && media.uri ? (
                              <VideoPreview uri={media.uri} />
                            ) : media.type === "audio" ? (
                              <AudioPreview item={media} />
                            ) : (
                              <View style={[styles.mediaPreview, { backgroundColor: media.type === "document" ? "#E3F2FD" : media.type === "live_location" ? "#FFEDF3" : media.type === "location" ? "#E8FBF0" : "#f0f0f0", alignItems: "center", justifyContent: "center" }]}>
                                <MaterialCommunityIcons name={media.type === "location" || media.type === "live_location" ? "map-marker" : "file-document"} size={24} color={media.type === "document" ? "#007AFF" : media.type === "live_location" ? "#FF2D55" : media.type === "location" ? "#25D366" : "#555"} />
                                {media.name && (<Text numberOfLines={1} style={{ fontSize: 10, maxWidth: 70, marginTop: 4, color: "#333" }} > {media.name} </Text>)}
                              </View>
                            )}
                            <TouchableOpacity style={styles.closeMediaPreview} onPress={() => setSelectedMedia((prev) => prev.filter((_, i) => i !== index))}>
                              <Entypo name="cross" size={16} color="white" />
                            </TouchableOpacity>
                          </View>
                        ))}
                      </ScrollView>
                    )}

                    <View style={[styles.inputPill]}>
                      <TextInput
                        ref={inputRef}
                        style={[styles.textInput]}
                        multiline
                        placeholder="Mesaj yazın"
                        placeholderTextColor="#999"
                        value={inputText}
                        onChangeText={setInputText}
                        onFocus={() => setShowEmojiPicker(false)}
                        onContentSizeChange={(e) => setInputHeight(e.nativeEvent.contentSize.height)}
                        textAlignVertical="center"
                      />
                      <View style={{ flexDirection: "row",justifyContent: "center", alignItems: "flex-end", position: 'absolute', right: 0, bottom: 0 }}>
                        <TouchableOpacity style={[styles.internalActionBtn]} onPress={handleEmojiToggle}>
                          <MaterialCommunityIcons name={showEmojiPicker ? "keyboard-outline" : "sticker-circle-outline"} size={26} color="black" />
                        </TouchableOpacity>
                        {(inputText.trim().length > 0 || selectedMedia.length > 0) && (
                          <TouchableOpacity onPress={handleSendMessagePress} style={styles.internalActionBtn}>
                            <MaterialCommunityIcons name="send-circle" size={26} color="black" />
                          </TouchableOpacity>
                        )}
                      </View>
                    </View>
                  </>
                )}
              </View>

              {(!inputText.trim() && selectedMedia.length === 0) && (
                <TouchableOpacity style={styles.externalButton} onPress={isRecording ? stopRecording : startRecording}>
                  <MaterialCommunityIcons name={isRecording ? "stop" : "microphone"} size={24} color={isRecording ? "#FF3B30" : "black"} />
                </TouchableOpacity>
              )}
            </View>
          </View>

          {showEmojiPicker && (
            <View style={styles.pickerContainer}>
              <View style={styles.pickerTabs}>
                <TouchableOpacity style={[styles.pickerTab, activePickerTab === 'emoji' && styles.pickerTabActive]} onPress={() => setActivePickerTab('emoji')} >
                  <Text style={[styles.pickerTabText, activePickerTab === 'emoji' && styles.pickerTabTextActive]}>Emoji</Text>
                </TouchableOpacity>
                <TouchableOpacity style={[styles.pickerTab, activePickerTab === 'gif' && styles.pickerTabActive]} onPress={() => setActivePickerTab('gif')} >
                  <Text style={[styles.pickerTabText, activePickerTab === 'gif' && styles.pickerTabTextActive]}>GIF</Text>
                </TouchableOpacity>
                <TouchableOpacity style={[styles.pickerTab, activePickerTab === 'sticker' && styles.pickerTabActive]} onPress={() => setActivePickerTab('sticker')} >
                  <Text style={[styles.pickerTabText, activePickerTab === 'sticker' && styles.pickerTabTextActive]}>Sticker</Text>
                </TouchableOpacity>
              </View>
              <View style={styles.pickerContent}>
                {activePickerTab === 'emoji' && (
                  <ScrollView contentContainerStyle={styles.emojiGrid}>
                    {['😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '🥹', '☺️', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🫣', '🤭', '🫢', '🫡', '🤫', '🫠', '🤥', '😶', '🫥', '😐', '🫤', '😑', '🫨', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '😵‍💫', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾'].map((emoji, i) => (
                      <TouchableOpacity key={i} onPress={() => setInputText(prev => prev + emoji)} style={styles.emojiItem}>
                        <Text style={styles.emojiText}>{emoji}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                )}
                {activePickerTab === 'gif' && (<View style={styles.centerContent}><Text style={{ color: '#999' }}>GIFs coming soon!</Text></View>)}
                {activePickerTab === 'sticker' && (<View style={styles.centerContent}><Text style={{ color: '#999' }}>Stickers coming soon!</Text></View>)}
              </View>
            </View>
          )}
        </KeyboardAvoidingView>
        <BottomSheetModal
          ref={bottomSheetModalRef}
          index={0}
          enablePanDownToClose={true}
          enableDynamicSizing={true}
          handleIndicatorStyle={{ backgroundColor: "#ccc", width: 40 }}
          containerStyle={{ marginTop: insets.top }}
        >
          {!showLocationPicker ? (
            <BottomSheetView style={{ paddingBottom: insets.bottom }}>
              <View style={[styles.sheetGrid]}>
                <TouchableOpacity style={styles.sheetButton} onPress={openCamera}>
                  <View style={[styles.sheetIconBox, { backgroundColor: '#FFEDF3' }]}><MaterialCommunityIcons name="camera" size={30} color="#FF2D55" /></View>
                  <Text style={styles.sheetLabel}>Kamera</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.sheetButton} onPress={pickImage}>
                  <View style={[styles.sheetIconBox, { backgroundColor: '#F0EEFF' }]}><MaterialCommunityIcons name="image" size={30} color="#5856D6" /></View>
                  <Text style={styles.sheetLabel}>Galeri</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.sheetButton} onPress={pickVideo}>
                  <View style={[styles.sheetIconBox, { backgroundColor: '#F0EEFF' }]}><MaterialCommunityIcons name="video" size={30} color="#5856D6" /></View>
                  <Text style={styles.sheetLabel}>Video</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.sheetButton} onPress={() => setShowLocationPicker(true)}>
                  <View style={[styles.sheetIconBox, { backgroundColor: '#E8FBF0' }]}><MaterialCommunityIcons name="map-marker" size={30} color="#25D366" /></View>
                  <Text style={styles.sheetLabel}>Konum</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.sheetButton} onPress={openDocuments}>
                  <View style={[styles.sheetIconBox, { backgroundColor: '#E3F2FD' }]}><MaterialCommunityIcons name="file-document" size={30} color="#007AFF" /></View>
                  <Text style={styles.sheetLabel}>Dosya</Text>
                </TouchableOpacity>
              </View>
            </BottomSheetView>
          ) : (
            <BottomSheetFlatList
              contentContainerStyle={{ flexGrow: 1 }}
              ref={bottomSheetFlatListRef}
              style={{ flex: 1 }}
              keyboardShouldPersistTaps="handled"
              keyboardDismissMode="on-drag"
              data={places}
              keyExtractor={(item, index) => `${item.id}-${index}`}
              onEndReached={() => {
                if (nextPageToken && !isLoadingPlaces) {
                  const lat = selectedLocationMap?.latitude || currentLocation?.latitude;
                  const lon = selectedLocationMap?.longitude || currentLocation?.longitude;
                  if (lat && lon) fetchNearbyPlaces(lat, lon, searchQuery, nextPageToken);
                }
              }}
              onEndReachedThreshold={0.5}
              renderItem={({ item }) => {
                const icon = getPlaceIcon(item.name);
                return (
                  <TouchableOpacity style={styles.placeItem} onPress={() => {
                    setSelectedMedia(prev => [...prev, { type: 'location', name: item.name, data: item }]);
                    setShowLocationPicker(false);
                    bottomSheetModalRef.current?.dismiss();
                  }}>
                    <View style={[styles.placeIcon, { backgroundColor: icon.color }]}>
                      <MaterialCommunityIcons name={icon.name as any} size={20} color="white" />
                    </View>
                    <View style={styles.placeText}>
                      <Text style={styles.placeName} numberOfLines={1}>{item.name}</Text>
                      <Text style={styles.placeAddr} numberOfLines={1}>{item.address}</Text>
                    </View>
                  </TouchableOpacity>
                );
              }}
              ListHeaderComponent={
                <View style={{ backgroundColor: "white" }}>
                  <View style={styles.locHeader}>
                    {isSearching ? (
                      <View style={styles.searchHeaderContainer}>
                        <TouchableOpacity onPress={() => { setIsSearching(false); setSearchQuery(""); }}>
                          <Ionicons name="arrow-back" size={24} color="black" />
                        </TouchableOpacity>
                        <TextInput autoFocus style={styles.searchBarInput} placeholder="Yerler ara..." value={searchQuery} onChangeText={setSearchQuery} />
                        {isLoadingPlaces && <ActivityIndicator size="small" color="#999" style={{ marginRight: 5 }} />}
                        {searchQuery.length > 0 && (
                          <TouchableOpacity onPress={() => setSearchQuery("")}>
                            <Ionicons name="close-circle" size={20} color="#888" />
                          </TouchableOpacity>
                        )}
                      </View>
                    ) : (
                      <>
                        <TouchableOpacity onPress={() => setShowLocationPicker(false)}>
                          <Ionicons name="close" size={28} color="black" />
                        </TouchableOpacity>
                        <Text style={styles.locTitle}>Konum</Text>
                        <View style={{ flexDirection: "row", alignItems: "center" }}>
                          {isLoadingPlaces && <ActivityIndicator size="small" color="#999" style={{ marginRight: 10 }} />}
                          <TouchableOpacity onPress={() => setIsSearching(true)}>
                            <Ionicons name="search" size={24} color="black" />
                          </TouchableOpacity>
                        </View>
                      </>
                    )}
                  </View>
                  <View style={styles.locMapContainer}>
                    {currentLocation ? (
                      <MapView provider={PROVIDER_GOOGLE} style={{ flex: 1 }} initialRegion={{ latitude: currentLocation.latitude, longitude: currentLocation.longitude, latitudeDelta: 0.01, longitudeDelta: 0.01, }} showsUserLocation={true} showsMyLocationButton={true} onRegionChangeComplete={(r) => { setSelectedLocationMap(r); fetchNearbyPlaces(r.latitude, r.longitude, searchQuery); }}>
                        <Marker coordinate={{ latitude: currentLocation.latitude, longitude: currentLocation.longitude, }} />
                      </MapView>
                    ) : (<ActivityIndicator style={{ flex: 1 }} />)}
                    <View style={styles.mapMarkerFixed}>
                      <View style={styles.markerCircle} />
                      <View style={styles.markerDot} />
                    </View>
                  </View>
                  {!isSearching && (
                    <>
                      <TouchableOpacity style={styles.locActionRow} onPress={() => { if (currentLocation) { setSelectedMedia(prev => [...prev, { type: 'live_location', name: "Canlı Konum", data: currentLocation }]); setShowLocationPicker(false); bottomSheetModalRef.current?.dismiss(); } }}>
                        <View style={[styles.locActionIcon, { backgroundColor: "#25D366" },]}>
                          <MaterialCommunityIcons name="radio-tower" size={26} color="white" />
                        </View>
                        <View style={styles.locActionTextCol}>
                          <Text style={styles.locActionTitle}>Canlı Konumumu Paylaş...</Text>
                          <Text style={styles.locActionSub}>Hareket halindeyken gerçek zamanlı güncellenir</Text>
                        </View>
                      </TouchableOpacity>

                      <TouchableOpacity onPress={() => { if (currentLocation) { setSelectedMedia(prev => [...prev, { type: 'location', name: "Mevcut Konum", data: currentLocation }]); setShowLocationPicker(false); bottomSheetModalRef.current?.dismiss(); } }} style={styles.locActionRow}>
                        <View style={[styles.locActionIcon, { backgroundColor: "white", borderWidth: 2, borderColor: "#007AFF", },]}>
                          <MaterialCommunityIcons name="map-marker-radius" size={22} color="#007AFF" />
                        </View>
                        <View style={styles.locActionTextCol}>
                          <Text style={styles.locActionTitle}>Şu anki konumu gönder</Text>
                          <Text style={styles.locActionSub}>15 metre kadar doğru</Text>
                        </View>
                      </TouchableOpacity>
                    </>
                  )}
                  <View style={styles.locDivider}><Text style={styles.locDividerText}>YA DA BİR YER SEÇİN</Text></View>
                </View>
              }
              ListEmptyComponent={
                isLoadingPlaces ? (<View style={{ padding: 30, alignItems: "center" }}><ActivityIndicator size="small" color="#999" /></View>) : (<View style={{ padding: 30, alignItems: "center" }}><Text style={{ color: "#888" }}>Yer bulunamadı</Text></View>)
              }
              ListFooterComponent={
                isLoadingPlaces && places.length > 0 ? (<View style={{ padding: 20, alignItems: "center" }}><ActivityIndicator size="small" color="#999" /></View>) : null
              }
              stickyHeaderIndices={[0]}
            />
          )
          }
        </BottomSheetModal>
      </>

  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: "#f5f7f9" },
  container: { flex: 1 },
  footerContainer: {
    paddingHorizontal: 8,
    paddingBottom: Platform.OS === "ios" ? 20 : 10,
    paddingTop: 8,
    backgroundColor: "transparent",
  },
  inputRow: { flexDirection: "row", alignItems: "flex-end", gap: 6 },
  externalButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: "#fff",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 2,
    shadowColor: "#000",
    shadowOpacity: 0.1,
    shadowRadius: 2,
    shadowOffset: { width: 0, height: 1 },
  },
  inputPillContainer: {
    flex: 1,
    backgroundColor: "white",
    borderRadius: 30,
    flexDirection: "column",
    justifyContent: "center",
    shadowColor: "#000",
    shadowOpacity: 0.1,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
    borderWidth: 1,
    borderColor: "#efefef",
  },
  pillSingleLine: { minHeight: 44 },
  pillMultiline: { borderRadius: 20 },
  inputPill: {
    flexDirection: "row",
    alignItems: "flex-end",
    paddingHorizontal: 4,
  },
  textInput: {
    flex: 1,
    fontSize: 16,
    color: "#000",
    paddingVertical: 10,
    paddingLeft: 12,
    lineHeight: 20,
  },
  internalActionBtn: { padding: 8 },

  // Preview Styles
  previewBar: {
    flexDirection: "row",
    alignItems: "center",
    padding: 8,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  previewReply: { backgroundColor: "#f0f7ff", borderLeftColor: "#3b82f6" },
  previewEdit: { backgroundColor: "#f5fff0", borderLeftColor: "#22c55e" },
  previewContent: { flex: 1, paddingLeft: 8 },
  previewLabel: { fontSize: 12, fontWeight: "bold", color: "#333" },
  previewText: { fontSize: 13, color: "#777", paddingTop: 2 },

  mediaPreviewContainer: {
    overflow: 'hidden',
    paddingHorizontal: 6,
    paddingVertical: 6,
    height: 100,
  },
  mediaPreview: {
    width: 80,
    height: 80,
    borderRadius: 8,
    backgroundColor: '#eee',
  },
  closeMediaPreview: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: 'rgba(0,0,0,0.7)',
    borderRadius: 12,
    padding: 2,
  },
  videoOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "rgba(0,0,0,0.3)",
    borderRadius: 8,
  },

  // Recording Styles
  recordingContainer: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-start",
    height: 44,
    width: "100%",
    paddingLeft: 16,
  },
  recordingIndicator: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: "#FF3B30",
    marginRight: 10,
  },
  recordingText: { fontSize: 16, color: "#333" },

  // Emoji Picker
  pickerContainer: { height: 300, backgroundColor: '#f2f2f7' },
  pickerTabs: {
    flexDirection: 'row',
    backgroundColor: '#e8e8ed',
    margin: 16,
    borderRadius: 10,
    padding: 4,
  },
  pickerTab: {
    flex: 1,
    paddingVertical: 6,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
  },
  pickerTabActive: {
    backgroundColor: '#fff',
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  pickerTabText: { fontSize: 14, color: '#8e8e93', fontWeight: '600' },
  pickerTabTextActive: { color: '#000' },
  pickerContent: { flex: 1 },
  emojiGrid: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 8 },
  emojiItem: { width: '12.5%', aspectRatio: 1, alignItems: 'center', justifyContent: 'center' },
  emojiText: { fontSize: 32 },
  centerContent: { flex: 1, justifyContent: 'center', alignItems: 'center' },

  // Bottom Sheet
  sheetGrid: {
    padding: 24,
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-around",
  },
  sheetButton: { width: "25%", alignItems: "center", marginBottom: 24 },
  sheetIconBox: {
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 8,
  },
  sheetLabel: { fontSize: 12, color: "#444", textAlign: 'center' },
  locHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 16,
    height: 50,
    borderBottomWidth: 0.5,
    borderBottomColor: "#eee",
    backgroundColor: "#fff",
  },
  locTitle: { fontSize: 17, fontWeight: "700" },
  searchHeaderContainer: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
  },
  searchBarInput: { flex: 1, height: 40, marginHorizontal: 10, fontSize: 16 },
  locMapContainer: { height: 280, width: "100%", position: "relative" },
  mapMarkerFixed: {
    position: "absolute",
    top: "50%",
    left: "50%",
    marginLeft: -15,
    marginTop: -15,
    width: 30,
    height: 30,
    justifyContent: "center",
    alignItems: "center",
    pointerEvents: "none",
  },
  markerCircle: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: "rgba(0, 122, 255, 0.15)",
    borderWidth: 1,
    borderColor: "rgba(0, 122, 255, 0.4)",
  },
  markerDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "#007AFF",
    position: "absolute",
    borderWidth: 2,
    borderColor: "#fff",
  },

  locActionRow: {
    flexDirection: "row",
    padding: 16,
    alignItems: "center",
    borderBottomWidth: 0.5,
    borderBottomColor: "#f0f0f0",
  },
  locActionIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 15,
  },
  locActionTextCol: { flex: 1 },
  locActionTitle: { fontSize: 16, fontWeight: "600", color: "#000" },
  locActionSub: { fontSize: 13, color: "#888", marginTop: 2 },

  locDivider: {
    backgroundColor: "#F8F8F8",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderTopWidth: 0.5,
    borderBottomWidth: 0.5,
    borderColor: "#eee",
  },
  locDividerText: {
    fontSize: 11,
    fontWeight: "700",
    color: "#999",
    letterSpacing: 0.5,
  },

  placeItem: {
    flexDirection: "row",
    padding: 12,
    alignItems: "center",
    borderBottomWidth: 0.5,
    borderBottomColor: "#f5f5f5",
  },
  placeIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  placeText: { flex: 1 },
  placeName: { fontSize: 15, fontWeight: "600", color: "#333" },
  placeAddr: { fontSize: 12, color: "#888", marginTop: 2 },
});