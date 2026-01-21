import React, { useState, useEffect, useRef, useCallback } from "react";
import { Modal, Pressable } from "react-native";
import * as Haptics from "expo-haptics";
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  FlatList,
  Image,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  ActivityIndicator,
} from "react-native";
import { useNavigation } from "@react-navigation/native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Animated } from "react-native";
import { BlurView } from "expo-blur";

import Ionicons from "@expo/vector-icons/Ionicons";
import MaterialCommunityIcons from "@expo/vector-icons/MaterialCommunityIcons";

import ChatInput from "@/components/ChatInput";

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
  const navigation = useNavigation();

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
  const [contextVisible, setContextVisible] = useState(false);
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  
  const flatListRef = useRef<FlatList>(null);
  const pressScales = useRef<{ [key: string]: Animated.Value }>({}).current;
  const [activePressedId, setActivePressedId] = useState<string | null>(null);

  const currentUser: User = {
    id: "them",
    name: "RIGHT6652",
    status: "son görülme yakınlarda",
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
        // Handle message edit
        setMessages(prev => prev.map(m => m.id === editingId ? {...m, text: text} : m));
    } else {
        // Handle new message
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
      
          // Simulate bot response
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
    setContextVisible(true);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  };

  const startReply = () => {
    if (selectedMessage) {
      setReplyingTo(selectedMessage);
      setEditingMessage(null);
      setContextVisible(false);
    }
  };

  const startEdit = () => {
    if (selectedMessage && selectedMessage.sender === "me") {
      setEditingMessage(selectedMessage);
      setReplyingTo(null);
      setContextVisible(false);
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

  const renderMessage = ({ item }: { item: Message }) => {
    const isMe = item.sender === "me";
    const isSelected = selectedIds.includes(item.id);

    return (
      <Animated.View style={[ styles.messageRow, isMe ? styles.messageRowMe : styles.messageRowThem ]}>
        {!isMe && (
          <View style={[styles.messageAvatarContainer, styles.messageAvatarLeft]}>
            {isSelectionMode && (
              <TouchableOpacity style={styles.checkbox} onPress={() => toggleSelection(item.id)}>
                <MaterialCommunityIcons name={isSelected ? "check-circle" : "circle-outline"} size={26} color={"black"} />
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
          <Animated.View style={[ styles.messageContainer, isMe ? styles.messageOut : styles.messageIn, { transform: [{ scale: getPressScale(item.id) }], opacity: activePressedId === item.id ? 0.8 : 1 } ]}>
            {item.replyTo && (
              <View style={styles.quoteBox}>
                <View style={styles.quoteHeader}>
                  <Image source={{ uri: "https://picsum.photos/seed/reply/100/100" }} style={styles.quoteAvatar}/>
                  <Text style={styles.quoteUser}>{item.replyTo.user}</Text>
                </View>
                <Text style={styles.quoteText} numberOfLines={1}>{item.replyTo.text}</Text>
              </View>
            )}
            <View style={{ minHeight: 40,minWidth:48 }}>
              <Text style={styles.messageTextWithMeta}>{item.text}</Text>
              <View style={styles.messageMetaAbsolute}>
                <Text style={styles.messageTime}>{item.timestamp}</Text>
                {isMe && (
                  <Ionicons name={ item.status === "read" ? "checkmark-done" : "checkmark" } size={14} color={item.status === "read" ? "#22c55e" : "#9ca3af"} />
                )}
              </View>
            </View>
          </Animated.View>
        </Pressable>

        {isMe && (
          <View style={[styles.messageAvatarContainer, styles.messageAvatarRight]}>
            {isSelectionMode && (
              <TouchableOpacity style={styles.checkbox} onPress={() => toggleSelection(item.id)}>
                <MaterialCommunityIcons name={isSelected ? "check-circle" : "circle-outline"} size={26} color={"black"} />
              </TouchableOpacity>
            )}
            <Image source={{ uri: myUser.avatarUrl }} style={[styles.messageAvatar]}/>
          </View>
        )}
      </Animated.View>
    );
  };

  return (
    <SafeAreaView style={[styles.safeArea]}>
      <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === "ios" ? "padding" : undefined}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
            <MaterialCommunityIcons name="chevron-left" size={32} color="black"/>
            <View style={styles.badge}><Text style={styles.badgeText}>8</Text></View>
          </TouchableOpacity>
          <View style={styles.headerCenter}>
            <Text style={styles.headerName}>{currentUser.name}</Text>
            <Text style={styles.headerStatus}>{currentUser.status}</Text>
          </View>
          <View style={styles.avatarCircle}>
            <Text style={styles.avatarChar}>{currentUser.avatarChar}</Text>
          </View>
        </View>

        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.photoScroll} contentContainerStyle={styles.photoScrollContent}>
          {currentUser.photos.map((url, index) => (
            <View key={index} style={styles.photoWrapper}>
              <Image source={{ uri: url }} style={styles.photo} />
            </View>
          ))}
          <TouchableOpacity style={styles.photoAddButton}><Text style={styles.photoAddText}>+</Text></TouchableOpacity>
        </ScrollView>

        <FlatList
          ref={flatListRef}
          data={messages}
          renderItem={renderMessage}
          keyExtractor={(item) => item.id}
          style={styles.messagesContainer}
          contentContainerStyle={styles.messagesContentContainer}
          onContentSizeChange={() => flatListRef.current?.scrollToEnd({ animated: true })}
          ListFooterComponent={
            isTyping ? (
              <View style={styles.messageRowThem}>
                <Image source={{ uri: currentUser.avatarUrl }} style={styles.messageAvatar}/>
                <View style={[styles.messageContainer, styles.messageIn, { paddingHorizontal: 15 }]}>
                  <ActivityIndicator size="small" color="#999" />
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

      <Modal transparent animationType="fade" visible={contextVisible} onRequestClose={() => setContextVisible(false)}>
        <Pressable style={styles.contextBackdrop} onPress={() => setContextVisible(false)}>
          {selectedMessage && (
            <View style={[ styles.contextContainer, selectedMessage?.sender === "me" ? styles.contextAlignRight : styles.contextAlignLeft ]}>
              <View style={styles.reactionBar}>
                <Text style={styles.reactionEmoji}>❤️</Text><Text style={styles.reactionEmoji}>👍</Text><Text style={styles.reactionEmoji}>👎</Text><Text style={styles.reactionEmoji}>🔥</Text><Text style={styles.reactionEmoji}>🥰</Text><Text style={styles.reactionEmoji}>👏</Text><Text style={styles.reactionEmoji}>😁</Text><Text style={styles.reactionEmoji}>✓</Text>
              </View>
              <BlurView experimentalBlurMethod="dimezisBlurView" intensity={100} tint="light" style={styles.contextMenuCard}>
                <Text style={styles.contextReadText}>✓✓ okundu bugün {selectedMessage.timestamp}</Text>
                <View style={styles.contextDivider} />
                <TouchableOpacity style={styles.menuItem} onPress={startReply}>
                  <Text style={styles.menuItemText}>Yanıtla</Text>
                  <MaterialCommunityIcons name="reply" size={24} color="black"/>
                </TouchableOpacity>
                <TouchableOpacity style={styles.menuItem} onPress={() => {}}>
                  <Text style={styles.menuItemText}>Kopyala</Text>
                  <MaterialCommunityIcons name="content-copy" size={24} color="black"/>
                </TouchableOpacity>
                {selectedMessage?.sender === "me" && (
                  <TouchableOpacity style={styles.menuItem} onPress={startEdit}>
                    <Text style={styles.menuItemText}>Düzenle</Text>
                    <MaterialCommunityIcons name="comment-edit-outline" size={24} color="black" />
                  </TouchableOpacity>
                )}
                <TouchableOpacity style={styles.menuItem} onPress={() => {}}>
                  <Text style={styles.menuItemText}>Sabitle</Text>
                  <MaterialCommunityIcons name="pin-outline" size={24} color="black" />
                </TouchableOpacity>
                <View style={styles.contextDivider} />
                <TouchableOpacity style={styles.menuItem} onPress={() => {}}>
                  <Text style={[styles.menuItemText, styles.contextDelete]}>Benden Sil</Text>
                  <MaterialCommunityIcons name="delete-outline" size={24} color="black" />
                </TouchableOpacity>
                <TouchableOpacity style={styles.menuItem} onPress={() => {}}>
                  <Text style={[styles.menuItemText, styles.contextDelete]}>Herkesten Sil</Text>
                  <MaterialCommunityIcons name="delete-alert-outline" size={24} color="black"/>
                </TouchableOpacity>
                <View style={styles.contextDivider} />
                <TouchableOpacity style={styles.menuItem} onPress={() => { setContextVisible(false); toggleSelection(selectedMessage.id); setIsSelectionMode(true); }}>
                  <Text style={[styles.menuItemText]}>Seç</Text>
                  <MaterialCommunityIcons name="comment-check-outline" size={24} color="black"/>
                </TouchableOpacity>
              </BlurView>
            </View>
          )}
        </Pressable>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
    safeArea: { flex: 1, backgroundColor: "#f5f7f9" },
    container: { flex: 1 },
    header: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "space-between",
      paddingHorizontal: 12,
      paddingTop: 10,
      paddingBottom: 8,
      backgroundColor: "transparent",
    },
    backButton: {
      flexDirection: "row",
      alignItems: "center",
      backgroundColor: "rgba(255,255,255,0.8)",
      paddingHorizontal: 10,
      paddingVertical: 5,
      borderRadius: 20,
      shadowColor: "#000",
      shadowOpacity: 0.05,
      shadowRadius: 2,
      shadowOffset: { width: 0, height: 1 },
    },
    badge: {
      backgroundColor: "#000",
      marginLeft: 5,
      paddingHorizontal: 6,
      borderRadius: 10,
      height: 18,
      justifyContent: "center",
      alignItems: "center",
    },
    badgeText: { color: "white", fontSize: 10, fontWeight: "bold" },
    headerCenter: {
      flex: 1,
      alignItems: "center",
      justifyContent: "center",
      backgroundColor: "rgba(255,255,255,0.7)",
      paddingHorizontal: 15,
      paddingVertical: 6,
      borderRadius: 25,
      marginHorizontal: 10,
    },
    headerName: { fontWeight: "700", fontSize: 14, color: "#000" },
    headerStatus: { fontSize: 10, color: "#666" },
    avatarCircle: {
      width: 40,
      height: 40,
      borderRadius: 20,
      backgroundColor: "#28D3D3",
      justifyContent: "center",
      alignItems: "center",
      borderWidth: 2,
      borderColor: "#fff",
    },
    avatarChar: { color: "white", fontWeight: "bold", fontSize: 18 },
  
    photoScroll: { maxHeight: 100, marginVertical: 8, paddingLeft: 16 },
    photoScrollContent: { alignItems: "center", paddingRight: 20 },
    photoWrapper: {
      width: 65,
      height: 85,
      borderRadius: 15,
      overflow: "hidden",
      marginRight: 10,
      backgroundColor: "#ddd",
    },
    photo: { width: "100%", height: "100%" },
    photoAddButton: {
      width: 65,
      height: 85,
      borderRadius: 15,
      borderWidth: 2,
      borderStyle: "dashed",
      borderColor: "#ccc",
      justifyContent: "center",
      alignItems: "center",
    },
    photoAddText: { fontSize: 30, color: "#999" },
  
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
    messageTextWithMeta: { fontSize: 15, marginBottom: 16, color: "#111", lineHeight: 25 },
    messageTime: { fontSize: 10, color: "#888" },
    
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
    quoteUser: { fontWeight: "600", color: "#3b82f6", fontSize: 12 },
    quoteText: { fontSize: 12, color: "#444" },
  
    contextBackdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.15)", justifyContent: "center", alignItems: "center" },
    contextContainer: { alignItems: "center", justifyContent: "center", paddingHorizontal: 8 },
    contextAlignLeft: { alignItems: "flex-start", alignSelf: "flex-start", marginLeft: 0, marginRight: "auto" },
    contextAlignRight: { alignItems: "flex-end", alignSelf: "flex-end", marginRight: 0, marginLeft: "auto" },
    reactionBar: { flexDirection: "row", backgroundColor: "#e0f5d9", borderRadius: 30, paddingHorizontal: 10, paddingVertical: 6, marginBottom: 10 },
    reactionEmoji: { fontSize: 22, marginHorizontal: 4 },
    contextMenuCard: { width: 260, borderColor: "#fff", padding: 10, borderWidth: 1, borderRadius: 18, paddingVertical: 10, overflow: "hidden" },
    contextReadText: { textAlign: "center", fontSize: 12, color: "#555", paddingVertical: 6 },
    contextDivider: { height: 1, backgroundColor: "#e4e4e4", marginVertical: 8 },
    menuItem: { flexDirection: "row", justifyContent: "space-between", padding: 16 },
    menuItemText: { fontSize: 16, fontWeight: "500" },
    contextDelete: { color: "#d00" },
  });