import { Actions, ActionType } from './actions';
import httpClient from './httpClient';

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
}

export const api = new ApiService();