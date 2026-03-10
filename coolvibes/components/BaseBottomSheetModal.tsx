import React, { forwardRef, ReactNode, useMemo } from 'react';
import { StyleProp, ViewStyle, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  BottomSheetModal as GorhomBottomSheetModal,
  BottomSheetModalProps,
} from '@gorhom/bottom-sheet';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { Colors } from '@/constants/Colors';

type BaseBottomSheetModalProps = BottomSheetModalProps & {
  children: ReactNode;
  handleIndicatorStyle?: StyleProp<ViewStyle>;
};

const BaseBottomSheetModal = forwardRef<GorhomBottomSheetModal, BaseBottomSheetModalProps>(({
  children,
  containerStyle,
  handleIndicatorStyle,
  index = 0,
  enableDynamicSizing = true,
  enablePanDownToClose = true,
  ...rest
}, ref) => {
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme() ?? 'light';
  const palette = Colors[colorScheme];
  const indicatorStyle = useMemo(
    () => StyleSheet.flatten([{ backgroundColor: palette.icon, width: 40 }, handleIndicatorStyle]),
    [handleIndicatorStyle, palette.icon]
  );

  return (
    <GorhomBottomSheetModal
      ref={ref}
      index={index}
      enableDynamicSizing={enableDynamicSizing}
      enablePanDownToClose={enablePanDownToClose}
      handleIndicatorStyle={indicatorStyle}
      containerStyle={[{ marginTop: insets.top }, containerStyle]}
      {...rest}
    >
      {children}
    </GorhomBottomSheetModal>
  );
});

BaseBottomSheetModal.displayName = 'BaseBottomSheetModal';

export default BaseBottomSheetModal;
