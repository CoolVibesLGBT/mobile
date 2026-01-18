import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { NativeTabs, Icon, Label, VectorIcon } from 'expo-router/unstable-native-tabs';
import { Platform } from 'react-native';

export default function TabLayout() {
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="Discover">
        <Label>Discover</Label>
        <Icon sf="house.fill" drawable="custom_android_drawable" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="Match">
        <Label>Match</Label>
        <Icon   src={<VectorIcon family={MaterialCommunityIcons} name="chart-bubble" />} />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="chat">
        <Label>Chat</Label>
        <Icon src={<VectorIcon family={MaterialCommunityIcons} name="chat" />} />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger  name="search" role="search">
        <Label>Search</Label>
        <Icon src={<VectorIcon family={MaterialCommunityIcons} name="foot-print" />} />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
