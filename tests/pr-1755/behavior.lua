local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ': ' .. tostring(err))
    count = count + 1
    print('PASS ' .. name)
end

local vectorMT = {}
local function vec3(x, y, z)
    return setmetatable({ x = x, y = y or x, z = z or x }, vectorMT)
end
vectorMT.__sub = function(a, b) return vec3(a.x-b.x, a.y-b.y, a.z-b.z) end
vectorMT.__add = function(a, b) return vec3(a.x+b.x, a.y+b.y, a.z+b.z) end
vectorMT.__div = function(a, b) return vec3(a.x/b, a.y/b, a.z/b) end
vectorMT.__len = function(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end

-- GLM geometry is a deterministic stand-in. Native FiveM GLM still needs an in-game check.
local polygonMT = {}
local function polygon(points) return setmetatable(points, polygonMT) end
polygonMT.__index = {
    isPlanar = function(self)
        for _, v in ipairs(self) do if v.z ~= self[1].z then return false end end
        return true
    end,
    isConvex = function() return true end,
    centroid = function(self)
        local sum = vec3(0,0,0)
        for _, p in ipairs(self) do sum = sum + p end
        return sum / #self
    end,
}
polygonMT.__add = function(self, offset)
    local points = {}
    for i, p in ipairs(self) do points[i] = p + offset end
    return polygon(points)
end
local glm = { polygon = { new = polygon }, tointeger = math.floor }
glm.polygon.contains = function(poly, p, thickness)
    if math.abs(p.z-poly[1].z) > thickness then return false end
    local inside = false
    local j = #poly
    for i = 1, #poly do
        local a, b = poly[i], poly[j]
        if (a.y > p.y) ~= (b.y > p.y) and p.x < (b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x then inside = not inside end
        j = i
    end
    return inside
end

local function fixture(server)
    local env = setmetatable({}, { __index = _G })
    env._ENV = env
    env.vec3, env.vec = vec3, vec3
    env.mat = function(...) return { ... } end
    env.quat = function(angle)
        return setmetatable({}, { __mul = function(_, poly)
            local points, radians = {}, math.rad(angle)
            for i,p in ipairs(poly) do
                points[i] = vec3(p.x*math.cos(radians)-p.y*math.sin(radians), p.x*math.sin(radians)+p.y*math.cos(radians),p.z)
            end
            return polygon(points)
        end })
    end
    env.require = function(name) assert(name == 'glm'); return glm end
    env.table = setmetatable({
        wipe = function(t) for k in pairs(t) do t[k] = nil end end,
        create = function() return {} end,
    }, { __index = table })
    local state = { threads = {}, events = {}, coords = vec3(0,0,0), resource = 'test', logs = {} }
    env.print = function(...) state.logs[#state.logs+1] = { ... } end
    env.GetInvokingResource = function() return state.resource end
    env.GetCurrentResourceName = function() return 'owner' end
    env.GetEntityCoords = function() return state.coords end
    env.PlayerPedId = function() return 1 end
    env.GetGameTimer = function() return 500 end
    env.IsDuplicityVersion = function() return server or false end
    env.DrawLine, env.DrawPoly, env.DrawMarker = function() end, function() end, function() end
    env.CreateThread = function(fn) state.threads[#state.threads+1] = coroutine.create(fn) end
    env.Wait = function(ms) coroutine.yield(ms) end
    env.AddEventHandler = function(name, fn)
        state.events[name] = state.events[name] or {}
        table.insert(state.events[name], fn)
    end
    function state.step(index)
        local ok, result = coroutine.resume(assert(state.threads[index]))
        assert(ok, result)
        return result
    end
    function state.stop(resource)
        for _, fn in ipairs(state.events.onResourceStop or {}) do fn(resource) end
    end
    env.xLib = { verify = function(value, expected, throwing)
        local valid = type(expected) == 'table' and (value == nil or type(value) == 'table') or type(value) == expected
        if throwing then assert(valid, 'invalid type') end
        return valid
    end }
    for _, name in ipairs({ 'class', 'table', 'grid', 'points', 'zones' }) do
        assert(load(SOURCES[name], name, 't', env))()
    end
    return env.xLib, state, env
end

test('existing table helpers and global functions survive', function()
    local lib, _, env = fixture()
    assert(lib.table ~= env.table and lib.table.concat ~= env.table.concat)
    assert(lib.table.contains({ 'a' }, { 'b', 'a' }))
    assert(lib.table.sizeOf({a=1,b=2}) == 2)
    assert(lib.table.join(lib.table.concat({'a'},{'b'}), ':') == 'a:b')
    assert(not lib.table.isArray({[2]='hole'}))
    assert(lib.table.dump({a={b=1}}):find('b'))
end)
test('arrays preserve false initial values and reverse reduction', function()
    local lib = fixture()
    local a = lib.table.array:new(1,2,3)
    assert(a:reduce(function(acc, n) return acc-n end, nil, true) == 0)
    assert(a:reduce(function(acc) assert(acc == false); return false end, false) == false)
    assert(a:reduce(function(acc, n) return acc+n end, 0) == 6)
    assert(lib.table.array.isArray(a) and not lib.table.array.isArray({[3]=true}))
end)
test('array transforms and merge preserve references', function()
    local lib = fixture()
    local value = {}
    local a = lib.table.array:new(value, 2)
    assert(a:merge({3})[1] == value)
    assert(a:map(function(_,i) return i end):join(':') == '1:2')
    assert(a:filter(function(v) return v == 2 end)[1] == 2)
    assert(a:indexOf('absent') == nil)
    assert(a:toReversed()[1] == 2 and a[1] == value)
end)
test('grid invalidates an empty cell cache on insertion and removal', function()
    local lib = fixture()
    local coords = vec3(0,0,0)
    assert(#lib.grid.getCell(coords) == 0)
    local entry = {coords=coords,radius=5}
    lib.grid.addEntry(entry)
    assert(lib.grid.getCell(coords)[1] == entry)
    assert(lib.grid.removeEntry(entry))
    assert(#lib.grid.getCell(coords) == 0 and #lib.grid.getNearbyEntries(coords) == 0)
end)
test('grid handles duplicate insertion, movement and dynamic filters', function()
    local lib = fixture()
    local entry = {coords=vec3(0,0,0),radius=500}
    lib.grid.addEntry(entry); lib.grid.addEntry(entry)
    assert(#lib.grid.getNearbyEntries(entry.coords) == 1)
    local enabled = true
    local filter = function() return enabled end
    assert(#lib.grid.getNearbyEntries(entry.coords,filter) == 1)
    enabled = false
    assert(#lib.grid.getNearbyEntries(entry.coords,filter) == 0)
    entry.coords = vec3(9000,9000,0)
    assert(lib.grid.removeEntry(entry))
    assert(#lib.grid.getNearbyEntries(vec3(0,0,0)) == 0)
    assert(not lib.grid.removeEntry(entry))
end)
test('legacy numeric points keep callbacks, hiding and restart behavior', function()
    local lib, state = fixture()
    local entered, inside, left = 0,0,0
    local handle = lib.points.create(vec3(0,0,0), 10, false,
        function() entered=entered+1 end, function() left=left+1 end,
        function(distance) assert(distance == 0); inside=inside+1 end)
    state.step(2); state.step(2)
    assert(entered == 1 and inside == 1)
    lib.points.remove(handle); state.step(2)
    assert(coroutine.status(state.threads[2]) == 'dead')
    assert(lib.points.create(vec3(0,0,0),10,true) > handle)
    state.step(3)
    assert(entered == 1 and left == 0)
end)
test('new points enter, report closest, tick, exit and clean resources', function()
    local lib, state = fixture()
    local entered, nearby, exited = 0,0,0
    local p = lib.points.new({coords={0,0,0},distance=5,
        onEnter=function(self) assert(self.id);entered=entered+1 end,
        nearby=function(self) assert(self.currentDistance == 0);nearby=nearby+1 end,
        onExit=function() exited=exited+1 end})
    state.step(2); state.step(3)
    assert(entered == 1 and nearby == 1 and lib.points.closest() == p and p.isClosest)
    state.coords = vec3(50,50,0);state.step(2);state.step(3)
    assert(exited == 1 and not p.isClosest and not lib.points.closest())
    state.stop('test')
    assert(next(lib.points.getAllPoints()) == nil)
    assert(#lib.grid.getNearbyEntries(vec3(0,0,0)) == 0)
end)
test('new point removal during enter prevents nearby callback', function()
    local lib, state = fixture()
    local point = lib.points.new({coords={0,0,0}, distance=5,
        onEnter=function(self) self:remove() end, nearby=function() error('removed point') end})
    state.step(2)
    assert(not lib.points.getAllPoints()[point.id] and #lib.points.getNearbyPoints() == 0)
    assert(not lib.points.getClosestPoint())
end)
test('point identifiers never reuse sparse handles and errors stay isolated', function()
    local lib, state = fixture()
    local a=lib.points.new({coords={0,0,0},distance=5,onEnter=function() error('intentional') end})
    local b=lib.points.new({coords={0,0,0},distance=5})
    a:remove()
    local c=lib.points.new({coords={0,0,0},distance=5,onEnter=function() error('intentional') end})
    assert(c.id > b.id)
    state.step(2)
    assert(#state.logs == 1 and lib.points.getAllPoints()[b.id] == b)
end)
test('nearby callback removal never repeats another point in the same frame', function()
    local lib, state = fixture()
    local calls=0
    local a=lib.points.new({coords={0,0,0},distance=5})
    lib.points.new({coords={0,0,0},distance=5,nearby=function() calls=calls+1;a:remove() end})
    state.step(2);state.step(3)
    assert(calls == 1)
end)
test('sphere transitions, callback errors and debug disabling', function()
    local lib, state = fixture()
    local enter, inside, exit = 0,0,0
    local zone=lib.zones.sphere({coords={0,0,0},radius=5,
        onEnter=function() enter=enter+1;error('intentional') end,
        inside=function() inside=inside+1 end,onExit=function() exit=exit+1 end})
    state.step(1);state.step(2)
    assert(enter == 1 and inside == 1 and #state.logs == 1)
    zone:setDebug(true);zone:setDebug(false);state.step(2)
    assert(inside == 2 and not zone.debug)
    state.coords=vec3(1000,1000,0);state.step(1);state.step(2)
    assert(exit == 1 and next(lib.zones.getCurrentZones()) == nil)
end)
test('removing an unrelated zone keeps queued callbacks', function()
    local lib, state = fixture()
    local called=0
    local other=lib.zones.sphere({coords={5000,5000,0},radius=5})
    lib.zones.sphere({coords={0,0,0},radius=5,onEnter=function() other:remove();called=called+1 end})
    lib.zones.sphere({coords={1,0,0},radius=5,onEnter=function() called=called+1 end})
    state.step(1)
    assert(called == 2)
end)
test('zones use monotonic IDs and resource stop removes active references', function()
    local lib, state = fixture()
    local a=lib.zones.sphere({coords={0,0,0}})
    local b=lib.zones.sphere({coords={0,0,0},inside=function() end})
    a:remove()
    local c=lib.zones.sphere({coords={0,0,0}})
    assert(c.id > b.id)
    state.step(1);state.stop('test');state.step(2)
    assert(next(lib.zones.getAllZones()) == nil and #lib.zones.getNearbyZones() == 0)
    assert(next(lib.zones.getCurrentZones()) == nil)
end)
test('server containment creates no active client loop', function()
    local lib, state = fixture(true)
    local zone=lib.zones.sphere({coords={0,0,0},radius=5,debug=true})
    assert(zone:contains(vec3(1,1,1)) and not zone:contains(vec3(50,0,0)))
    assert(not zone.debug)
    state.step(1)
    assert(coroutine.status(state.threads[1]) == 'dead')
    state.stop('test');assert(next(lib.zones.getAllZones()) == nil)
end)
test('rotated long boxes cover their far corners in the spatial grid', function()
    local lib = fixture()
    local zone=lib.zones.box({coords={0,0,0},size={1000,2,4},rotation=90})
    local far=vec3(0,490,0)
    assert(zone:contains(far))
    local found=false
    for _,entry in ipairs(lib.grid.getNearbyEntries(far)) do if entry == zone then found=true end end
    assert(found)
end)
test('polygon input tables flatten safely and compute containment', function()
    local lib = fixture()
    local zone=lib.zones.poly({points={{0,0,0},{10,0,2},{10,10,0},{0,10,2}}})
    assert(zone.coords.z == 1)
    assert(zone:contains(vec3(5,5,1)) and not zone:contains(vec3(50,50,1)))
end)
print(('Passed %d spatial and compatibility regressions; 5 modules parsed.'):format(count))
