import React from 'react';
import { Heart, X, Zap, Shield, MessageSquare } from 'lucide-react';
import { BurstType } from './types';

interface ActionBarProps {
    viewMode: 'card' | 'bubble';
    liked: boolean;
    disliked: boolean;
    blocked: boolean;
    onLikeToggle: () => void;
    onDislikeToggle: () => void;
    onBlockToggle: () => void;
    onOpenGiftSelector: () => void;
    onOpenQuickMessageSelector: () => void;
    baseButtonStyle: string;
    onTriggerOverlay: (type: BurstType) => void;
}

export const ActionBar: React.FC<ActionBarProps> = ({
    viewMode,
    liked,
    disliked,
    blocked,
    onLikeToggle,
    onDislikeToggle,
    onBlockToggle,
    onOpenGiftSelector,
    onOpenQuickMessageSelector,
    baseButtonStyle,
    onTriggerOverlay,
}) => {
    const handleLike = () => {
        onLikeToggle();
        onTriggerOverlay('like');
    };

    const handleDislike = () => {
        onDislikeToggle();
        onTriggerOverlay('dislike');
    };

    const handleBlock = () => {
        onBlockToggle();
        onTriggerOverlay('block');
    }

    return (
        <div className="flex items-center justify-center gap-2">
            <button onClick={handleLike} className={`${baseButtonStyle} rounded-full p-3`}>
                <Heart className={`w-6 h-6 ${liked ? 'text-red-500 fill-current' : ''}`} />
            </button>
            <button onClick={onOpenQuickMessageSelector} className={`${baseButtonStyle} rounded-full p-3`}>
                <MessageSquare className="w-6 h-6" />
            </button>
            <button onClick={handleDislike} className={`${baseButtonStyle} rounded-full p-3`}>
                <X className={`w-6 h-6 ${disliked ? 'text-blue-500' : ''}`} />
            </button>
            <button onClick={handleBlock} className={`${baseButtonStyle} rounded-full p-3`}>
                <Shield className={`w-6 h-6 ${blocked ? 'text-red-700' : ''}`} />
            </button>
        </div>
    );
};
