import React, {
  useMemo,
  useState,
  useRef,
  useEffect,
  useCallback,
} from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  LayoutAnimation,
  Platform,
  UIManager,
  Animated,
} from "react-native";
import Icon from "@expo/vector-icons/Ionicons";

// Android için LayoutAnimation'ı etkinleştir
if (
  Platform.OS === "android" &&
  UIManager.setLayoutAnimationEnabledExperimental
) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

export type DrawBoardProps = {
  drawnNumbers?: number[];
  onNumberPress?: (number: number) => void;
};

export function DrawBoard({
  drawnNumbers = [],
  onNumberPress,
}: DrawBoardProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const scaleAnims = useRef<{ [key: number]: Animated.Value }>({});
  const rotateAnim = useRef(new Animated.Value(0)).current;

  // Her numara için animasyon değeri oluştur
  const getScaleAnim = (num: number) => {
    if (!scaleAnims.current[num]) {
      scaleAnims.current[num] = new Animated.Value(1);
    }
    return scaleAnims.current[num];
  };

  const toggleExpand = () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setIsExpanded(!isExpanded);

    // Chevron animasyonu
    Animated.timing(rotateAnim, {
      toValue: isExpanded ? 0 : 1,
      duration: 300,
      useNativeDriver: true,
    }).start();
  };

  // Chevron rotasyon değeri
  const rotateInterpolate = rotateAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ["0deg", "180deg"],
  });

  // Şimdilik random renkler için - sonra logic ekleyeceğiz
  // useMemo ile memoize ediyoruz ki her render'da aynı sonuçları döndürsün
  const drawnNumbersSet = useMemo(() => {
    const drawn = new Set<number>();
    for (let i = 1; i <= 90; i++) {
      if (Math.random() > 0.4) {
        drawn.add(i);
      }
    }
    return drawn;
  }, []); // Boş dependency array ile sadece ilk render'da oluştur

  const isDrawn = useCallback(
    (num: number) => {
      return drawnNumbersSet.has(num);
    },
    [drawnNumbersSet]
  );

  // Accordion açıldığında çekilmiş numaraları animate et
  useEffect(() => {
    if (isExpanded) {
      // Tüm çekilmiş numaraları topla
      const allNumbers = Array.from({ length: 90 }, (_, i) => i + 1);
      const drawnNums = allNumbers.filter((num) => isDrawn(num));

      // Her çekilmiş numara için animasyon başlat
      drawnNums.forEach((num) => {
        const scaleAnim = getScaleAnim(num);
        const randomDelay = Math.random() * 500 + 50; // 50-150ms arası random

        // 1'den başlat (varsayılan)
        scaleAnim.setValue(1);

        // Random delay ile animasyonu başlat
        Animated.sequence([
          Animated.delay(randomDelay),
          Animated.timing(scaleAnim, {
            toValue: 1.3,
            duration: 200,
            useNativeDriver: true,
          }),
          Animated.timing(scaleAnim, {
            toValue: 1,
            duration: 150,
            useNativeDriver: true,
          }),
        ]).start();
      });
    } else {
      // Kapatıldığında tüm animasyonları 1'e sıfırla
      Object.values(scaleAnims.current).forEach((anim) => {
        anim.setValue(1);
      });
    }
  }, [isExpanded, isDrawn]);

  // Dikey olarak düzenle (10 satır x 9 sütun)
  const rows = useMemo(() => {
    const result: number[][] = [];
    for (let row = 0; row < 10; row++) {
      const rowNumbers: number[] = [];
      for (let col = 0; col < 9; col++) {
        rowNumbers.push(row + 1 + col * 10);
      }
      result.push(rowNumbers);
    }
    return result;
  }, []);

  return (
    <View style={styles.container}>
      {/* Accordion Header */}
      <Pressable style={styles.header} onPress={toggleExpand}>
        <View style={styles.headerLeft}>
          <Text style={styles.headerTitle}>Tabela</Text>
        </View>
        <Animated.View
          style={{
            transform: [{ rotate: rotateInterpolate }],
          }}
        >
          <Icon name="chevron-down" size={20} color="#666" />
        </Animated.View>
      </Pressable>

      {/* Collapsible Content */}
      {isExpanded && (
        <View style={styles.grid}>
          {rows.map((row, rowIndex) => (
            <View key={rowIndex} style={styles.row}>
              {row.map((num) => {
                const drawn = isDrawn(num);
                const scaleAnim = getScaleAnim(num);

                return (
                  <Animated.View
                    key={num}
                    style={[
                      styles.cellWrapper,
                      {
                        transform: [{ scale: scaleAnim }],
                      },
                    ]}
                  >
                    <Pressable
                      style={[
                        styles.cell,
                        drawn ? styles.drawnCell : styles.undrawnCell,
                      ]}
                      onPress={() => onNumberPress?.(num)}
                    >
                      <Text
                        style={[
                          styles.number,
                          drawn ? styles.drawnText : styles.undrawnText,
                        ]}
                      >
                        {num}
                      </Text>
                    </Pressable>
                  </Animated.View>
                );
              })}
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: "#FFFFFF",
    borderRadius: 8,
    marginBottom: 16,
    overflow: "hidden",
    shadowColor: "#000",
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    padding: 16,
    backgroundColor: "#FFFFFF",
  },
  headerLeft: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#333",
  },
  grid: {
    backgroundColor: "#FFFFFF",
    padding: 8,
    gap: 12,
  },
  row: {
    flexDirection: "row",
    gap: 12,
  },
  cellWrapper: {
    flex: 1,
  },
  cell: {
    width: "100%",
    aspectRatio: 1,
    borderRadius: 20,
    justifyContent: "center",
    alignItems: "center",
    shadowColor: "#000",
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  drawnCell: {
    backgroundColor: "#2196F3",
  },
  undrawnCell: {
    backgroundColor: "#FFFFFF",
  },
  number: {
    fontSize: 14,
    fontWeight: "bold",
  },
  drawnText: {
    color: "#FFFFFF",
  },
  undrawnText: {
    color: "#000000",
  },
});
