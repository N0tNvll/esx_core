Core.PlayerClass = Core.PlayerClass or {}

function Core.PlayerClass.AttachInventory(self)
    function self.getInventory(minimal)
        if minimal then
            local minimalInventory = {}

            for _, v in ipairs(self.inventory) do
                if v.count > 0 then
                    minimalInventory[v.name] = v.count
                end
            end

            return minimalInventory
        end

        return self.inventory
    end

    function self.getInventoryItem(itemName)
        for _, v in ipairs(self.inventory) do
            if v.name == itemName then
                return v
            end
        end
        return nil
    end

    function self.addInventoryItem(itemName, count)
        local item = self.getInventoryItem(itemName)

        if item then
            count = ESX.Math.Round(count)
            item.count = item.count + count
            self.weight = self.weight + (item.weight * count)

            TriggerEvent("esx:onAddInventoryItem", self.source, item.name, item.count)
            self.triggerEvent("esx:addInventoryItem", item.name, item.count)
            return true
        end

        return false
    end

    function self.removeInventoryItem(itemName, count)
        local item = self.getInventoryItem(itemName)

        if item then
            count = ESX.Math.Round(count)
            if count > 0 then
                local newCount = item.count - count

                if newCount >= 0 then
                    item.count = newCount
                    self.weight = self.weight - (item.weight * count)

                    TriggerEvent("esx:onRemoveInventoryItem", self.source, item.name, item.count)
                    self.triggerEvent("esx:removeInventoryItem", item.name, item.count)
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
        local item = self.getInventoryItem(itemName)

        if item and count >= 0 then
            count = ESX.Math.Round(count)

            if count == item.count then
                return
            end

            if count > item.count then
                return self.addInventoryItem(item.name, count - item.count)
            else
                return self.removeInventoryItem(item.name, item.count - count)
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
        for _, v in ipairs(self.inventory) do
            if v.name == item and v.count >= 1 then
                return v, v.count
            end
        end

        return false
    end

end
