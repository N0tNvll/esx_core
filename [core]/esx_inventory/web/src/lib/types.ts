export interface InventoryItem {
  type: "item_standard" | "item_account" | "item_weapon"
  name: string
  label: string
  description?: string
  image: string
  weight: number
  count: number
  slot: number
  usable: boolean
  canRemove: boolean
}

export interface StorageData {
  id: string
  label: string
  slots: number
  maxWeight: number
  items: InventoryItem[]
}

export interface NearbyPlayer {
  id: number
  name: string
  distance: number
}

export interface DragState {
  item: InventoryItem
  from: "left" | "right"
  x: number
  y: number
}

export type LocaleMap = Record<string, string>

export const DEFAULT_LOCALE: LocaleMap = {
  inventory: "Inventory",
  storage: "Storage",
  weight: "Weight",
  use: "Use",
  give: "Give",
  remove: "Throw",
  take: "Take",
  amount: "Amount",
  nearbyPlayers: "Nearby Players",
  noNearbyPlayers: "No nearby Players",
  addedToInventory: "Added to inventory",
  removedFromInventory: "Removed from inventory",
}

export const THEME_VARIABLES: Record<string, string> = {
  primary: "--brand-color",
  background: "--darkest-color",
  secondary: "--mid-color",
  accent: "--light-color",
}

export interface NotificationData {
  item: { name: string; label: string; image: string }
  amount: number
  added: boolean
  key: number
}

export const itemKey = (item: InventoryItem) => `${item.type}:${item.name}`
