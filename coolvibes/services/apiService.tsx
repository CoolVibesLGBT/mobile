import { Actions, ActionType } from './actions';
import httpClient from './httpClient';
import { reportAppError } from '@/helpers/errorReporter';

interface ApiRequestOptions {
  method?: 'GET' | 'POST';
  params?: Record<string, any>;
  body?: Record<string, any> | FormData; // FormData desteği eklendi
}

export class ApiService {

  async call<T = any>(action: ActionType, options: ApiRequestOptions = {}): Promise<T> {
    const method = options.method ?? 'GET';

    console.log(`[API REQUEST] Action: ${action} | Method: ${method}`, options.params || options.body || '');

    try {
      let response;
      if (method === 'GET') {
        response = await httpClient.get('/', {
          params: { action, ...options.params },
        });
      } else {
        // POST
        if (options.body instanceof FormData) {
          response = await httpClient.post('/', options.body);
        } else {
          const formData = new FormData();
          formData.append('action', action);

          if (options.body && typeof options.body === 'object') {
            for (const key in options.body) {
              if (Object.prototype.hasOwnProperty.call(options.body, key)) {
                const val = (options.body as any)[key];
                if (val !== undefined && val !== null) {
                  if (val instanceof File || val instanceof Blob) {
                    formData.append(key, val);
                  } else if (typeof val === 'object' && val !== null && 'uri' in val) {
                    formData.append(key, val as any);
                  } else if (Array.isArray(val) || (typeof val === 'object' && val !== null)) {
                    formData.append(key, JSON.stringify(val));
                  } else {
                    formData.append(key, val.toString());
                  }
                }
              }
            }
          }
          response = await httpClient.post('/', formData);
        }
      }

      console.log(`[API RESPONSE] Action: ${action}`, response.data);
      return response.data as T;
    } catch (error: any) {
      reportAppError(error, {
        source: 'api',
        action,
        extra: {
          status: error?.response?.status,
          data: error?.response?.data,
          message: error?.message,
        },
      });
      console.error(`[API ERROR] Action: ${action}`, error.response?.data || error.message);
      throw error;
    }
  }



  async uploadFile(file: Blob | File) {
    const formData = new FormData();
    formData.append('file', file);

    return this.call(Actions.CMD_USER_UPLOAD_AVATAR, {
      method: 'POST',
      body: formData,
    });
  }

  async login(credentials: { nickname: string; password: string }) {
    return this.call(Actions.AUTH_LOGIN, { method: 'POST', body: credentials });
  }

  async register(data: { name: string; nickname: string; password: string; referralCode?: string, domain: string }) {
    return this.call(Actions.AUTH_REGISTER, { method: 'POST', body: data });
  }

  async fetchChats(params: { limit?: number; cursor?: string }) {
    return this.call(Actions.CMD_FETCH_CHATS, { method: 'POST', body: params });
  }

  async fetchMessages(params: { chat_id: string; limit?: number; cursor?: string }) {
    return this.call(Actions.CMD_FETCH_MESSAGES, { method: 'POST', body: params });
  }

    async fetchStories(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_FETCH_STORIES, {
      method: "POST",
      body: payload,
    });
  }

  async uploadStory(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPLOAD_STORY, {
      method: "POST",
      body: payload,
    });
  }
  
  async fetchProfile(username?: string) {
    return this.call(Actions.USER_FETCH_PROFILE, {
      method: 'GET',
      params: username ? { username } : {},
    });
  }

  async fetchProfileByNickname(nickname: string) {
    return this.call(Actions.USER_FETCH_PROFILE, {
      method: 'POST',
      body: { nickname },
    });
  }

  async fetchVibes(params: { limit?: number; cursor?: string }) {
    return this.call(Actions.POST_VIBES, { method: 'POST', body: params });
  }

  async fetchCheckIns(params: { limit?: number; cursor?: string }) {
    return this.call(Actions.CMD_USER_CHECK_IN_FETCH, { method: 'POST', body: params });
  }

  async sendMessage(chatId: string, content: string) {
    return this.call(Actions.CMD_SEND_MESSAGE, {
      method: 'POST',
      body: { chat_id: chatId, content },
    });
  }

  async createChat(participantIds: string[]) {
    return this.call(Actions.CMD_CHAT_CREATE, {
      method: 'POST',
      body: { participant_ids: participantIds },
    });
  }

  async handlePostLike(postId: string) {
    return this.call(Actions.CMD_POST_LIKE, {
      method: 'POST',
      body: { post_id: postId },
    });
  }

  async pinMessage(chatId: string, messageId: string) {
    return this.call(Actions.CMD_PIN_MESSAGE, {
      method: 'POST',
      body: { message_id: messageId, chat_id: chatId },
    });
  }

  async unpinMessage(chatId: string, messageId: string) {
    return this.call(Actions.CMD_UNPIN_MESSAGE, {
      method: 'POST',
      body: { message_id: messageId, chat_id: chatId },
    });
  }

  async deleteMessageFromChatForUser(chatId: string, messageId: string) {
    return this.call(Actions.CMD_DELETE_MESSAGE_FOR_USER, {
      method: 'POST',
      body: { message_id: messageId, chat_id: chatId },
    });
  }

  async deleteMessageFromChatForAll(chatId: string, messageId: string) {
    return this.call(Actions.CMD_DELETE_MESSAGE_FOR_ALL, {
      method: 'POST',
      body: { message_id: messageId, chat_id: chatId },
    });
  }



  async getAuthUserInfo() {
    return this.call(Actions.CMD_AUTH_USER_INFO, {
      method: "POST",
      body: {},
    });
  }

  async updateProfile(userData: Record<string, any>) {
    return this.call(Actions.CMD_UPDATE_USER_PROFILE, {
      method: "POST",
      body: userData,
    });
  }

  async updatePassword(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPDATE_PASSWORD, {
      method: "POST",
      body: payload,
    });
  }

  async updateIdentify(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPDATE_IDENTIFY, {
      method: "POST",
      body: payload,
    });
  }

  async updateAttribute(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPDATE_ATTRIBUTE, {
      method: "POST",
      body: payload,
    });
  }

  async updateInterest(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPDATE_INTEREST, {
      method: "POST",
      body: payload,
    });
  }

  async toggleBlockUser(blockedId: string) {
    return this.call(Actions.CMD_USER_TOGGLE_BLOCK, {
      method: 'POST',
      body: { blocked_id: blockedId },
    });
  }

  async toggleFollow(followeeId: string) {
    return this.call(Actions.CMD_USER_TOGGLE_FOLLOW, {
      method: 'POST',
      body: { followee_id: followeeId },
    });
  }

  async updateFantasy(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPDATE_FANTASY, {
      method: "POST",
      body: payload,
    });
  }

  async updatePreferences(id: string, bit_index: number, enabled: boolean) {
    return this.call(Actions.CMD_USER_UPDATE_PREFERENCES, {
      method: "POST",
      body: { id, bit_index, enabled },
    });
  }

  async uploadAvatar(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPLOAD_AVATAR, {
      method: "POST",
      body: payload,
    });
  }

  async uploadCover(payload: Record<string, any>) {
    return this.call(Actions.CMD_USER_UPLOAD_COVER, {
      method: "POST",
      body: payload,
    });
  }


  // Diğer metodlar da benzer şekilde

  async fetchNearbyPlaces(latitude: number | null, longitude: number | null, cursor: string | null = null, limit: number | null = null) {
    return this.call(Actions.CMD_PLACE_FETCH, {
      method: 'POST',
      body: { latitude: latitude, longitude: longitude, cursor: cursor, limit: limit },
    });
  }

  async fetchNearbyUsers(latitude: number | null, longitude: number | null, cursor: string | null = null, limit: number | null = null) {
    return this.call(Actions.CMD_USER_FETCH_NEARBY_USERS, {
      method: 'POST',
      body: { latitude: latitude, longitude: longitude, cursor: cursor, limit: limit },
    });
  }

  async createMatch(publicId: string | number, reaction: 'like' | 'dislike' | 'superlike' | 'favorite' | 'bookmark') {
    return this.call(Actions.CMD_MATCH_CREATE, {
      method: 'POST',
      body: { public_id: publicId, reaction },
    });
  }
}

export const api = new ApiService();
