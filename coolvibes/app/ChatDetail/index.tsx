import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  Image,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  ActivityIndicator,
  StatusBar,
  Pressable,
  Modal,
  Dimensions
} from "react-native";
import { FlashList, FlashListProps } from "@shopify/flash-list";
import * as Haptics from "expo-haptics";
import { useTheme } from "@react-navigation/native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeIn, SlideInRight, SlideInLeft } from "react-native-reanimated";
import { BottomSheetView, BottomSheetBackdrop, BottomSheetModal } from "@gorhom/bottom-sheet";
import { useLocalSearchParams, Stack, useRouter } from 'expo-router';
import { BlurView } from 'expo-blur';
import { VideoView, useVideoPlayer } from 'expo-video';
import * as SecureStore from 'expo-secure-store';

import Ionicons from "@expo/vector-icons/Ionicons";
import MaterialCommunityIcons from "@expo/vector-icons/MaterialCommunityIcons";

import {
  ChevronLeft,
  MoreVertical,
  X,
  Reply,
  Copy,
  Edit,
  CheckCircle,
  Pin,
  Trash2,
  Check,
  CheckCheck
} from 'lucide-react-native';

import ChatInput from "@/components/ChatInput";
import BaseBottomSheetModal from "@/components/BaseBottomSheetModal";
import { ThemedText } from "@/components/ThemedText";
import { useAppDispatch, useAppSelector } from "@/store/hooks";
import { api } from "@/services/apiService";
import { getSafeImageURL, getSafeImageURLEx } from "@/helpers/safeUrl";
import { useSocket } from "@/contexts/SocketContext";
import { Actions } from "@/services/actions";
import { markChatRead } from "@/store/slice/chat";

// --- Types ---
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
  image?: string;
  video?: string;
  videoThumbnail?: string;
}

interface User {
  id: string;
  name: string;
  status: string;
  avatarUrl: string;
}

const getReadMessageId = (message: any) => {
  const rawId = message?.id ?? message?.message_id ?? null;
  if (rawId === null || rawId === undefined || rawId === '') return '';
  return String(rawId);
};

export default function ChatDetail() {
  const { colors, dark } = useTheme();
  const insets = useSafeAreaInsets();
  const params = useLocalSearchParams();
  const router = useRouter();
  const dispatch = useAppDispatch();
  const language = useAppSelector((state) => state.system.language) || 'en';
  const authUser = useAppSelector((state) => state.auth.user);
  const authUserId = useAppSelector((state) => state.auth.user?.id ?? null);
  const socket = useSocket();

  // Colors
  const textColor = dark ? '#FFFFFF' : '#000000';
  const backgroundColor = dark ? '#000000' : '#FFFFFF';
  const borderCol = dark ? '#1A1A1A' : '#F0F0F0';
  const secondaryText = dark ? '#666666' : '#999999';
  const bubbleThem = dark ? '#1C1C1E' : '#F2F2F7';
  const bubbleMe = dark ? '#FFFFFF' : '#000000';
  const bubbleMeText = dark ? '#000000' : '#FFFFFF';

  // State
  const [messages, setMessages] = useState<Message[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [messagesError, setMessagesError] = useState<string | null>(null);

  const [revealedMediaIds, setRevealedMediaIds] = useState<string[]>([]);
  const [fullscreenImage, setFullscreenImage] = useState<string | null>(null);
  const [fullscreenVideo, setFullscreenVideo] = useState<string | null>(null);

  const videoPlayer = useVideoPlayer(fullscreenVideo || '', player => {
    player.loop = true;
    player.play();
  });

  useEffect(() => {
    if (!fullscreenVideo) {
      videoPlayer.pause();
    } else {
      videoPlayer.play();
    }
  }, [fullscreenVideo]);

  const [replyingTo, setReplyingTo] = useState<Message | null>(null);
  const [editingMessage, setEditingMessage] = useState<Message | null>(null);
  const [isTyping, setIsTyping] = useState(false);
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  const flashListRef = useRef<any>(null);
  const bottomSheetModalRef = useRef<BottomSheetModal>(null);
  const typingIndicatorTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastTypingParamRef = useRef<string | null>(null);
  const pendingReadIdsRef = useRef<Set<string>>(new Set());
  const readFlushTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const chatId = (params.chatId as string) || "";
  const currentChatRoomRef = useRef<string | null>(null);

  useEffect(() => {
    if (chatId) {
      dispatch(markChatRead({ chatId, userId: authUserId }));
    }
  }, [chatId, authUserId, dispatch]);

  const queueMarkRead = useCallback((ids: string[]) => {
    if (!chatId || ids.length === 0) return;
    ids.forEach((id) => {
      if (id) pendingReadIdsRef.current.add(String(id));
    });
    if (readFlushTimeoutRef.current) return;
    readFlushTimeoutRef.current = setTimeout(async () => {
      const batch = Array.from(pendingReadIdsRef.current);
      pendingReadIdsRef.current.clear();
      readFlushTimeoutRef.current = null;
      if (batch.length === 0) return;
      try {
        await api.markMessagesRead({ chat_id: chatId, message_ids: batch });
      } catch {
        // ignore mark read errors
      }
    }, 350);
  }, [chatId]);

  useEffect(() => {
    return () => {
      if (readFlushTimeoutRef.current) {
        clearTimeout(readFlushTimeoutRef.current);
        readFlushTimeoutRef.current = null;
      }
      pendingReadIdsRef.current.clear();
    };
  }, []);

  const getLocalizedText = (value: any) => {
    if (!value) return '';
    if (typeof value === 'string') return value;
    if (typeof value === 'number') return String(value);
    if (typeof value === 'object') {
      return value[language] || value.en || Object.values(value)[0] || '';
    }
    return '';
  };

  const formatTime = (timestamp?: string) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    if (Number.isNaN(date.getTime())) return '';
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const resolveAttachmentUrl = (attachment: any, variant = 'original') => {
    const raw =
      attachment?.file?.variants?.video?.[variant]?.url ||
      attachment?.variants?.video?.[variant]?.url ||
      attachment?.file?.variants?.image?.[variant]?.url ||
      attachment?.variants?.image?.[variant]?.url ||
      attachment?.file?.url ||
      attachment?.url;
    return getSafeImageURL(raw || attachment, variant);
  };

  const toMessage = useCallback((msg: any): Message | null => {
    if (!msg) return null;
    const attachments = Array.isArray(msg?.attachments) ? msg.attachments : [];
    let image: string | undefined;
    let video: string | undefined;
    let videoThumbnail: string | undefined;

    attachments.forEach((att: any) => {
      const mime = String(att?.file?.mime_type || att?.mime_type || '').toLowerCase();
      if (!image && mime.startsWith('image/')) {
        image = resolveAttachmentUrl(att, 'medium') || resolveAttachmentUrl(att, 'large') || undefined;
      }
      if (!video && mime.startsWith('video/')) {
        video = resolveAttachmentUrl(att, 'original') || resolveAttachmentUrl(att, 'large') || undefined;
        videoThumbnail = resolveAttachmentUrl(att, 'thumbnail') || resolveAttachmentUrl(att, 'small') || undefined;
      }
    });

    const id = String(msg?.id ?? msg?.public_id ?? msg?.uuid ?? msg?.slug ?? Math.random());
    const sender: "me" | "them" = msg?.author_id && authUserId && String(msg.author_id) === String(authUserId) ? "me" : "them";
    const text =
      getLocalizedText(msg?.content) ||
      getLocalizedText(msg?.text) ||
      getLocalizedText(msg?.body) ||
      '';
    const timestamp = formatTime(msg?.created_at || msg?.updated_at || msg?.timestamp);

    return {
      id,
      sender,
      text,
      timestamp,
      status: msg?.status || undefined,
      image,
      video,
      videoThumbnail,
    };
  }, [authUserId, language]);

  const mapMessages = useCallback((rawMessages: any[]): Message[] => {
    if (!Array.isArray(rawMessages)) return [];
    const sorted = [...rawMessages].sort((a, b) => {
      const ta = new Date(a?.created_at || a?.updated_at || 0).getTime();
      const tb = new Date(b?.created_at || b?.updated_at || 0).getTime();
      return ta - tb;
    });
    return sorted.map((msg: any) => toMessage(msg)).filter(Boolean) as Message[];
  }, [toMessage]);

  useEffect(() => {
    let isActive = true;
    if (!chatId) return;
    const fetchMessages = async () => {
      setMessagesLoading(true);
      setMessagesError(null);
      try {
        const response = await api.fetchMessages({ chat_id: chatId, limit: 50 });
        const payload = response?.data ?? response;
        const rawMessages =
          payload?.messages ??
          payload?.data?.messages ??
          response?.messages ??
          response?.data?.messages ??
          [];
        const unreadIds = rawMessages
          .filter((msg: any) => msg?.author_id && authUserId && String(msg.author_id) !== String(authUserId))
          .map((msg: any) => getReadMessageId(msg))
          .filter(Boolean);
        if (isActive) {
          setMessages(mapMessages(rawMessages));
          if (unreadIds.length > 0) {
            dispatch(markChatRead({ chatId, userId: authUserId }));
            queueMarkRead(unreadIds);
          }
        }
      } catch (error: any) {
        if (isActive) setMessagesError(error?.message || 'Failed to load messages');
      } finally {
        if (isActive) setMessagesLoading(false);
      }
    };
    fetchMessages();
    return () => {
      isActive = false;
    };
  }, [chatId, mapMessages, authUserId, dispatch, queueMarkRead]);

  useEffect(() => {
    if (!socket || !chatId) return;

    const parseSocketPayload = (msg: any) => {
      if (Array.isArray(msg)) {
        if (msg.length > 1 && typeof msg[1] === 'string') {
          try {
            return JSON.parse(msg[1]);
          } catch {
            return msg;
          }
        }
        return msg;
      }
      if (typeof msg === 'string') {
        try {
          return JSON.parse(msg);
        } catch {
          return msg;
        }
      }
      return msg;
    };

    const handleSocketMessage = (msg: any) => {
      const messageData = parseSocketPayload(msg);
      const action = messageData?.action;
      const message = messageData?.message || messageData?.data?.message || messageData?.data || messageData;

      if (action === Actions.CMD_TYPING || messageData?.typing !== undefined) {
        const typingChatId = messageData?.chatID || messageData?.chat_id || messageData?.chatId;
        const typingUserId = messageData?.userID || messageData?.user_id || messageData?.userId;
        const isTypingActive = messageData?.typing === true;

        if (
          typingChatId &&
          String(typingChatId) === String(chatId) &&
          typingUserId &&
          String(typingUserId) !== String(authUserId)
        ) {
          if (typingIndicatorTimeoutRef.current) {
            clearTimeout(typingIndicatorTimeoutRef.current);
            typingIndicatorTimeoutRef.current = null;
          }

          if (isTypingActive) {
            setIsTyping(true);
            typingIndicatorTimeoutRef.current = setTimeout(() => {
              setIsTyping(false);
              typingIndicatorTimeoutRef.current = null;
            }, 3000);
          } else {
            setIsTyping(false);
          }
        }
        return;
      }

      const isMessageLike = Boolean(message?.contentable_id || message?.chat_id || message?.content || message?.text);

      if ((action === Actions.CMD_SEND_MESSAGE || (!action && isMessageLike)) && message) {
        const messageChatId = message.contentable_id || message.chat_id || messageData?.chat_id || messageData?.chatID;
        if (messageChatId && chatId && String(messageChatId) !== String(chatId)) {
          return;
        }
        const mapped = toMessage(message);
        if (!mapped) return;

        if (mapped.sender === 'them') {
          setIsTyping(false);
          if (typingIndicatorTimeoutRef.current) {
            clearTimeout(typingIndicatorTimeoutRef.current);
            typingIndicatorTimeoutRef.current = null;
          }
        }

        setMessages((prev) => {
          if (prev.some((m) => m.id === mapped.id)) return prev;

          if (mapped.sender === 'me') {
            const recent = prev.slice(-5).reverse();
            const optimistic = recent.find((m) => m.sender === 'me' && m.text === mapped.text && String(m.id).startsWith('temp-'));
            if (optimistic) {
              return prev.map((m) => (m.id === optimistic.id ? { ...m, id: mapped.id, status: mapped.status ?? m.status } : m));
            }
          }

          return [...prev, mapped];
        });

        if (mapped.sender === 'them') {
          const messageId = getReadMessageId(message);
          if (messageId) {
            dispatch(markChatRead({ chatId, userId: authUserId }));
            queueMarkRead([messageId]);
          }
        }
      }
    };

    const onConnect = async () => {
      try {
        const savedToken = await SecureStore.getItemAsync('authToken');
        if (savedToken) {
          socket.emit('auth', savedToken);
        }
      } catch {
        // ignore
      }

      if (currentChatRoomRef.current !== chatId) {
        socket.emit('join', JSON.stringify({ chat_id: chatId }));
        currentChatRoomRef.current = chatId;
      }
    };

    onConnect();
    socket.on('connect', onConnect);
    socket.on('message', handleSocketMessage);
    socket.on('chat', handleSocketMessage);

    return () => {
      socket.off('message', handleSocketMessage);
      socket.off('chat', handleSocketMessage);
      socket.off('connect', onConnect);

      if (currentChatRoomRef.current) {
        socket.emit('leave', JSON.stringify({ chat_id: currentChatRoomRef.current }));
        currentChatRoomRef.current = null;
      }

      if (typingIndicatorTimeoutRef.current) {
        clearTimeout(typingIndicatorTimeoutRef.current);
        typingIndicatorTimeoutRef.current = null;
      }
    };
  }, [socket, chatId, toMessage, authUserId, dispatch, queueMarkRead]);

  useEffect(() => {
    const nextParam = isTyping ? '1' : '0';
    if (lastTypingParamRef.current !== nextParam) {
      lastTypingParamRef.current = nextParam;
      router.setParams({ typing: nextParam });
    }
  }, [isTyping, router]);

  // Chat Partner Data
  const chatPartner: User = {
    id: chatId || "user_1",
    name: (params.name as string) || "Alex Rivera",
    status: (params.status as string) || "online",
    avatarUrl: (params.avatar as string) || `https://i.pravatar.cc/150?u=${params.name || "Alex"}`,
  };

  const myUser = useMemo(() => {
    const avatar = getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar, 'small') ||
      getSafeImageURLEx(authUser?.id ?? authUser?.public_id, authUser?.avatar_url || authUser?.avatarUrl, 'small') ||
      "https://i.pravatar.cc/150?u=me";
    return {
      id: authUser?.id || "me",
      name: authUser?.displayname || authUser?.username || "Me",
      avatarUrl: avatar,
    };
  }, [authUser]);

  const handleSendMessage = (text: string, media: any[], replyToId?: string, editingId?: string) => {
    if (editingId) {
      setMessages(prev => prev.map(m => m.id === editingId ? { ...m, text: text } : m));
    } else {
      if (!text?.trim() && (!media || media.length === 0)) return;

      const tempId = `temp-${Date.now()}`;
      const newMessage: Message = {
        id: tempId,
        sender: "me",
        text: text,
        timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
        status: "sent",
        ...(replyToId && { replyTo: { user: chatPartner.name, text: messages.find(m => m.id === replyToId)?.text || "", type: "text" } })
      };

      setMessages((prev) => [...prev, newMessage]);

      api.sendMessage(chatId, text).catch(() => {
        // keep optimistic message; errors will be visible when server doesn't echo
      });
    }
  };

  const openContextMenu = (message: Message) => {
    setSelectedMessage(message);
    bottomSheetModalRef.current?.present();
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  };

  const toggleSelection = (id: string) => {
    if (selectedIds.includes(id)) {
      const next = selectedIds.filter((sid) => sid !== id);
      setSelectedIds(next);
      if (next.length === 0) setIsSelectionMode(false);
    } else {
      setSelectedIds([...selectedIds, id]);
    }
    Haptics.selectionAsync();
  };

  const renderBackdrop = useCallback(
    (props: any) => <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />,
    []
  );

  const renderMessage = ({ item, index }: { item: Message, index: number }) => {
    const isMe = item.sender === "me";
    const isSelected = selectedIds.includes(item.id);
    const nextMsg = messages[index + 1];
    const isLastInGroup = !nextMsg || nextMsg.sender !== item.sender;

    return (
      <View style={[
        styles.messageRow,
        isMe ? styles.messageRowMe : styles.messageRowThem,
        { marginBottom: isLastInGroup ? 16 : 4 }
      ]}>
        <Pressable
          onLongPress={() => !isSelectionMode && openContextMenu(item)}
          onPress={() => isSelectionMode && toggleSelection(item.id)}
          delayLongPress={200}
          style={({ pressed }) => [
            { opacity: (pressed || isSelected) ? 0.7 : 1, maxWidth: '85%' }
          ]}
        >
          <Animated.View
            entering={FadeIn.duration(400).delay(index * 50)}
            style={[
              styles.messageContainer,
              isMe ? [styles.messageOut, { backgroundColor: bubbleMe }] : [styles.messageIn, { backgroundColor: bubbleThem }],
            ]}
          >
            {item.replyTo && (
              <View style={[styles.quoteBox, { backgroundColor: isMe ? 'rgba(0,0,0,0.1)' : 'rgba(0,0,0,0.05)', borderLeftColor: isMe ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)' }]}>
                <Text style={[styles.quoteUser, { color: isMe ? bubbleMeText : textColor }]}>{item.replyTo.user}</Text>
                <Text style={[styles.quoteText, { color: isMe ? bubbleMeText + 'AA' : secondaryText }]} numberOfLines={1}>{item.replyTo.text}</Text>
              </View>
            )}

            {item.image && (
              <TouchableOpacity
                activeOpacity={0.9}
                onPress={() => {
                  if (isSelectionMode) {
                    toggleSelection(item.id);
                  } else if (messages.length < 10 && !revealedMediaIds.includes(item.id)) {
                    setRevealedMediaIds(prev => [...prev, item.id]);
                  } else {
                    setFullscreenImage(item.image || null);
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  }
                }}
                onLongPress={() => !isSelectionMode && openContextMenu(item)}
                delayLongPress={200}
                style={styles.messageImageContainer}
              >
                <Image source={{ uri: item.image }} style={styles.messageImage} />
                {messages.length < 10 && !revealedMediaIds.includes(item.id) && (
                  <BlurView intensity={Platform.OS === 'ios' ? 70 : 90} tint={dark ? "dark" : "light"} style={styles.blurCover}>
                    <MaterialCommunityIcons name="eye-off-outline" size={24} color={textColor} />
                    <Text style={[styles.blurText, { color: textColor }]}>Tap to reveal</Text>
                  </BlurView>
                )}
              </TouchableOpacity>
            )}

            {item.video && (
              <TouchableOpacity
                activeOpacity={0.9}
                onPress={() => {
                  if (isSelectionMode) {
                    toggleSelection(item.id);
                  } else if (messages.length < 10 && !revealedMediaIds.includes(item.id)) {
                    setRevealedMediaIds(prev => [...prev, item.id]);
                  } else {
                    setFullscreenVideo(item.video || null);
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  }
                }}
                onLongPress={() => !isSelectionMode && openContextMenu(item)}
                delayLongPress={200}
                style={styles.messageImageContainer}
              >
                <Image source={{ uri: item.videoThumbnail }} style={styles.messageImage} />
                
                {messages.length < 10 && !revealedMediaIds.includes(item.id) ? (
                  <BlurView intensity={Platform.OS === 'ios' ? 70 : 90} tint={dark ? "dark" : "light"} style={styles.blurCover}>
                    <MaterialCommunityIcons name="eye-off-outline" size={24} color={textColor} />
                    <Text style={[styles.blurText, { color: textColor }]}>Tap to reveal</Text>
                  </BlurView>
                ) : (
                  <View style={styles.playIconContainer}>
                    <MaterialCommunityIcons name="play-circle-outline" size={48} color="#FFF" />
                  </View>
                )}
              </TouchableOpacity>
            )}

            <Text style={[styles.messageText, { color: isMe ? bubbleMeText : textColor }]}>{item.text}</Text>

            <View style={styles.messageMeta}>
              <Text style={[styles.messageTime, { color: isMe ? bubbleMeText + '99' : secondaryText }]}>{item.timestamp}</Text>
              {isMe && (
                <View style={{ marginLeft: 4 }}>
                  {item.status === 'read' ? (
                    <CheckCheck size={12} color={bubbleMeText + 'AA'} />
                  ) : (
                    <Check size={12} color={bubbleMeText + 'AA'} />
                  )}
                </View>
              )}
            </View>
          </Animated.View>
        </Pressable>

        {isSelectionMode && (
          <TouchableOpacity
            style={[styles.selectionCheck, { marginLeft: isMe ? 8 : 0, marginRight: isMe ? 0 : 8 }]}
            onPress={() => toggleSelection(item.id)}
          >
            <MaterialCommunityIcons
              name={isSelected ? "check-circle" : "circle-outline"}
              size={22}
              color={textColor}
            />
          </TouchableOpacity>
        )}
      </View>
    );
  };

  const headerHeight = 64 + insets.top;

  return (
    <View style={[styles.main, { backgroundColor }]}>
      <Stack.Screen options={{ headerShown: false }} />
      <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />

      <KeyboardAvoidingView
        style={styles.container}
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        keyboardVerticalOffset={0}
      >
        <FlashList
          ref={flashListRef}
          data={messages}
          renderItem={renderMessage}
          keyExtractor={(item) => item.id}
          // @ts-ignore
          estimatedItemSize={100}
          contentContainerStyle={[
            styles.list,
            {
              paddingBottom: 20,
              paddingTop: headerHeight + 12
            }
          ]}
          showsVerticalScrollIndicator={false}
          onContentSizeChange={() => flashListRef.current?.scrollToEnd?.({ animated: true })}
          ListEmptyComponent={
            messagesLoading ? (
              <View style={{ paddingTop: 120, alignItems: 'center' }}>
                <ActivityIndicator size="small" color={secondaryText} />
              </View>
            ) : (
              <View style={{ paddingTop: 120, alignItems: 'center' }}>
                <ThemedText style={{ color: secondaryText }}>
                  {messagesError ? messagesError : 'No messages yet.'}
                </ThemedText>
              </View>
            )
          }
          ListFooterComponent={null}
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

      <BaseBottomSheetModal
        ref={bottomSheetModalRef}
        backdropComponent={renderBackdrop}
      >
        <BottomSheetView style={styles.sheet}>
          <View style={styles.sheetHeader}>
            <Image source={{ uri: selectedMessage?.sender === "me" ? myUser.avatarUrl : chatPartner.avatarUrl }} style={styles.sheetAvatar} />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <ThemedText style={styles.sheetName}>{selectedMessage?.sender === "me" ? "You" : chatPartner.name}</ThemedText>
              <Text style={{ fontSize: 13, color: secondaryText, fontFamily: 'Inter-Medium' }}>{selectedMessage?.timestamp}</Text>
            </View>
            <TouchableOpacity onPress={() => bottomSheetModalRef.current?.dismiss()} style={styles.closeBtn}>
              <X size={20} color={textColor} />
            </TouchableOpacity>
          </View>

          <View style={styles.sheetOptions}>
            <MenuOption icon={<Reply size={20} color={textColor} />} label="Reply" onPress={() => { if (selectedMessage) { setReplyingTo(selectedMessage); bottomSheetModalRef.current?.dismiss(); } }} />
            <MenuOption icon={<Copy size={20} color={textColor} />} label="Copy text" onPress={() => { bottomSheetModalRef.current?.dismiss(); }} />

            {selectedMessage?.sender === "me" && (
              <MenuOption icon={<Edit size={20} color={textColor} />} label="Edit message" onPress={() => { if (selectedMessage) { setEditingMessage(selectedMessage); bottomSheetModalRef.current?.dismiss(); } }} />
            )}

            <View style={[styles.div, { backgroundColor: borderCol }]} />
            <MenuOption icon={<Pin size={20} color={textColor} />} label="Pin to chat" onPress={() => bottomSheetModalRef.current?.dismiss()} />
            <View style={[styles.div, { backgroundColor: borderCol }]} />

            <MenuOption icon={<Trash2 size={20} color="#FF3B30" />} label="Delete for me" onPress={() => bottomSheetModalRef.current?.dismiss()} danger />
            <MenuOption icon={<Trash2 size={20} color="#FF3B30" />} label="Delete for everyone" onPress={() => bottomSheetModalRef.current?.dismiss()} danger />

            <View style={[styles.div, { backgroundColor: borderCol }]} />
            <MenuOption icon={<CheckCircle size={20} color={textColor} />} label="Select messages" onPress={() => {
              if (selectedMessage) {
                setIsSelectionMode(true);
                toggleSelection(selectedMessage.id);
                bottomSheetModalRef.current?.dismiss();
              }
            }} />
          </View>
          <View style={{ height: insets.bottom + 20 }} />
        </BottomSheetView>
      </BaseBottomSheetModal>

      {/* Fullscreen Image Viewer */}
      <Modal
        visible={!!fullscreenImage}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setFullscreenImage(null)}
      >
        <View style={styles.modalContainer}>
          <BlurView intensity={95} tint="light" style={StyleSheet.absoluteFill} />
          <TouchableOpacity
            style={[styles.modalCloseBtn, { top: insets.top + 10 }]}
            onPress={() => setFullscreenImage(null)}
          >
            <X size={28} color="#000" />
          </TouchableOpacity>

          {fullscreenImage && (
            <Image
              source={{ uri: fullscreenImage }}
              style={styles.modalImage}
              resizeMode="contain"
            />
          )}
        </View>
      </Modal>

      {/* Fullscreen Video Viewer */}
      <Modal
        visible={!!fullscreenVideo}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setFullscreenVideo(null)}
      >
        <View style={styles.modalContainer}>
          <BlurView intensity={95} tint="light" style={StyleSheet.absoluteFill} />
          <TouchableOpacity
            style={[styles.modalCloseBtn, { top: insets.top + 10 }]}
            onPress={() => setFullscreenVideo(null)}
          >
            <X size={28} color="#000" />
          </TouchableOpacity>

          {fullscreenVideo && (
            <VideoView 
              player={videoPlayer} 
              style={styles.modalVideo} 
              allowsFullscreen 
              allowsPictureInPicture 
            />
          )}
        </View>
      </Modal>
    </View>
  );
}

function MenuOption({ icon, label, onPress, danger }: any) {
  const { dark } = useTheme();
  return (
    <TouchableOpacity onPress={onPress} style={styles.option}>
      <View style={styles.optionIcon}>{icon}</View>
      <Text style={[styles.optionLabel, { color: dark ? '#FFF' : '#000' }, danger && { color: '#FF3B30' }]}>{label}</Text>
    </TouchableOpacity>
  );
}

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const styles = StyleSheet.create({
  main: { flex: 1 },
  header: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 1000,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(0,0,0,0.1)',
    display: 'none', // Handled by GlobalHeader
  },
  headerInner: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
  },
  headerIcon: { padding: 10 },
  headerCenter: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 4,
  },
  headerAvatar: { width: 36, height: 36, borderRadius: 18, backgroundColor: '#eee' },
  headerNames: { marginLeft: 10, flex: 1 },
  headerTitle: { fontSize: 16, fontFamily: 'Outfit-Bold', textTransform: 'uppercase', letterSpacing: 0.5 },
  headerSub: { fontSize: 11, fontFamily: 'Inter-Medium', opacity: 0.7 },
  statusRow: { flexDirection: 'row', alignItems: 'center', marginTop: 1 },
  onlineDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#34C759', marginRight: 5 },
  headerRight: { flexDirection: 'row', alignItems: 'center' },

  container: { flex: 1 },
  list: { paddingHorizontal: 16 },
  messageRow: { flexDirection: "row", alignItems: "flex-end" },
  messageRowMe: { justifyContent: "flex-end" },
  messageRowThem: { justifyContent: "flex-start" },

  messageContainer: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 20,
    minWidth: 50,
  },
  messageIn: { borderBottomLeftRadius: 4 },
  messageOut: { borderBottomRightRadius: 4 },

  messageText: { fontSize: 15, fontFamily: 'Inter-Regular', lineHeight: 20 },
  messageMeta: { flexDirection: 'row', alignItems: 'center', justifyContent: 'flex-end', marginTop: 4 },
  messageTime: { fontSize: 10, fontFamily: 'Inter-Medium' },

  typingContainer: { paddingBottom: 16, width: 80 },
  selectionCheck: { alignSelf: 'center' },

  quoteBox: {
    padding: 8,
    borderRadius: 8,
    borderLeftWidth: 3,
    marginBottom: 8,
  },
  quoteUser: { fontFamily: 'Inter-Bold', fontSize: 12, marginBottom: 2 },
  quoteText: { fontSize: 12, fontFamily: 'Inter-Regular' },

  sheet: { padding: 24 },
  sheetHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 24 },
  sheetAvatar: { width: 44, height: 44, borderRadius: 22 },
  sheetName: { fontSize: 17, fontFamily: 'Outfit-Bold' },
  closeBtn: { padding: 8, borderRadius: 20, backgroundColor: 'rgba(0,0,0,0.05)' },
  sheetOptions: { gap: 2 },
  option: { flexDirection: 'row', alignItems: 'center', paddingVertical: 14, paddingHorizontal: 4 },
  optionIcon: { width: 34 },
  optionLabel: { fontSize: 16, fontFamily: 'Inter-SemiBold' },
  div: { height: 1, marginVertical: 8, opacity: 0.1 },
  messageImageContainer: {
    width: 240,
    height: 180,
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: 8,
  },
  messageImage: {
    width: '100%',
    height: '100%',
  },
  blurCover: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  blurText: {
    fontSize: 12,
    fontFamily: 'Inter-SemiBold',
    marginTop: 8,
  },
  playIconContainer: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.1)',
  },
  modalContainer: {
    flex: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.4)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalImage: {
    width: SCREEN_WIDTH,
    height: SCREEN_WIDTH * 1.5,
  },
  modalVideo: {
    width: SCREEN_WIDTH,
    height: SCREEN_WIDTH * 0.56, // 16:9
  },
  modalCloseBtn: {
    position: 'absolute',
    right: 20,
    zIndex: 10,
    padding: 8,
    backgroundColor: 'rgba(0,0,0,0.05)',
    borderRadius: 25,
  },
});
