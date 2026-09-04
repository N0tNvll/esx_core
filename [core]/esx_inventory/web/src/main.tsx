import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import InventorySystem from "@/components/inventory-system"
import "./globals.css"

createRoot(document.getElementById("root") as HTMLElement).render(
  <StrictMode>
    <main className="min-h-screen flex items-center justify-center p-8">
      <InventorySystem />
    </main>
  </StrictMode>
)
