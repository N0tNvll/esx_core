-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@class LogField
---@field name string
---@field value any
---@field inline? boolean

---@class LogEntry
---@field title? string
---@field message? string
---@field fields? LogField[]
---@field color? number|string

---@class LogOptions
---@field webhook? string

---@class LogQueue
---@field url string
---@field items table[]
---@field busy boolean
---@field nextAt integer
---@field failures integer
---@field dropped integer
---@field warnedAt integer

local MAX_EMBEDS <const> = 10
local MAX_BATCH_CHARS <const> = 6000
local MAX_QUEUE <const> = 5000
local MAX_HTTP_BATCH <const> = 50
local MAX_FAILURES <const> = 5
local MAX_BACKOFF_MS <const> = 30000
local TICK_MS <const> = 250
local WARN_INTERVAL_MS <const> = 60000
local CHANNEL_PATTERN <const> = "^[%w_%-%.:]+$"

local LIMITS <const> = {
    title = 256,
    description = 4096,
    fieldName = 256,
    fieldValue = 1024,
    fields = 25,
}

local COLORS <const> = {
    default = 14423100,
    blue = 255,
    red = 16711680,
    green = 65280,
    white = 16777215,
    black = 0,
    orange = 16744192,
    yellow = 16776960,
    pink = 16761035,
    lightgreen = 65309,
}

local FOOTER_ICON <const> = "https://cdn.discordapp.com/attachments/944789399852417096/1020099828266586193/blanc-800x800.png"
local AUTHOR_ICON <const> = "https://cdn.discordapp.com/emojis/939245183621558362.webp?size=128&quality=lossless"

---@type table<string, LogQueue>
local discordQueues = {}

---@type LogQueue
local httpQueue = { url = "", items = {}, busy = false, nextAt = 0, failures = 0, dropped = 0, warnedAt = 0 }

local workerRunning = false

---@param value any
---@param limit integer
---@return string
local function clip(value, limit)
    value = tostring(value or "")

    if #value <= limit then
        return value
    end

    return value:sub(1, limit - 3) .. "..."
end

---@param name string
---@return string?
local function readConvar(name)
    local value = GetConvar(name, "")

    if value == "" then
        return nil
    end

    return value
end

---@param url any
---@return boolean
local function isWebhookUrl(url)
    return type(url) == "string" and url:find("^https?://") ~= nil
end

---@param channel string
---@param options? LogOptions
---@return string?
local function resolveWebhook(channel, options)
    local url = readConvar(("esx:logs:%s"):format(channel))

    if not url and options and isWebhookUrl(options.webhook) then
        url = options.webhook
    end

    url = url or readConvar("esx:logs:default")

    return isWebhookUrl(url) and url or nil
end

---@param color any
---@return integer
local function resolveColor(color)
    if math.type(color) == "integer" and color >= 0 and color <= 16777215 then
        return color
    end

    return COLORS[color] or COLORS.default
end

---@param fields any
---@return table[]?
local function buildFields(fields)
    if type(fields) ~= "table" then
        return nil
    end

    local result = {}

    for i = 1, math.min(#fields, LIMITS.fields) do
        local field = fields[i]

        if type(field) == "table" then
            result[#result + 1] = {
                name = clip(field.name ~= nil and field.name or "-", LIMITS.fieldName),
                value = clip(field.value ~= nil and field.value or "-", LIMITS.fieldValue),
                inline = field.inline == true,
            }
        end
    end

    return result
end

---@param embed table
---@return integer
local function embedSize(embed)
    local size = #(embed.title or "") + #(embed.description or "") + #embed.footer.text + #embed.author.name

    if embed.fields then
        for i = 1, #embed.fields do
            size = size + #embed.fields[i].name + #embed.fields[i].value
        end
    end

    return size
end

---@param entry LogEntry
---@return table
local function buildEmbed(entry)
    local title = entry.title ~= nil and entry.title ~= "" and clip(entry.title, LIMITS.title) or nil
    local description = entry.message ~= nil and entry.message ~= "" and clip(entry.message, LIMITS.description) or nil

    local embed = {
        title = title,
        description = description,
        color = resolveColor(entry.color),
        fields = buildFields(entry.fields),
        footer = {
            text = ("| ESX Logs | %s"):format(os.date()),
            icon_url = FOOTER_ICON,
        },
        author = {
            name = "ESX Framework",
            icon_url = AUTHOR_ICON,
        },
    }

    embed.size = embedSize(embed)

    return embed
end

---@param queue LogQueue
---@param item table
---@param label string
local function enqueue(queue, item, label)
    if #queue.items >= MAX_QUEUE then
        table.remove(queue.items, 1)
        queue.dropped = queue.dropped + 1

        local now = GetGameTimer()

        if now - queue.warnedAt >= WARN_INTERVAL_MS then
            queue.warnedAt = now
            print(("[^3WARNING^7] xLib logs: %s queue is full, %d log(s) dropped so far"):format(label, queue.dropped))
        end
    end

    queue.items[#queue.items + 1] = item
end

---@param headers any
---@param name string
---@return string?
local function readHeader(headers, name)
    if type(headers) ~= "table" then
        return nil
    end

    for key, value in pairs(headers) do
        if type(key) == "string" and key:lower() == name then
            return tostring(value)
        end
    end

    return nil
end

---@param ... any
---@return number?
local function readRetryAfter(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)

        if type(value) == "string" then
            local retryAfter = tonumber(value:match('"retry_after"%s*:%s*([%d%.]+)'))

            if retryAfter then
                return retryAfter
            end
        end
    end

    return nil
end

---@param batch table[]
local function restoreSizes(batch)
    for i = 1, #batch do
        batch[i].size = embedSize(batch[i])
    end
end

---@param queue LogQueue
---@param batch table[]
local function requeue(queue, batch)
    for i = #batch, 1, -1 do
        table.insert(queue.items, 1, batch[i])
    end

    while #queue.items > MAX_QUEUE do
        table.remove(queue.items)
        queue.dropped = queue.dropped + 1
    end
end

---@param queue LogQueue
---@param batch table[]
---@param label string
local function retryLater(queue, batch, label)
    queue.failures = queue.failures + 1

    if queue.failures > MAX_FAILURES then
        print(("[^3WARNING^7] xLib logs: %s unreachable, %d log(s) dropped"):format(label, #batch))
        queue.failures = 0
        queue.nextAt = GetGameTimer() + MAX_BACKOFF_MS
        return
    end

    requeue(queue, batch)
    queue.nextAt = GetGameTimer() + math.min(1000 * 2 ^ (queue.failures - 1), MAX_BACKOFF_MS)
end

---@param queue LogQueue
---@return table[]
local function takeDiscordBatch(queue)
    local batch = {}
    local chars = 0

    while #batch < MAX_EMBEDS and queue.items[1] do
        local size = queue.items[1].size

        if #batch > 0 and chars + size > MAX_BATCH_CHARS then
            break
        end

        local embed = table.remove(queue.items, 1)
        embed.size = nil
        batch[#batch + 1] = embed
        chars = chars + size
    end

    return batch
end

---@param queue LogQueue
local function flushDiscord(queue)
    local batch = takeDiscordBatch(queue)

    if #batch == 0 then
        return
    end

    queue.busy = true

    local function handleResponse(status, body, headers, errorData)
        local now = GetGameTimer()
        status = tonumber(status) or 0

        if status == 429 then
            local retryAfter = readRetryAfter(body, errorData) or tonumber(readHeader(headers, "retry-after") or "") or 1

            restoreSizes(batch)
            requeue(queue, batch)
            queue.nextAt = now + math.ceil(retryAfter * 1000) + 100
            return
        end

        if status >= 200 and status < 300 then
            queue.failures = 0

            if readHeader(headers, "x-ratelimit-remaining") == "0" then
                local resetAfter = tonumber(readHeader(headers, "x-ratelimit-reset-after") or "") or 1
                queue.nextAt = now + math.ceil(resetAfter * 1000) + 100
            end

            return
        end

        if status >= 400 and status < 500 then
            print(("[^3WARNING^7] xLib logs: Discord refused %d log(s) with status %d"):format(#batch, status))
            return
        end

        restoreSizes(batch)
        retryLater(queue, batch, "Discord webhook")
    end

    PerformHttpRequest(queue.url, function(status, body, headers, errorData)
        queue.busy = false

        local ok, err = pcall(handleResponse, status, body, headers, errorData)

        if not ok then
            print(("[^3WARNING^7] xLib logs: failed to handle Discord response: %s"):format(err))
            restoreSizes(batch)
            requeue(queue, batch)
            queue.nextAt = GetGameTimer() + 1000
        end
    end, "POST", json.encode({ username = "Logs", embeds = batch }), { ["Content-Type"] = "application/json" })
end

local function flushHttp()
    local url = readConvar("esx:logs:http")

    if not url then
        httpQueue.items = {}
        return
    end

    local batch = {}

    while #batch < MAX_HTTP_BATCH and httpQueue.items[1] do
        batch[#batch + 1] = table.remove(httpQueue.items, 1)
    end

    local headers = { ["Content-Type"] = "application/json" }
    local token = readConvar("esx:logs:httpToken")

    if token then
        headers.Authorization = ("Bearer %s"):format(token)
    end

    httpQueue.busy = true

    PerformHttpRequest(url, function(status)
        httpQueue.busy = false
        status = tonumber(status) or 0

        if status >= 200 and status < 300 then
            httpQueue.failures = 0
            return
        end

        if status >= 400 and status < 500 and status ~= 429 then
            print(("[^3WARNING^7] xLib logs: HTTP sink refused %d log(s) with status %d"):format(#batch, status))
            return
        end

        retryLater(httpQueue, batch, "HTTP sink")
    end, "POST", json.encode(batch), headers)
end

local function startWorker()
    if workerRunning then
        return
    end

    workerRunning = true

    CreateThread(function()
        while true do
            Wait(TICK_MS)

            local now = GetGameTimer()
            local pending = false

            for url, queue in pairs(discordQueues) do
                if #queue.items > 0 then
                    pending = true

                    if not queue.busy and now >= queue.nextAt then
                        flushDiscord(queue)
                    end
                elseif not queue.busy and queue.dropped == 0 then
                    discordQueues[url] = nil
                end
            end

            if #httpQueue.items > 0 then
                pending = true

                if not httpQueue.busy and now >= httpQueue.nextAt then
                    flushHttp()
                end
            end

            if not pending then
                local idle = true

                for _, queue in pairs(discordQueues) do
                    if queue.busy then
                        idle = false
                    end
                end

                if idle and not httpQueue.busy then
                    workerRunning = false
                    return
                end
            end
        end
    end)
end

---@param channel string
---@param entry LogEntry
---@param options? LogOptions
---@return boolean queued
function xLib.logs_send(channel, entry, options)
    if type(channel) ~= "string" or not channel:find(CHANNEL_PATTERN) or type(entry) ~= "table" then
        return false
    end

    local resource = GetInvokingResource() or GetCurrentResourceName()
    local queued = false

    if GetConvar("esx:logs:console", "false") == "true" then
        print(("[logs:%s] %s %s"):format(channel, tostring(entry.title or ""), tostring(entry.message or "")))
        queued = true
    end

    local webhook = resolveWebhook(channel, type(options) == "table" and options or nil)

    if webhook then
        local queue = discordQueues[webhook]

        if not queue then
            queue = { url = webhook, items = {}, busy = false, nextAt = 0, failures = 0, dropped = 0, warnedAt = 0 }
            discordQueues[webhook] = queue
        end

        enqueue(queue, buildEmbed(entry), ("Discord (%s)"):format(channel))
        queued = true
    end

    if readConvar("esx:logs:http") then
        enqueue(httpQueue, {
            channel = channel,
            resource = resource,
            timestamp = os.time(),
            title = entry.title and clip(entry.title, LIMITS.title) or nil,
            message = entry.message and clip(entry.message, LIMITS.description) or nil,
            fields = buildFields(entry.fields),
        }, "HTTP")
        queued = true
    end

    if queued then
        startWorker()
    end

    return queued
end
