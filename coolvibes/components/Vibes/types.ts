export type VibeMediaType = 'image' | 'video';

export interface VibeAuthor {
  id?: string;
  public_id?: string;
  username?: string;
  displayname?: string;
  date_of_birth?: string;
  avatar?: unknown;
  bio?: string;
}

export interface VibeItemData {
  id: string;
  mediaUrl: string;
  mediaType: VibeMediaType;
  posterUrl?: string;
  username: string;
  dateOfBirth?: string;
  avatar: string;
  description: string;
  bio?: string;
  author: VibeAuthor;
}

export type BurstType = 'like' | 'block';
