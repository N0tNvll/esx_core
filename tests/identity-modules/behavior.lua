local cases, mode, fixtures = 0, nil, nil
local function clone(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = clone(item) end
    return copy
end
local function stable(value)
    if type(value) ~= 'table' then return type(value) .. ':' .. tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
    for _,key in ipairs(keys) do parts[#parts+1] = stable(key) .. '=' .. stable(value[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
end
local function resume(thread)
    local ok, result = coroutine.resume(thread)
    assert(ok, result)
    return result
end
local function test(name, fn)
    local expected
    for _, selected in ipairs(BASELINE and { 'baseline', 'modules' } or { 'modules' }) do
        mode, fixtures = selected, {}
        local ok, err = pcall(fn)
        assert(ok, name .. ' (' .. selected .. '): ' .. tostring(err))
        local traces = {}
        for i, state in ipairs(fixtures) do traces[i] = state.trace end
        local actual = stable(traces)
        if expected then assert(actual == expected, name .. ': behavior changed from baseline') end
        expected = actual
    end
    cases = cases + 1
    print('PASS ' .. name)
end

local function fixture(options)
    options = options or {}
    local env = setmetatable({}, { __index = _G })
    local state = { trace = {}, callbacks = {}, events = {}, commands = {}, pending = {}, variables = {}, states = {},
        exists = options.exists ~= false, ready = options.ready ~= false, identifier = 'license:test' }
    fixtures[#fixtures+1] = state
    local function record(...) state.trace[#state.trace+1] = clone(table.pack(...)) end
    env.Config = { Locale='en', MaxNameLength=20, MinHeight=120, MaxHeight=220, MaxAge=100, DateFormat='DD/MM/YYYY',
        FullCharDelete=true, EnableCommands=false, EnableDebugging=false }
    for key, value in pairs(options.config or {}) do env.Config[key] = value end
    env.os = { date = function() return { year=2026 } end }
    local player = { source=7, src=7, identifier=state.identifier }
    player.getIdentifier = function() return state.identifier end
    player.getSource = function() return 7 end
    player.setName = function(name) state.name=name; record('name',name) end
    player.getName = function() return state.name or 'Existing Name' end
    player.set = function(key,value) state.variables[key]=value; record('variable',key,value) end
    player.get = function(key) return state.variables[key] end
    player.showNotification = function(...) record('notification',...) end
    player.kick = function(...) record('kick',...) end
    state.player = player
    env.ESX = {
        GetConfig = function() return { Multichar=options.multichar ~= false } end,
        Player = function() return state.exists and player or nil end,
        GetIdentifier = function()
            if options.identifierError then error('no license') end
            return state.identifier
        end,
        ExtendedPlayers = function() return state.exists and { player } or {} end,
        RegisterCommand = function(name,group,fn,console,suggestion)
            record('command',name,group,console,suggestion)
            state.commands[name]={ group=group, fn=fn }
        end,
    }
    assert(load(CORE_VALIDATION, 'core-validation', 't', env))()
    env.xLib = { callback = { registerCompat = function(name,fn)
        record('callback',name);state.callbacks[name]=fn
    end } }
    env.ESXCatalog = { awaitReady = function()
        record('awaitCatalog')
        if not state.ready then coroutine.yield('catalog') end
        assert(state.ready)
    end }
    env.MySQL = {
        query = { await = function(...) record('query',...);return 1 end },
        update = { await = function(...) record('update',...);return 1 end },
        prepare = { await = function(...) record('prepare',...);return 1 end },
        single = function(query,params,cb)
            record('read',query,params);state.pending[#state.pending+1]=cb
        end,
    }
    env.Player = function()
        return { state = { set = function(_,key,value,replicated)
            state.states[key]=value; record('state',key,value,replicated)
        end } }
    end
    env.TranslateCap = function(...) return table.concat(table.pack(...), ':') end
    env.GetCurrentResourceName = function() return 'esx_identity' end
    env.AddEventHandler = function(event,fn)
        record('handler',event);state.events[event]=fn
    end
    env.RegisterNetEvent = function() error('identity lifecycle must remain server-local') end
    env.TriggerClientEvent = function(...) record('client',...) end
    env.TriggerEvent = function(...) record('event',...) end
    env.Wait = function(ms) record('wait',ms) end
    function state.invoke(data)
        local replies, value = 0
        state.callbacks['esx_identity:registerIdentity'](7,function(result)
            replies, value = replies+1,result;record('reply',result)
        end,data)
        assert(replies == 1, 'callback must reply exactly once')
        return value
    end
    function state.flush(row)
        local callback = table.remove(state.pending,1)
        assert(callback, 'no pending SQL read');callback(row)
    end
    function state.emit(event,...)
        env.source = 7
        assert(state.events[event], 'missing event ' .. event)(...)
    end
    function state.connect()
        state.emit('playerConnecting', 'name', nil, {
            defer = function() record('defer') end,
            done = function(...) record('done',...) end,
        })
    end
    function state.count(kind,name)
        local total = 0
        for _, entry in ipairs(state.trace) do
            if entry[1] == kind and (name == nil or entry[2] == name) then total=total+1 end
        end
        return total
    end
    state.start = coroutine.create(function()
        if mode == 'baseline' then assert(load(BASELINE,'baseline','t',env))()
        else for i, source in ipairs(SOURCES) do assert(load(source,'module-' .. i,'t',env))() end end
    end)
    resume(state.start)
    return state, env
end
local function data(changes)
    local value = { firstname='tEST',lastname='nAME',dateofbirth='29/02/2000',sex='M',height='180' }
    for key,item in pairs(changes or {}) do value[key]=item end
    return value
end
local row = { firstname='Saved',lastname='Name',dateofbirth='01/01/1990',sex='f',height=170 }

test('catalog readiness precedes event and callback registration', function()
    local state = fixture({ ready=false, multichar=false, config={EnableCommands=true} })
    assert(not next(state.callbacks) and not next(state.events) and not next(state.commands))
    state.ready=true;resume(state.start)
    assert(coroutine.status(state.start)=='dead' and state.callbacks['esx_identity:registerIdentity'])
end)
for _,multichar in ipairs({true,false}) do
    test('existing player registration with multichar=' .. tostring(multichar), function()
        local state=fixture({multichar=multichar})
        assert(state.invoke(data()) == true)
        assert(state.name=='Test Name' and state.variables.sex=='m' and state.variables.height==180)
        assert(state.states.name=='Test Name' and state.states.height==180)
        assert(state.count('update')==1 and state.count('event','esx_identity:completedRegistration')==0)
    end)
end
test('multichar creation emits one formatted registration event', function()
    local state=fixture({exists=false})
    local payload=data()
    assert(state.invoke(payload)==true and payload.firstname=='Test' and payload.lastname=='Name')
    assert(payload.sex=='m' and payload.height==180)
    assert(state.count('event','esx_identity:completedRegistration')==1 and state.count('update')==0)
end)
test('missing player without multichar is rejected', function()
    local state=fixture({exists=false,multichar=false})
    assert(state.invoke(data())==false and state.count('client','esx:showNotification')==1)
    assert(state.count('update')==0)
end)
test('malformed registration payloads return false without database writes', function()
    for _,value in ipairs({false,1,'bad',function()end}) do
        local state=fixture();assert(state.invoke(value)==false and state.count('update')==0)
    end
    local state=fixture();assert(state.invoke(nil)==false)
end)
local invalids = {
    {'first name type',{firstname={}}}, {'last name type',{lastname=25}},
    {'empty first name',{firstname=''}}, {'empty last name',{lastname=''}},
    {'name length',{firstname=string.rep('a',20)}}, {'name characters',{firstname='Alice123'}},
    {'invalid UTF-8',{firstname=string.char(255)}}, {'invalid sex',{sex={}}},
    {'date type',{dateofbirth={}}}, {'invalid leap day',{dateofbirth='29/02/2001'}},
    {'invalid month',{dateofbirth='01/13/2000'}}, {'invalid day',{dateofbirth='31/04/2000'}},
    {'too young',{dateofbirth='01/01/2009'}}, {'too old',{dateofbirth='01/01/1925'}},
    {'height type',{height={}}}, {'height text',{height='bad'}},
    {'height NaN',{height=0/0}}, {'positive infinity',{height=math.huge}},
    {'negative infinity',{height=-math.huge}}, {'short height',{height=119}}, {'tall height',{height=221}},
}
for _,case in ipairs(invalids) do
    test('rejects ' .. case[1], function()
        local state=fixture();assert(state.invoke(data(case[2]))==false)
        assert(state.count('update')==0 and state.count('event')==0)
    end)
end
test('missing identity fields fail before persistence', function()
    for _,key in ipairs({'firstname','lastname','dateofbirth','sex','height'}) do
        local state=fixture();local payload=data();payload[key]=nil
        assert(state.invoke(payload)==false and state.count('update')==0)
    end
end)
test('validation preserves first-error notification order', function()
    local state=fixture();assert(state.invoke({})==false)
    local last=state.trace[#state.trace-1]
    assert(last[1]=='client' and last[4]=='invalid_firstname_format')
end)
for _,height in ipairs({120,220}) do
    test('accepts height boundary ' .. height, function()
        local state=fixture();assert(state.invoke(data({height=height}))==true)
    end)
end
test('preserves locale-specific characters and configured alphabets', function()
    for _,options in ipairs({{name='José'}, {name='Νίκος',locale='el'}, {name='Νίκος',sets={el=true}}}) do
        local state=fixture({config={Locale=options.locale or 'en',ValidCharacterSets=options.sets}})
        assert(state.invoke(data({firstname=options.name}))==true)
    end
end)
for _,format in ipairs({'DD/MM/YYYY','MM/DD/YYYY','YYYY/MM/DD'}) do
    test('keeps date formatting ' .. format, function()
        local state=fixture({config={DateFormat=format}})
        assert(state.invoke(data())==true)
        local expected=({['DD/MM/YYYY']='29/02/2000',['MM/DD/YYYY']='02/29/2000',['YYYY/MM/DD']='2000/02/29'})[format]
        assert(state.variables.dateofbirth==expected)
    end)
end
test('a completed existing identity cannot register twice', function()
    local state=fixture()
    assert(state.invoke(data())==true and state.invoke(data())==false)
    assert(state.count('update')==1)
end)
test('existing connection identity is read asynchronously and applied on load', function()
    local state=fixture({multichar=false})
    state.connect()
    assert(#state.pending==1 and state.count('done')==0)
    state.flush(row)
    assert(state.count('done')==1)
    state.emit('esx:playerLoaded',7,state.player)
    assert(state.name=='Saved Name' and state.variables.sex=='f')
    assert(state.count('client','esx_identity:alreadyRegistered')==1)
    assert(state.invoke(data())==false)
end)
test('connection without a row opens identity registration on load', function()
    local state=fixture({multichar=false})
    state.connect();state.flush(nil);state.emit('esx:playerLoaded',7,state.player)
    assert(state.count('done')==1 and state.count('client','esx_identity:showRegisterIdentity')==1)
end)
test('connection with an incomplete row requires registration', function()
    local state=fixture({multichar=false})
    state.connect();state.flush({});state.emit('esx:playerLoaded',7,state.player)
    assert(state.count('client','esx_identity:showRegisterIdentity')==1)
end)
test('missing license completes the deferral with an error', function()
    local state=fixture({multichar=false,identifierError=true})
    state.connect();assert(state.count('read')==0 and state.count('done')==1)
end)
test('resource restart restores online identities through asynchronous reads', function()
    local state=fixture({multichar=false})
    state.emit('onResourceStart','other');assert(#state.pending==0)
    state.emit('onResourceStart','esx_identity');assert(#state.pending==1)
    state.flush(row);assert(state.name=='Saved Name' and state.count('update')==0)
end)
test('resource restart with missing identity opens registration', function()
    local state=fixture({multichar=false})
    state.emit('onResourceStart','esx_identity');state.flush(nil)
    assert(state.count('client','esx_identity:showRegisterIdentity')==1)
end)
test('multichar mode leaves connection and player-load handling to multicharacter', function()
    local state=fixture()
    assert(not state.events.playerConnecting and not state.events['esx:playerLoaded'])
end)
test('commands remain opt-in and character deletion requires admin', function()
    local disabled=fixture();assert(not next(disabled.commands))
    local state=fixture({config={EnableCommands=true}})
    assert(state.commands.char.group=='user' and state.commands.chardel.group=='admin')
    state.commands.char.fn(state.player)
end)
for _,fullDelete in ipairs({true,false}) do
    test('identity deletion preserves FullCharDelete=' .. tostring(fullDelete), function()
        local state=fixture({config={EnableCommands=true,FullCharDelete=fullDelete}})
        assert(state.invoke(data())==true)
        state.commands.chardel.fn(state.player)
        assert(state.count('query')==1 and state.count('prepare')==(fullDelete and 1 or 0))
        if fullDelete then
            local found=false
            for _,entry in ipairs(state.trace) do
                if entry[1]=='prepare' then assert(entry[3][1]=='{}');found=true end
            end
            assert(found)
        end
        assert(state.invoke(data())==true)
    end)
end
test('deferral deletion preserves the disconnect and wait sequence', function()
    local state=fixture({config={EnableCommands=true,UseDeferrals=true}})
    assert(state.invoke(data())==true)
    state.commands.chardel.fn(state.player)
    assert(state.count('kick')==1 and state.count('query')==1)
    assert(state.count('client','esx_identity:showRegisterIdentity')==0)
end)
test('debug commands preserve names, configuration and values', function()
    local state=fixture({config={EnableDebugging=true}})
    assert(state.invoke(data())==true)
    for _,name in ipairs({'xPlayerGetFirstName','xPlayerGetLastName','xPlayerGetFullName','xPlayerGetSex','xPlayerGetDOB','xPlayerGetHeight'}) do
        assert(state.commands[name].group=='user');state.commands[name].fn(state.player)
    end
    assert(state.count('command')==6)
end)
test('the existing SetPlayerData helper still updates player and state bags', function()
    local state,env=fixture()
    env.SetPlayerData(state.player,{firstName='Custom',lastName='Player',dateOfBirth='01/01/1990',sex='f',height=175})
    assert(state.name=='Custom Player' and state.states.firstName=='Custom' and state.states.sex=='f')
end)
print(('Passed %d identity regressions%s.'):format(cases, BASELINE and ' with matching baseline traces' or ''))
