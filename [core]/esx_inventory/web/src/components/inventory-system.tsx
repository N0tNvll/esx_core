"use client"

import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { Package, User } from "lucide-react"
import Inventory from "./inventory"
import ActionPanel from "./action-panel"
import DragGhost from "./drag-ghost"
import ItemNotification from "./item-notification"
import { fetchNui } from "@/lib/nui"
import { useDrag } from "@/hooks/use-drag"
import {
  DEFAULT_LOCALE,
  THEME_VARIABLES,
  itemKey,
  type InventoryItem,
  type LocaleMap,
  type NearbyPlayer,
  type NotificationData,
  type StorageData,
} from "@/lib/types"

export default function InventorySystem() {
  const [visible, setVisible] = useState(false)
  const [locale, setLocale] = useState<LocaleMap>(DEFAULT_LOCALE)
  const [hotbarSlots, setHotbarSlots] = useState(5)
  const [items, setItems] = useState<InventoryItem[]>([])
  const [slotCount, setSlotCount] = useState(25)
  const [maxWeight, setMaxWeight] = useState(0)
  const [storage, setStorage] = useState<StorageData | null>(null)
  const [selectedLeft, setSelectedLeft] = useState<string | null>(null)
  const [selectedRight, setSelectedRight] = useState<string | null>(null)
  const [amount, setAmount] = useState<number>(1)
  const [showPlayerList, setShowPlayerList] = useState(false)
  const [nearbyPlayers, setNearbyPlayers] = useState<NearbyPlayer[]>([])
  const [notification, setNotification] = useState<NotificationData | null>(null)

  const itemsRef = useRef<InventoryItem[]>([])
  itemsRef.current = items

  const t = useCallback((key: string) => locale[key] ?? DEFAULT_LOCALE[key] ?? key, [locale])

  const resetView = useCallback(() => {
    setVisible(false)
    setStorage(null)
    setSelectedLeft(null)
    setSelectedRight(null)
    setShowPlayerList(false)
  }, [])

  const closeInventory = useCallback(() => {
    resetView()
    fetchNui("close")
  }, [resetView])

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const data = event.data
      if (!data || typeof data !== "object") return

      if (data.action === "open") {
        if (data.locale) setLocale({ ...DEFAULT_LOCALE, ...data.locale })
        if (typeof data.hotbarSlots === "number") setHotbarSlots(data.hotbarSlots)
        if (data.theme) {
          for (const [key, cssVar] of Object.entries(THEME_VARIABLES)) {
            const value = data.theme[key]
            if (typeof value === "string" && value !== "") {
              document.documentElement.style.setProperty(cssVar, value)
            }
          }
        }
        setVisible(true)
      } else if (data.action === "state") {
        setItems(Array.isArray(data.items) ? data.items : [])
        if (typeof data.slotCount === "number") setSlotCount(data.slotCount)
        if (typeof data.maxWeight === "number") setMaxWeight(data.maxWeight)
        setStorage(data.storage && typeof data.storage === "object" ? data.storage : null)
      } else if (data.action === "close") {
        resetView()
      } else if (data.action === "notify" && data.item) {
        setNotification({ item: data.item, amount: data.amount ?? 1, added: data.added !== false, key: Date.now() })
      }
    }

    const onError = (event: ErrorEvent) => {
      fetchNui("uiError", { message: event.message, source: event.filename + ":" + event.lineno })
    }
    const onRejection = (event: PromiseRejectionEvent) => {
      fetchNui("uiError", { message: String(event.reason) })
    }

    window.addEventListener("message", onMessage)
    window.addEventListener("error", onError)
    window.addEventListener("unhandledrejection", onRejection)
    return () => {
      window.removeEventListener("message", onMessage)
      window.removeEventListener("error", onError)
      window.removeEventListener("unhandledrejection", onRejection)
    }
  }, [resetView])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!visible) return

      const target = event.target as HTMLElement | null
      const isTyping = target !== null && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")

      if (event.key === "Escape" || (event.key === "Backspace" && !isTyping)) {
        closeInventory()
      }
    }

    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [visible, closeInventory])

  const selectedItem = useMemo(
    () => items.find((item) => itemKey(item) === selectedLeft) ?? null,
    [items, selectedLeft]
  )

  const clampedAmount = useCallback(
    (item: InventoryItem) => Math.min(Math.max(1, Math.floor(amount) || 1), item.count),
    [amount]
  )

  const saveSlots = useCallback((updated: InventoryItem[]) => {
    const slots: Record<string, number> = {}
    for (const item of updated) slots[itemKey(item)] = item.slot
    fetchNui("saveSlots", { slots })
  }, [])

  const handleMoveLeft = useCallback(
    (item: InventoryItem, targetSlot: number) => {
      const current = itemsRef.current
      const live = current.find((i) => itemKey(i) === itemKey(item))
      if (!live || live.slot === targetSlot) return

      const occupant = current.find((i) => i.slot === targetSlot)
      const updated = current.map((i) => {
        if (itemKey(i) === itemKey(live)) return { ...i, slot: targetSlot }
        if (occupant && itemKey(i) === itemKey(occupant)) return { ...i, slot: live.slot }
        return i
      })
      setItems(updated)
      saveSlots(updated)
    },
    [saveSlots]
  )

  const handleUse = useCallback((item: InventoryItem) => {
    if (item.type !== "item_standard" || !item.usable) return
    fetchNui("useItem", { type: item.type, name: item.name })
  }, [])

  const handleDrop = useCallback(
    (item: InventoryItem) => {
      fetchNui("dropItem", { type: item.type, name: item.name, count: clampedAmount(item) })
      setSelectedLeft(null)
    },
    [clampedAmount]
  )

  const handleStoragePut = useCallback(
    (item: InventoryItem) => {
      if (item.type !== "item_standard") return
      fetchNui("storagePut", { type: item.type, name: item.name, count: clampedAmount(item) })
    },
    [clampedAmount]
  )

  const handleStorageTake = useCallback(
    (item: InventoryItem) => {
      fetchNui("storageTake", { name: item.name, count: clampedAmount(item) })
    },
    [clampedAmount]
  )

  const openPlayerList = useCallback(async () => {
    const players = await fetchNui<NearbyPlayer[]>("getNearbyPlayers")
    setNearbyPlayers(Array.isArray(players) ? players : [])
    setShowPlayerList(true)
  }, [])

  const handleGiveIntent = useCallback(
    (item: InventoryItem) => {
      setSelectedLeft(itemKey(item))
      openPlayerList()
    },
    [openPlayerList]
  )

  const handleGiveToPlayer = useCallback(
    (playerId: number) => {
      if (!selectedItem) return
      fetchNui("giveItem", {
        type: selectedItem.type,
        name: selectedItem.name,
        count: clampedAmount(selectedItem),
        target: playerId,
      })
      setSelectedLeft(null)
      setShowPlayerList(false)
    },
    [selectedItem, clampedAmount]
  )

  const { drag, startDrag } = useDrag(visible, {
    onMoveWithin: handleMoveLeft,
    onPutToStorage: handleStoragePut,
    onTakeFromStorage: handleStorageTake,
    onUse: handleUse,
    onGive: handleGiveIntent,
  })

  const toast = notification ? (
    <ItemNotification
      key={notification.key}
      item={notification.item}
      amount={notification.amount}
      added={notification.added}
      label={notification.added ? t("addedToInventory") : t("removedFromInventory")}
      onComplete={() => setNotification(null)}
    />
  ) : null

  if (!visible) {
    return toast
  }

  return (
    <div className="w-full max-w-7xl relative select-none">
      <div className={`grid grid-cols-1 ${storage ? "lg:grid-cols-[1fr_auto_1fr]" : "lg:grid-cols-[minmax(0,640px)_auto]"} gap-6 items-center justify-center`}>
        <Inventory
          title={t("inventory")}
          icon={<User className="w-5 h-5" />}
          items={items}
          weightLabel={t("weight")}
          maxWeight={maxWeight}
          selectedItem={selectedLeft}
          setSelectedItem={setSelectedLeft}
          panel="left"
          onSlotPointerDown={startDrag}
          onUseItem={handleUse}
          onGiveItem={handleGiveIntent}
          onDropItem={storage ? handleStoragePut : handleDrop}
          canDropItem={storage ? (item) => item.type === "item_standard" : undefined}
          dropLabel={storage ? t("storage") : t("remove")}
          useLabel={t("use")}
          giveLabel={t("give")}
          slotCount={slotCount}
          maxVisibleRows={4}
          hotbarSlots={hotbarSlots}
        />

        <ActionPanel
          t={t}
          selectedItem={selectedItem}
          dragFromLeft={drag !== null && drag.from === "left"}
          amount={amount}
          setAmount={setAmount}
          onUse={() => selectedItem && handleUse(selectedItem)}
          showPlayerList={showPlayerList}
          setShowPlayerList={setShowPlayerList}
          nearbyPlayers={nearbyPlayers}
          onOpenPlayerList={openPlayerList}
          onGiveToPlayer={handleGiveToPlayer}
        />

        {storage && (
          <Inventory
            title={storage.label}
            icon={<Package className="w-5 h-5" />}
            items={storage.items}
            weightLabel={t("weight")}
            maxWeight={storage.maxWeight}
            selectedItem={selectedRight}
            setSelectedItem={setSelectedRight}
            panel="right"
            onSlotPointerDown={startDrag}
            onDropItem={handleStorageTake}
            dropLabel={t("take")}
            slotCount={storage.slots}
            maxVisibleRows={4}
            hotbarSlots={0}
          />
        )}
      </div>

      {drag && <DragGhost drag={drag} />}
      {toast}
    </div>
  )
}
