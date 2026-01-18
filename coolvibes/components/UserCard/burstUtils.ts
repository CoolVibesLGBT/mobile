import { BurstType, Particle, Confetti, Streak } from './types';
import { Heart, X, Shield, Star, Gift, Diamond } from 'lucide-react';

export const burstConfig = {
    like: {
        gradient: 'radial-gradient(circle, rgba(255,105,180,0.5) 0%, rgba(255,105,180,0) 70%)',
        Icon: Heart,
        color: 'text-pink-500',
    },
    dislike: {
        gradient: 'radial-gradient(circle, rgba(135,206,250,0.5) 0%, rgba(135,206,250,0) 70%)',
        Icon: X,
        color: 'text-sky-500',
    },
    block: {
        gradient: 'radial-gradient(circle, rgba(255,69,0,0.5) 0%, rgba(255,69,0,0) 70%)',
        Icon: Shield,
        color: 'text-red-500',
    },
};

const random = (min: number, max: number) => Math.random() * (max - min) + min;

export const createOverlayParticles = (type: BurstType, key: number): Particle[] => {
    const particleIcons = [Star, Diamond, Gift];
    return Array.from({ length: 12 }).map((_, i) => ({
        id: `particle-${key}-${i}`,
        x: random(-250, 250),
        y: random(-250, 250),
        rotate: random(-360, 360),
        Icon: particleIcons[i % particleIcons.length],
        color: burstConfig[type].color,
    }));
};

export const createOverlayConfetti = (type: BurstType, key: number): Confetti[] => {
    return Array.from({ length: 30 }).map((_, i) => ({
        id: `confetti-${key}-${i}`,
        x: random(-350, 350),
        y: random(-350, 350),
        size: random(8, 20),
        color: `hsl(${random(0, 360)}, 100%, 75%)`,
        rotate: random(-360, 360),
        driftX: random(-10, 10),
        driftY: random(-10, 10),
        duration: random(1.5, 2.5),
        delay: random(0, 1),
        shape: ['circle', 'square', 'triangle'][i % 3] as any,
    }));
};

export const createOverlayStreaks = (type: BurstType, key: number): Streak[] => {
    return Array.from({ length: 8 }).map((_, i) => ({
        id: `streak-${key}-${i}`,
        angle: random(0, 360),
        length: random(150, 250),
        delay: random(0, 0.5),
    }));
};
