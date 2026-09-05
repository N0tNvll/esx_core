Core.PlayerClass = Core.PlayerClass or {}

local function buildItemEntry(itemName, count)
    local itemData = ESX.Items[itemName]

    if not itemData then
        return nil
    end

    return {
        name = itemName,
        count = count,
        label = itemData.label,
        weight = itemData.weight,
        usable = Core.UsableItemsCallbacks[itemName] ~= nil,
        rare = itemData.rare,
        canRemove = itemData.canRemove,
    }
end

function Core.PlayerClass.AttachInventory(self)
    function self.getInventory(minimal)
        if minimal then
            local minimalInventory = {}

            for itemName, item in pairs(self.inventory) do
                minimalInventory[itemName] = item.count
            end

            return minimalInventory
        end

        local items = {}

        for _, item in pairs(self.inventory) do
            items[#items + 1] = item
        end

        table.sort(items, function(a, b)
            return a.label < b.label
        end)

        return items
    end

    function self.getInventoryItem(itemName)
        local item = self.inventory[itemName]

        if item then
            return item
        end

        local itemData = ESX.Items[itemName]

        if not itemData then
            return nil
        end

        return {
            name = itemName,
            count = 0,
            label = itemData.label,
            weight = itemData.weight,
            usable = Core.UsableItemsCallbacks[itemName] ~= nil,
            rare = itemData.rare,
            canRemove = itemData.canRemove,
        }
    end

    function self.addInventoryItem(itemName, count)
        count = ESX.Math.Round(count)

        if count <= 0 then
            return false
        end

        local item = self.inventory[itemName]

        if item then
            item.count = item.count + count
        else
            item = buildItemEntry(itemName, count)

            if not item then
                print(('[^3WARNING^7] Item ^5"%s"^7 was used but does not exist!'):format(itemName))
                return false
            end

            self.inventory[itemName] = item
        end

        self.weight = self.weight + (item.weight * count)

        TriggerEvent("esx:onAddInventoryItem", self.source, itemName, item.count)
        self.triggerEvent("esx:addInventoryItem", itemName, item.count, false, item)
        return true
    end

    function self.removeInventoryItem(itemName, count)
        local item = self.inventory[itemName]

        if item then
            count = ESX.Math.Round(count)

            if count > 0 then
                local newCount = item.count - count

                if newCount >= 0 then
                    item.count = newCount
                    self.weight = self.weight - (item.weight * count)

                    if newCount == 0 then
                        self.inventory[itemName] = nil
                    end

                    TriggerEvent("esx:onRemoveInventoryItem", self.source, itemName, item.count)
                    self.triggerEvent("esx:removeInventoryItem", itemName, item.count)
                    return true
                end

                return false
            else
                error(("Player ID:^5%s Tried remove a Invalid count -> %s of %s"):format(self.playerId, count, itemName))
            end
        end

        return false
    end

    function self.setInventoryItem(itemName, count)
        local item = self.inventory[itemName]

        if (item or ESX.Items[itemName]) and count >= 0 then
            count = ESX.Math.Round(count)

            if item and count == item.count then
                return
            end

            if count > (item and item.count or 0) then
                return self.addInventoryItem(itemName, count - (item and item.count or 0))
            else
                return self.removeInventoryItem(itemName, (item and item.count or 0) - count)
            end
        end

        return false
    end

    function self.getWeight()
        return self.weight
    end


    function self.getMaxWeight()
        return self.maxWeight
    end

    function self.canCarryItem(itemName, count)
        if ESX.Items[itemName] then
            local currentWeight, itemWeight = self.weight, ESX.Items[itemName].weight
            local newWeight = currentWeight + (itemWeight * count)

            return newWeight <= self.maxWeight
        else
            print(('[^3WARNING^7] Item ^5"%s"^7 was used but does not exist!'):format(itemName))
            return false
        end
    end

    function self.canSwapItem(firstItem, firstItemCount, testItem, testItemCount)
        local firstItemObject = self.getInventoryItem(firstItem)
        if not firstItemObject then
            return false
        end
        local testItemObject = self.getInventoryItem(testItem)
        if not testItemObject then
            return false
        end

        if firstItemObject.count >= firstItemCount then
            local weightWithoutFirstItem = ESX.Math.Round(self.weight - (firstItemObject.weight * firstItemCount))
            local weightWithTestItem = ESX.Math.Round(weightWithoutFirstItem + (testItemObject.weight * testItemCount))

            return weightWithTestItem <= self.maxWeight
        end

        return false
    end

    function self.setMaxWeight(newWeight)
        self.maxWeight = newWeight
        self.triggerEvent("esx:setMaxWeight", self.maxWeight)
    end

    function self.hasItem(item)
        local entry = self.inventory[item]

        if entry and entry.count >= 1 then
            return entry, entry.count
        end

        return false
    end

end