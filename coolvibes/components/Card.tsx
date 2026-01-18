import React, { useMemo, useState, useRef } from "react";
import { View, Text, StyleSheet, Pressable, Animated } from "react-native";
import { TombalaCard } from "../types/main";
import Icon from "@expo/vector-icons/Ionicons";

export type CardProps = TombalaCard & {
  soldCount: number;
  price: number;
  cinko1Prize: string;
  cinko2Prize: string;
  tombalaPrize: string;
  jackpotPrize: string;
  onNumberPress?: (number: number) => void;
  onBuyPress?: () => void;
  markedNumbers?: number[];
};

export function Card({
  no,
  soldCount,
  price,
  background,
  foreground,
  numbers,
  cinko1Prize,
  cinko2Prize,
  tombalaPrize,
  jackpotPrize,
  onNumberPress,
  onBuyPress,
  markedNumbers = [],
}: CardProps) {
  // numbers array'indeki 0'ları null'a çevir (TombalaCard formatından component formatına)
  const cardNumbers = useMemo(() => {
    return numbers.map((row) => row.map((num) => (num === 0 ? null : num)));
  }, [numbers]);

  const isMarked = (num: number | null) => {
    if (num === null) return false;
    return markedNumbers.includes(num);
  };

  // Heart animasyon state'leri
  const [isLiked, setIsLiked] = useState(false);
  const scaleAnim = useRef(new Animated.Value(1)).current;

  const handleHeartPress = () => {
    setIsLiked(!isLiked);

    // Pulse animasyonu
    Animated.sequence([
      Animated.timing(scaleAnim, {
        toValue: 1.4,
        duration: 150,
        useNativeDriver: true,
      }),
      Animated.timing(scaleAnim, {
        toValue: 1,
        duration: 150,
        useNativeDriver: true,
      }),
    ]).start();
  };

  return (
    <View style={[styles.cardContainer, { backgroundColor: background }]}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <Pressable onPress={handleHeartPress}>
            <Animated.View style={{ transform: [{ scale: scaleAnim }] }}>
              <Icon
                name={isLiked ? "heart" : "heart-outline"}
                size={16}
                color={isLiked ? foreground : "white"}
              />
            </Animated.View>
          </Pressable>
          {/* <View style={styles.heartIcon}>
            <Text style={styles.heartText}>♥</Text>
          </View> */}
          <Text style={styles.cardNoText}>No: {no}</Text>
          <View>
            <Text style={styles.dotText}>●</Text>
          </View>
          <Text style={styles.soldText}>{soldCount} adet satıldı</Text>
        </View>
        {/* <Pressable style={styles.buyButton} onPress={onBuyPress}>
          <Text style={styles.buyButtonText}>SATIN AL</Text>
          <Text style={styles.priceText}>{price} ₺</Text>
        </Pressable> */}
      </View>

      {/* Grid */}
      <View style={styles.gridContainer}>
        {cardNumbers.map((row, rowIndex) => (
          <View key={rowIndex} style={styles.row}>
            {row.map((num, colIndex) => (
              <View
                key={`${rowIndex}-${colIndex}`}
                style={[
                  styles.cell,
                  num === null && [
                    styles.emptyCell,
                    {
                      backgroundColor: `${foreground}33`,
                    },
                  ],
                ]}
              >
                {num !== null && (
                  <Pressable
                    onPress={() => onNumberPress?.(num)}
                    style={[
                      styles.numberButton,
                      isMarked(num) && styles.markedButton,
                    ]}
                  >
                    <Text
                      style={[
                        styles.numberText,
                        isMarked(num) && styles.markedText,
                      ]}
                    >
                      {num}
                    </Text>
                  </Pressable>
                )}
              </View>
            ))}
          </View>
        ))}
      </View>

      {/* Footer */}
      <View style={styles.footer}>
        <View style={styles.prizeSection}>
          <Text style={styles.prizeLabel}>1.Çinko:</Text>
          <Text style={styles.prizeAmount}>{cinko1Prize}</Text>
        </View>
        <View style={styles.prizeSection}>
          <Text style={styles.prizeLabel}>2.Çinko:</Text>
          <Text style={styles.prizeAmount}>{cinko2Prize}</Text>
        </View>
        <View style={styles.prizeSection}>
          <Text style={styles.prizeLabel}>Tombala:</Text>
          <Text style={styles.prizeAmount}>{tombalaPrize}</Text>
        </View>
        <View style={styles.prizeSection}>
          <Text style={styles.prizeLabel}>Jackpot:</Text>
          <Text style={styles.prizeAmount}>{jackpotPrize}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  cardContainer: {
    borderRadius: 4,
    padding: 8,
    marginBottom: 16,
    shadowColor: "#000",
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 3,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
  headerLeft: {
    flexDirection: "row",
    alignItems: "center",
    flex: 1,
    gap: 8,
  },
  heartIcon: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 8,
  },
  heartText: {
    color: "#fff",
    fontSize: 18,
  },
  cardNoText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "bold",
    marginRight: 6,
  },
  dotSeparator: {
    marginHorizontal: 6,
  },
  dotText: {
    color: "#fff",
    fontSize: 8,
  },
  soldText: {
    color: "#fff",
    fontSize: 14,
  },
  buyButton: {
    backgroundColor: "#FFD700",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  buyButtonText: {
    color: "#000",
    fontSize: 14,
    fontWeight: "bold",
  },
  priceText: {
    color: "#000",
    fontSize: 14,
    fontWeight: "bold",
  },
  gridContainer: {
    backgroundColor: "rgba(0, 0, 0, 0.1)",
    borderRadius: 4,
    padding: 8,
    marginBottom: 6,
  },
  row: {
    flexDirection: "row",
    marginBottom: 4,
  },
  cell: {
    flex: 1,
    aspectRatio: 1.3,
    marginHorizontal: 2,
  },
  emptyCell: {
    borderRadius: 4,
  },
  numberButton: {
    width: "100%",
    height: "100%",
    backgroundColor: "#fff",
    borderRadius: 4,
    justifyContent: "center",
    alignItems: "center",
  },
  markedButton: {
    backgroundColor: "#FFD700",
  },
  numberText: {
    fontSize: 14,
    fontWeight: "bold",
    color: "#000",
  },
  markedText: {
    color: "#000",
  },
  footer: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingTop: 8,
  },
  prizeSection: {
    flex: 1,
    alignItems: "center",
  },
  prizeLabel: {
    color: "#fff",
    fontSize: 11,
    fontWeight: "600",
    marginBottom: 2,
  },
  prizeAmount: {
    color: "#fff",
    fontSize: 13,
    fontWeight: "bold",
  },
});
