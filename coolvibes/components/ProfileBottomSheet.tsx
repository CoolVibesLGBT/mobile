import React, { forwardRef, useMemo, useEffect, useRef, useState } from 'react'
import type { BottomSheetModal } from '@gorhom/bottom-sheet'
import { useTheme } from '@react-navigation/native'

import BaseBottomSheetModal from '@/components/BaseBottomSheetModal'
import FullProfileView from '@/components/FullProfileView'
import { normalizeProfileUser } from '@/helpers/profile'
import { api } from '@/services/apiService'

type ProfileBottomSheetProps = {
  user?: any
  fallback?: {
    id?: string
    name?: string
    username?: string
    avatar?: string
  }
  isMe?: boolean
  onMessage?: () => void
  onFollow?: () => void
  onEdit?: () => void
  onWallet?: () => void
  onDismiss?: () => void
  backdropComponent?: (props: any) => JSX.Element
  snapPoints?: string[]
}

const ProfileBottomSheet = forwardRef<BottomSheetModal, ProfileBottomSheetProps>(({
  user,
  fallback,
  isMe,
  onMessage,
  onFollow,
  onEdit,
  onWallet,
  onDismiss,
  backdropComponent,
  snapPoints = ['92%'],
}, ref) => {
  const { dark } = useTheme()
  const [fetchedUser, setFetchedUser] = useState<any | null>(null)
  const lastFetchKeyRef = useRef<string | null>(null)

  const normalizeName = (value?: string) => (typeof value === 'string' ? value.trim() : '')
  const isGenericName = (value: string) => {
    const lower = value.toLowerCase()
    return lower === 'chat' || lower === 'user' || lower === 'unknown' || lower === 'me'
  }
  const isValidUsername = (value?: string) => {
    const name = normalizeName(value)
    if (!name) return false
    if (isGenericName(name)) return false
    if (/\s/.test(name)) return false
    return true
  }
  const isValidNickname = (value?: string) => {
    const name = normalizeName(value)
    if (!name) return false
    if (isGenericName(name)) return false
    return true
  }

  const fetchUsername = isValidUsername(user?.username || user?.raw?.username || fallback?.username)
    ? normalizeName(user?.username || user?.raw?.username || fallback?.username)
    : null

  const fetchNickname = !fetchUsername && isValidNickname(user?.nickname || user?.raw?.nickname)
    ? normalizeName(user?.nickname || user?.raw?.nickname)
    : null

  const identityKey =
    user?.id ||
    user?.public_id ||
    user?.username ||
    user?.raw?.id ||
    user?.raw?.public_id ||
    user?.raw?.username ||
    fallback?.id ||
    fallback?.username ||
    null

  useEffect(() => {
    setFetchedUser(null)
    lastFetchKeyRef.current = null
  }, [identityKey])

  useEffect(() => {
    const fetchKey = fetchUsername || fetchNickname
    if (!fetchKey || lastFetchKeyRef.current === fetchKey) return
    lastFetchKeyRef.current = fetchKey
    let isActive = true

    const run = async () => {
      try {
        const response = fetchUsername
          ? await api.fetchProfile(fetchUsername)
          : await api.fetchProfileByNickname(fetchNickname as string)
        const payload = (response as any)?.data ?? response
        const profile =
          payload?.user ||
          payload?.data?.user ||
          payload?.profile ||
          payload?.data?.profile ||
          payload?.data ||
          payload
        if (isActive && profile) setFetchedUser(profile)
      } catch {
        // ignore fetch errors; fallback to provided data
      }
    }

    run()
    return () => {
      isActive = false
    }
  }, [fetchUsername, fetchNickname])

  const profileUser = useMemo(() => normalizeProfileUser(fetchedUser ?? user, fallback), [fetchedUser, user, fallback])

  return (
    <BaseBottomSheetModal
      ref={ref}
      index={0}
      snapPoints={snapPoints}
      enableDynamicSizing={false}
      backdropComponent={backdropComponent}
      onDismiss={onDismiss}
      backgroundStyle={{ backgroundColor: dark ? '#000' : '#FFF' }}
      handleIndicatorStyle={{ backgroundColor: dark ? '#333' : '#E0E0E0' }}
    >
      {profileUser && (
        <FullProfileView
          user={profileUser}
          isMe={isMe}
          useBottomSheetScroll
          onMessage={onMessage}
          onFollow={onFollow}
          onEdit={onEdit}
          onWallet={onWallet}
        />
      )}
    </BaseBottomSheetModal>
  )
})

ProfileBottomSheet.displayName = 'ProfileBottomSheet'

export default ProfileBottomSheet
