import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { Pressable, View, Text, TouchableOpacity, ScrollView, FlatList, Image, KeyboardAvoidingView, Platform, StyleSheet, ActivityIndicator } from "react-native";
import * as Haptics from "expo-haptics";
import { useNavigation, useTheme } from "@react-navigation/native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Animated } from "react-native";
import { BlurView } from "expo-blur";
import { BottomSheetView, BottomSheetBackdrop, BottomSheetModal } from "@gorhom/bottom-sheet";

import Ionicons from "@expo/vector-icons/Ionicons";
import MaterialCommunityIcons from "@expo/vector-icons/MaterialCommunityIcons";
import { Pin, Trash2, Eraser, X, Reply, Copy, Edit, CheckCircle } from 'lucide-react-native';

import ChatInput from "@/components/ChatInput";
import BaseBottomSheetModal from "@/components/BaseBottomSheetModal";
import { ThemedText } from "@/components/ThemedText";

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
  media?: Media[];
}

interface User {
  id: string;
  name: string;
  status: string;
  avatarChar: string;
  avatarUrl: string;
  distance: string;
  age: number;
  photos: string[];
}

export default function ChatDetail() {
  const { colors, dark } = useTheme();
  const navigation = useNavigation();
  const insets = useSafeAreaInsets();

  const textColor = colors.text;
  const backgroundColor = colors.background;
  const borderColor = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)';
  const secondaryTextColor = dark ? '#666666' : '#999999';

  const [messages, setMessages] = useState<Message[]>([
    {
      id: "1",
      sender: "them",
      text: "He is you father FlashList v2 has been rebuilt from the ground up for RNs new architecture and delivers fast performance, higher precision, and better ease of use compared to v1. Weve achieved all this while moving to a JS-only solution! One of the key advantages of FlashList v2 is that it doesnt require any estimates. It also introduces several new features compared to v1. To know more about whats new in v2 click here.?",
      timestamp: "12:06",
      replyTo: {
        user: "Ersan",
        text: "Hikaye",
        type: "story",
      },
    },
    {
      id: "2",
      sender: "me",
      text: "He is you father FlashList v2 has been rebuilt from the ground up for RNs new architecture and delivers fast performance, higher precision, and better ease of use compared to v1. Weve achieved all this while moving to a JS-only solution! One of the key advantages of FlashList v2 is that it doesnt require any estimates. It also introduces several new features compared to v1. To know more about whats new in v2 click here.?",
      timestamp: "13:08",
      status: "read",
    },
    {
      id: "3",
      sender: "me",
      text: "He is you father FlashList v2 has been rebuilt from the ground up for RNs new architecture and delivers fast performance, higher precision, and better ease of use compared to v1. Weve achieved all this while moving to a JS-only solution! One of the key advantages of FlashList v2 is that it doesnt require any estimates. It also introduces several new features compared to v1. To know more about whats new in v2 click here.?",
      timestamp: "13:28",
      status: "read",
    },
  ]);
  const [replyingTo, setReplyingTo] = useState<Message | null>(null);
  const [editingMessage, setEditingMessage] = useState<Message | null>(null);
  const [isTyping, setIsTyping] = useState(false);
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  
  const flatListRef = useRef<FlatList>(null);
  const bottomSheetModalRef = useRef<BottomSheetModal>(null);
  const pressScales = useRef<{ [key: string]: Animated.Value }>({}).current;
  const [activePressedId, setActivePressedId] = useState<string | null>(null);

  const currentUser: User = {
    id: "them",
    name: "RIGHT6652",
    status: "seen recently",
    avatarChar: "R",
    avatarUrl: "https://i.pravatar.cc/150?u=right6652",
    distance: "2.4 km",
    age: 24,
    photos: [
      "https://picsum.photos/seed/chat1/200/300",
      "https://picsum.photos/seed/chat2/200/300",
      "https://picsum.photos/seed/chat3/200/300",
      "https://picsum.photos/seed/chat4/200/300",
    ],
  };

  const myUser: User = {
      id: "me",
      name: "Ersan",
      status: "online",
      avatarChar: "E",
      avatarUrl: "https://i.pravatar.cc/150?u=me",
      distance: "0 km",
      age: 30,
      photos: []
  }

  const handleSendMessage = (text: string, media: Media[], replyToId?: string, editingId?: string) => {
    if(editingId) {
        setMessages(prev => prev.map(m => m.id === editingId ? {...m, text: text} : m));
    } else {
        const newMessage: Message = {
            id: Date.now().toString(),
            sender: "me",
            text: text,
            timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
            status: "sent",
            media: media,
            ...(replyToId && { replyTo: messages.find(m => m.id === replyToId) as any})
          };
      
          setMessages((prev) => [...prev, newMessage]);
          setIsTyping(true);
      
          setTimeout(() => {
              const botMessage: Message = {
                  id: (Date.now() + 1).toString(),
                  sender: "them",
                  text: "ok",
                  timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
              };
              setMessages((prev) => [...prev, botMessage]);
              setIsTyping(false);
          }, 1000);
    }
  };

  const openContextMenu = (message: Message) => {
    setSelectedMessage(message);
    bottomSheetModalRef.current?.present();
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  };

  const startReply = () => {
    if (selectedMessage) {
      setReplyingTo(selectedMessage);
      setEditingMessage(null);
      bottomSheetModalRef.current?.dismiss();
    }
  };

  const startEdit = () => {
    if (selectedMessage && selectedMessage.sender === "me") {
      setEditingMessage(selectedMessage);
      setReplyingTo(null);
      bottomSheetModalRef.current?.dismiss();
    }
  };

  const toggleSelection = (id: string) => {
    if (selectedIds.includes(id)) {
      const next = selectedIds.filter((sid) => sid !== id);
      setSelectedIds(next);
      if (next.length === 0) setIsSelectionMode(false);
    } else {
      setSelectedIds([...selectedIds, id]);
    }
    try {
      Haptics.selectionAsync();
    } catch (e) { }
  };

  const getPressScale = (id: string) => {
    if (!pressScales[id]) {
      pressScales[id] = new Animated.Value(1);
    }
    return pressScales[id];
  };

  const handlePressIn = (id: string) => {
    setActivePressedId(id);
    Haptics.selectionAsync();
    Animated.spring(getPressScale(id), { toValue: 0.92, speed: 25, bounciness: 6, useNativeDriver: true }).start();
  };

  const handlePressOut = (id: string) => {
    setActivePressedId(null);
    Animated.spring(getPressScale(id), { toValue: 1, speed: 25, bounciness: 6, useNativeDriver: true }).start();
  };

  const renderBackdrop = useCallback(
    (props: any) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />,
    []
  );

  const renderMessage = ({ item }: { item: Message }) => {
    const isMe = item.sender === "me";
    const isSelected = selectedIds.includes(item.id);

    return (
      <Animated.View style={[ styles.messageRow, isMe ? styles.messageRowMe : styles.messageRowThem ]}>
        {!isMe && (
          <View style={[styles.messageAvatarContainer, styles.messageAvatarLeft]}>
            {isSelectionMode && (
              <TouchableOpacity style={styles.checkbox} onPress={() => toggleSelection(item.id)}>
                <MaterialCommunityIcons name={isSelected ? "check-circle" : "circle-outline"} size={26} color={textColor} />
              </TouchableOpacity>
            )}
            <Image source={{ uri: currentUser.avatarUrl }} style={[styles.messageAvatar]}/>
          </View>
        )}

        <Pressable
          style={{ maxWidth: "86%" }}
          onLongPress={() => !isSelectionMode && openContextMenu(item)}
          onPress={() => isSelectionMode && toggleSelection(item.id)}
          delayLongPress={200}
          onPressIn={() => handlePressIn(item.id)}
          onPressOut={() => handlePressOut(item.id)}
        >
          <Animated.View style={[ styles.messageContainer, isMe ? [styles.messageOut, { backgroundColor: textColor }] : [styles.messageIn, { backgroundColor: dark ? '#1A1A1A' : '#ffffff' }], { transform: [{ scale: getPressScale(item.id) }], opacity: activePressedId === item.id ? 0.8 : 1 } ]}>
            {item.replyTo && (
              <View style={[styles.quoteBox, { backgroundColor: dark ? '#333' : '#F5F5F5', borderLeftColor: textColor }]}>
                <View style={styles.quoteHeader}>
                  <Image source={{ uri: "https://picsum.photos/seed/reply/100/100" }} style={styles.quoteAvatar}/>
                  <Text style={[styles.quoteUser, { color: textColor }]}>{item.replyTo.user}</Text>
                </View>
                <Text style={[styles.quoteText, { color: backgroundColor }]} numberOfLines={1}>{item.replyTo.text}</Text>
              </View>
            )}
            <View style={{ minHeight: 40,minWidth:48 }}>
              <Text style={[styles.messageTextWithMeta, { color: isMe ? backgroundColor : textColor }]}>{item.text}</Text>
              <View style={styles.messageMetaAbsolute}>
                <Text style={[styles.messageTime, { color: isMe ? backgroundColor + 'CC' : textColor + '80' }]}>{item.timestamp}</Text>
                {isMe && (
                  <Ionicons name={ item.status === "read" ? "checkmark-done" : "checkmark" } size={14} color={backgroundColor} />
                )}
              </View>
            </View>
          </Animated.View>
        </Pressable>

        {isMe && (
          <View style={[styles.messageAvatarContainer, styles.messageAvatarRight]}>
            {isSelectionMode && (
              <TouchableOpacity style={styles.checkbox} onPress={() => toggleSelection(item.id)}>
                <MaterialCommunityIcons name={isSelected ? "check-circle" : "circle-outline"} size={26} color={textColor} />
              </TouchableOpacity>
            )}
            <Image source={{ uri: myUser.avatarUrl }} style={[styles.messageAvatar]}/>
          </View>
        )}
      </Animated.View>
    );
  };

    const bottomBarHeight = Platform.OS === 'ios' ? 88 : 68;
    const headerHeight = 60 + insets.top;

    return (
      <View style={[styles.safeArea, { backgroundColor: backgroundColor }]}>
        <KeyboardAvoidingView 
          style={[styles.container, { paddingBottom: bottomBarHeight, paddingTop: headerHeight }]} 
          behavior={Platform.OS === "ios" ? "padding" : undefined}
          keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 0}
        >

          <FlatList
            ref={flatListRef}
            data={messages}
            renderItem={renderMessage}
            keyExtractor={(item) => item.id}
            style={styles.messagesContainer}
            contentContainerStyle={[styles.messagesContentContainer, { paddingBottom: insets.bottom + 20 }]}
            onContentSizeChange={() => flatListRef.current?.scrollToEnd({ animated: true })}
            ListFooterComponent={
              isTyping ? (
                <View style={styles.messageRowThem}>
                  <Image source={{ uri: currentUser.avatarUrl }} style={styles.messageAvatar}/>
                  <View style={[styles.messageContainer, styles.messageIn, { backgroundColor: dark ? '#222' : '#FFF', paddingHorizontal: 15 }]}>
                    <ActivityIndicator size="small" color={textColor + '50'} />
                  </View>
                </View>
              ) : null
            }
          />

        <ChatInput
          currentUser={myUser}
          onSendMessage={handleSendMessage}
          replyingTo={replyingTo}
          onCancelReply={() => setReplyingTo(null)}
          editingMessage={editingMessage}
          onCancelEdit={() => setEditingMessage(null)}
        />
      </KeyboardAvoidingView>

      {/* Message Context Menu BottomSheet */}
      <BaseBottomSheetModal
        ref={bottomSheetModalRef}
        backdropComponent={renderBackdrop}
        backgroundStyle={{ backgroundColor: dark ? '#000' : '#FFF' }}
      >
        <BottomSheetView style={styles.sheetContent}>
            <View style={styles.sheetHeader}>
                <View style={styles.sheetAvatarContainer}>
                    <Image source={{ uri: selectedMessage?.sender === "me" ? myUser.avatarUrl : currentUser.avatarUrl }} style={styles.sheetAvatar} />
                </View>
                <View style={{ flex: 1, marginLeft: 12 }}>
                    <ThemedText style={styles.sheetTitle}>{selectedMessage?.sender === "me" ? "You" : currentUser.name}</ThemedText>
                    <ThemedText style={[styles.sheetSub, { color: secondaryTextColor }]}>Sent at {selectedMessage?.timestamp}</ThemedText>
                </View>
                <TouchableOpacity onPress={() => bottomSheetModalRef.current?.dismiss()} style={styles.closeBtn}>
                   <X size={20} color={textColor} />
                </TouchableOpacity>
            </View>

            <View style={styles.sheetOptions}>
                <OptionItem 
                    icon={<Reply size={20} color={textColor} />} 
                    label="Reply" 
                    onPress={startReply}
                    textColor={textColor}
                />
                <OptionItem 
                    icon={<Copy size={20} color={textColor} />} 
                    label="Copy" 
                    onPress={() => { bottomSheetModalRef.current?.dismiss(); }}
                    textColor={textColor}
                />
                {selectedMessage?.sender === "me" && (
                  <OptionItem 
                    icon={<Edit size={20} color={textColor} />} 
                    label="Edit" 
                    onPress={startEdit}
                    textColor={textColor}
                  />
                )}
                <View style={[styles.separator, { backgroundColor: borderColor }]} />
                
                <OptionItem 
                    icon={<Pin size={20} color={textColor} />} 
                    label="Pin Message" 
                    onPress={() => { bottomSheetModalRef.current?.dismiss(); }}
                    textColor={textColor}
                />
                
                <View style={[styles.separator, { backgroundColor: borderColor }]} />

                <OptionItem 
                    icon={<Trash2 size={20} color={textColor} />} 
                    label="Delete For Me" 
                    onPress={() => { bottomSheetModalRef.current?.dismiss(); }}
                    textColor={textColor}
                />
                <OptionItem 
                    icon={<Trash2 size={20} color="#FF453A" />} 
                    label="Delete For All" 
                    onPress={() => { bottomSheetModalRef.current?.dismiss(); }}
                    textColor="#FF453A"
                />
                
                <View style={[styles.separator, { backgroundColor: borderColor }]} />
                
                <OptionItem 
                    icon={<CheckCircle size={20} color={textColor} />} 
                    label="Select" 
                    onPress={() => { 
                        if(selectedMessage) {
                            toggleSelection(selectedMessage.id); 
                            setIsSelectionMode(true); 
                        }
                        bottomSheetModalRef.current?.dismiss(); 
                    }}
                    textColor={textColor}
                />
            </View>
            <View style={{ height: insets.bottom + 20 }} />
        </BottomSheetView>
      </BaseBottomSheetModal>
    </View>
  );
}

function OptionItem({ icon, label, onPress, textColor }: any) {
    return (
        <TouchableOpacity onPress={onPress} style={styles.optionItem}>
            <View style={styles.optionIcon}>{icon}</View>
            <ThemedText style={[styles.optionLabel, { color: textColor }]}>{label}</ThemedText>
        </TouchableOpacity>
    );
}

const styles = StyleSheet.create({
    safeArea: { flex: 1, backgroundColor: "#f5f7f9" },
    container: { flex: 1 },
    messagesContainer: { flex: 1, paddingHorizontal: 12, position: "relative" },
    messagesContentContainer: { paddingBottom: 20 },
    messageRow: {
      flexDirection: "row",
      marginVertical: 4,
      alignItems: "flex-end",
      width: "100%",
    },
    messageRowMe: { justifyContent: "flex-end" },
    messageRowThem: { justifyContent: "flex-start" },
    messageAvatar: { width: 32, height: 32, borderRadius: 16, backgroundColor: "#eee" },
    messageAvatarContainer: { flexDirection: "column", alignItems: "center", alignContent: "center", gap: 10, justifyContent: "center" },
    messageAvatarRight: { marginLeft: 10 },
    messageAvatarLeft: { marginRight: 10 },
    checkbox: { width: "100%", alignContent: "center", alignItems: "center" },
  
    messageContainer: {
      borderRadius: 18,
      paddingTop: 10,
      paddingHorizontal: 10,
      paddingBottom: 8,
      width: "100%",
      shadowColor: "#000",
      shadowOpacity: 0.05,
      textAlign: "left",
      justifyContent: "center",
      shadowRadius: 1,
      shadowOffset: { width: 0, height: 1 },
    },
    messageIn: { backgroundColor: "#fff", borderBottomLeftRadius: 4, alignSelf: "flex-start" },
    messageOut: { backgroundColor: "#e9fcd9", borderBottomRightRadius: 4, alignSelf: "flex-end" },
    messageMetaAbsolute: { position: "absolute", right: 0, bottom: 0, flexDirection: "row", alignItems: "center" },
    messageTextWithMeta: { fontSize: 15, marginBottom: 16, color: "#111", lineHeight: 22, fontFamily: 'Inter-Regular' },
    messageTime: { fontSize: 10, color: "#888", fontFamily: 'Inter-SemiBold' },
    
    quoteBox: {
      backgroundColor: "#f0f4f8",
      borderLeftWidth: 3,
      borderLeftColor: "#3b82f6",
      borderRadius: 8,
      padding: 6,
      marginBottom: 6,
    },
    quoteHeader: { flexDirection: "row", alignItems: "center", marginBottom: 2 },
    quoteAvatar: { width: 20, height: 20, borderRadius: 4, marginRight: 6 },
    quoteUser: { fontFamily: "Inter-Bold", color: "#3b82f6", fontSize: 12 },
    quoteText: { fontSize: 12, color: "#444", fontFamily: 'Inter-Regular' },

    sheetContent: {
      padding: 24,
    },
    sheetHeader: {
      flexDirection: "row",
      alignItems: "center",
      marginBottom: 32,
    },
    sheetAvatarContainer: {
      width: 50,
      height: 50,
      borderRadius: 25,
      overflow: "hidden",
      backgroundColor: "#333",
    },
    sheetAvatar: {
      width: "100%",
      height: "100%",
    },
    sheetTitle: {
      fontSize: 20,
      fontFamily: "Outfit-Bold",
    },
    sheetSub: {
      fontSize: 13,
      fontFamily: "Inter-Medium",
    },
    closeBtn: {
      padding: 8,
      borderRadius: 20,
      backgroundColor: "rgba(150,150,150,0.1)",
    },
    sheetOptions: {
      gap: 4,
    },
    optionItem: {
      flexDirection: "row",
      alignItems: "center",
      paddingVertical: 14,
      paddingHorizontal: 12,
    },
    optionIcon: {
      width: 32,
      alignItems: "center",
    },
    optionLabel: {
      fontSize: 16,
      fontFamily: "Inter-SemiBold",
      marginLeft: 16,
    },
    separator: {
      height: 1,
      marginVertical: 6,
      opacity: 0.5,
    },
});