import { CheckIn } from '@/components/CheckInBar';
import { Stack } from 'expo-router';

export default function ChatDetailLayout() {
  return (
    <Stack>
       
      <Stack.Screen
        name="index"
        options={{
          headerShown: false
        }}
      />
        
    
    </Stack>
  );
}
