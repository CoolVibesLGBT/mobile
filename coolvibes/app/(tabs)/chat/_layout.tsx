import { Stack } from 'expo-router';

export default function ChatLayout() {
  return (
    <Stack>
      <Stack.Screen
        name="index"
        options={{
          title: 'Chats',
          headerShown:false,
        }}
    
      />

      <Stack.Screen
        name="[chatId]"
        options={{
        headerShown:false,
        navigationBarHidden: false,
          headerBackTitle: 'Back',
          title: '',
        }}
      />

      <Stack.Screen
        name="info"
        options={{
          title: 'Chat Info',
        }}
      />
    </Stack>
  );
}