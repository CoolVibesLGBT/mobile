import { Icon as LucideIcon } from 'lucide-react';

export type BurstType = 'like' | 'dislike' | 'block';

export interface BurstOverlayState {
    type: BurstType;
    key: number;
    particles: Particle[];
    confetti: Confetti[];
    streaks: Streak[];
}

export interface Particle {
    id: string;
    x: number;
    y: number;
    rotate: number;
    Icon: LucideIcon;
    color: string;
}

export interface Confetti {
    id: string;
    x: number;
    y: number;
    size: number;
    color: string;
    rotate: number;
    driftX: number;
    driftY: number;
    duration: number;
    delay: number;
    shape: 'circle' | 'square' | 'triangle';
}

export interface Streak {
    id: string;
    angle: number;
    length: number;
    delay: number;
}
