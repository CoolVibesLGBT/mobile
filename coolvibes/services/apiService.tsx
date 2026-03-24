import { Actions, ActionType } from './actions';
import httpClient from './httpClient';
import { reportAppError } from '@/helpers/errorReporter';

interface ApiRequestOptions {
  method?: 'GET' | 'POST';
  params?: Record<string, any>;
  body?: Record<string, any> | FormData; // FormData desteği eklendi
  timeout?: number;
  suppressGlobalError?: boolean;
}

const shouldReportApiError = (action: ActionType, error: any) => {
  const hasResponse = Boolean(error?.response);
  const message = String(error?.message || '');
  const isNetworkError = !hasResponse && message.toLowerCase().includes('network error');

  if (action === Actions.CMD_AUTH_USER_INFO && isNetworkError) {
    return false;
  }

  return true;
};

export class ApiService {

  async call<T = any>(action: ActionType, options: ApiRequestOptions = {}): Promise<T> {
    const method = options.method ?? 'GET';

    console.log(`[API REQUEST] Action: ${action} | Method: ${method}`, options.params || options.body || '');

    try {
      let response;
      if (method === 'GET') {
        response = await httpClient.get('/', {
          params: { action, ...options.params },
          timeout: options.timeout,
        });
      } else {
        // POST
        if (options.body instanceof FormData) {
          response = await httpClient.post('/', options.body, {
            timeout: options.timeout,
          });
        } else {
          const formData = new FormData();
          formData.append('action', action);

          if (options.body && typeof options.body === 'object') {
            for (const key in options.body) {
              if (Object.prototype.hasOwnProperty.call(options.body, key)) {
                const val = (options.body as any)[key];
                if (val !== undefined && val !== null) {
                  const isFile = (typeof File !== 'undefined') && (val instanceof File);
                  const isBlob = (typeof Blob !== 'undefined') && (val instanceof Blob);
                  if (isFile || isBlob) {
                    formData.append(key, val);
                    continue;
                  }

                  if (Array.isArray(val)) {
                    const items = val.filter((item: any) => item !== undefined && item !== null);
                    const isFileLikeItem = (item: any) => {
                      const itemIsFile = (typeof File !== 'undefined') && (item instanceof File);
                      const itemIsBlob = (typeof Blob !== 'undefined') && (item instanceof Blob);
                      return itemIsFile || itemIsBlob || (typeof item === 'object' && item !== null && 'uri' in item);
                    };

                    const isFileArray = items.length > 0 && items.every(isFileLikeItem);
                    if (isFileArray) {
                      items.forEach((item: any) => {
                        const itemIsFile = (typeof File !== 'undefined') && (item instanceof File);
                        const itemIsBlob = (typeof Blob !== 'undefined') && (item instanceof Blob);
                        if (itemIsFile || itemIsBlob) {
                          formData.append(key, item);
                          return;
                        }
                        if (typeof item === 'object' && item !== null && 'uri' in item) {
                          formData.append(key, item as any);
                        }
                      });
                    } else {
                      formData.append(key, JSON.stringify(val));
                    }
                    continue;
                  }

                  if (typeof val === 'object' && val !== null && 'uri' in val) {
                    formData.append(key, val as any);
                    continue;
                  }

                  if (typeof val === 'object' && val !== null) {
                    formData.append(key, JSON.stringify(val));
                    continue;
                  }

                  formData.append(key, val.toString());
                }
              }
            }
          }
          response = await httpClient.post('/', formData, {
            timeout: options.timeout,
          });
        }
      }

      console.log(`[API RESPONSE] Action: ${action}`, response.data);
      return response.data as T;
    } catch (error: any) {
      if (!options.suppressGlobalError && shouldReportApiError(action, error)) {
        reportAppError(error, {
          source: 'api',
          action,
          extra: {
            status: error?.response?.status,
            data: error?.response?.data,
            message: error?.message,
          },
        });
      }
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

  async fetchMessages(chatId: string) {
    return this.call(Actions.CMD_FETCH_MESSAGES, {
      method: 'POST',
      body: { chat_id: chatId },
    });
  }

async markMessagesRead(params: { chat_id: string; message_ids: string[] }) {
  const uniqueMessageIds = Array.from(
    new Set((params.message_ids || []).map((messageId) => String(messageId || '')).filter(Boolean))
  );

  if (!params.chat_id || uniqueMessageIds.length === 0) {
    return { success: true };
  }

  const results = await Promise.allSettled(
    uniqueMessageIds.map((messageId) =>
      this.call(Actions.CMD_CHAT_MESSAGE_READ, {
        method: 'POST',
        body: {
          chat_id: params.chat_id,
          message_id: messageId,
        },
        suppressGlobalError: true,
      })
    )
  );

  const rejected = results.filter((result) => result.status === 'rejected');
  if (rejected.length === uniqueMessageIds.length) {
    throw (rejected[0] as PromiseRejectedResult).reason;
  }

  return { success: true };
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

  async fetchTimeline({ limit = 10, cursor = "" }: { limit?: number; cursor?: string }) {
    return this.call(Actions.POST_TIMELINE, {
      method: "POST",
      body: { limit, cursor }, // doğru değişkenler gönderiliyor
    });
  }

  async fetchPost(postId: string) {
    return this.call(Actions.POST_FETCH, {
      method: 'POST',
      body: { post_id: postId },
    });
  }

  async fetchJobOffers({ limit = 20, cursor }: { limit?: number; cursor?: string | null }) {
    const body: Record<string, any> = { limit };
    if (cursor) body.cursor = cursor;
    return this.call(Actions.CMD_FETCH_JOB_OFFERS, {
      method: 'POST',
      body,
    });
  }

  async fetchJobSearches({ limit = 20, cursor }: { limit?: number; cursor?: string | null }) {
    const body: Record<string, any> = { limit };
    if (cursor) body.cursor = cursor;
    return this.call(Actions.CMD_FETCH_JOB_SEARCH, {
      method: 'POST',
      body,
    });
  }

  async fetchClassified(postId: string) {
    return this.call(Actions.CMD_CLASSIFIEDS_FETCH, {
      method: 'POST',
      body: { post_id: postId },
    });
  }

  async createPost(payload: Record<string, any>) {
    return this.call(Actions.POST_CREATE, {
      method: 'POST',
      body: payload,
      timeout: 0,
      suppressGlobalError: true,
    });
  }

  async fetchVibes(params: { limit?: number; cursor?: string }) {
    return this.call(Actions.POST_VIBES, { method: 'POST', body: params });
  }

  async fetchCheckIns(params: { limit?: number; cursor?: string }) {
    return this.call(Actions.CMD_USER_CHECK_IN_FETCH, { method: 'POST', body: params });
  }

  async fetchUserEngagements(payload: Record<string, any> = {}) {
    return this.call(Actions.CMD_USER_FETCH_ENGAGEMENTS, {
      method: 'POST',
      body: payload,
    });
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

  async fetchPlace(publicId: string) {
    return this.call(Actions.CMD_PLACE_FETCH, {
      method: 'POST',
      body: { public_id: publicId },
    });
  }

  async fetchNearbyPlaces(latitude: number | null, longitude: number | null, cursor: string | null = null, distance: string | null = null, limit: number | null = null) {
    return this.call(Actions.CMD_PLACE_FETCH, {
      method: 'POST',
      body: { latitude, longitude, cursor, distance, limit },
    });
  }

  async fetchNearbyUsers(latitude: number | null, longitude: number | null, cursor: any = null, limit: number | null = null) {
    const nextCursor =
      cursor && typeof cursor === 'object'
        ? cursor.next ?? cursor.next_cursor ?? cursor.nextCursor ?? cursor.cursor ?? null
        : cursor;
    const distance =
      cursor && typeof cursor === 'object'
        ? cursor.distance ?? null
        : null;

    const body: Record<string, any> = {};

    if (typeof latitude === 'number' && Number.isFinite(latitude)) {
      body.latitude = latitude;
    }

    if (typeof longitude === 'number' && Number.isFinite(longitude)) {
      body.longitude = longitude;
    }

    if (nextCursor !== null && nextCursor !== undefined && nextCursor !== '') {
      body.cursor = nextCursor;
    }

    if (distance !== null && distance !== undefined && distance !== '') {
      body.distance = distance;
    }

    if (typeof limit === 'number' && Number.isFinite(limit)) {
      body.limit = limit;
    }

    return this.call(Actions.CMD_USER_FETCH_NEARBY_USERS, {
      method: 'POST',
      body,
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
