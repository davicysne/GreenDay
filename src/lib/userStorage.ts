const normalizeUserId = (userId?: string | null) => userId || 'demo-user'

export const userStorageKey = (userId: string | null | undefined, key: string) => `gd:${normalizeUserId(userId)}:${key}`

export function getUserItem<T>(userId: string | null | undefined, key: string, fallback: T): T {
  const scoped = localStorage.getItem(userStorageKey(userId, key))
  if (!scoped) return fallback
  try {
    return JSON.parse(scoped) as T
  } catch {
    return fallback
  }
}

export function setUserItem<T>(userId: string | null | undefined, key: string, value: T) {
  localStorage.setItem(userStorageKey(userId, key), JSON.stringify(value))
}

export function removeUserItem(userId: string | null | undefined, key: string) {
  localStorage.removeItem(userStorageKey(userId, key))
}
