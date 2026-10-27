local count = 0
local function test(name, fn)
    local ok, err=pcall(fn)
    assert(ok, name .. ': ' .. tostring(err))
    count=count+1;print('PASS ' .. name)
end
local function stable(value)
    if type(value)~='table' then return type(value) .. ':' .. tostring(value) end
    local keys,parts={},{}
    for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
    for _,key in ipairs(keys) do parts[#parts+1]=stable(key)..'='..stable(value[key]) end
    return '{' .. table.concat(parts,',') .. '}'
end
local function fixture(options)
    options=options or {}
    local env=setmetatable({}, {__index=_G})
    local state={sets={},events={},writes={},now=1000,row={ssn='11111111111',accounts={},job='unemployed',job_grade=0,group='user',
        metadata={},position={x=1,y=2,z=3,heading=0},firstname='Test',lastname='Name',sex='m',height=180}}
    env.Config={MaxWeight=100,Identifier='license',Multichar=true,Identity=true,StartingAccountMoney={bank=100},
        Accounts={bank={label='Bank'}},DefaultSpawns={{x=1,y=2,z=3}},DefaultJobDuty=false}
    if options.multichar==false then env.Config.Multichar=false end
    env.Config.StartingInventoryItems=options.inventory
    env.Core={IsPlayerAdmin=function()return false end,generateSSN=function()return'11111111111'end,
        PlayerFunctionOverrides={},playersByIdentifier={},RegisteredCommands={},PlayerClass={}}
    env.ESX={Players={},Jobs={unemployed={id=1,name='unemployed',label='Unemployed',type='civ',grades={['0']={name='unemployed',label='Unemployed',salary=0,skin_male={},skin_female={}}}}},
        Math={Random=function()return 1 end},DoesJobExist=function()return true end}
    env.ESX.GetPlayerFromId=function(id)return env.ESX.Players[id]end
    env.ESX.GetPlayerFromIdentifier=function(identifier)return env.Core.playersByIdentifier[identifier]end
    env.GetPlayerName=function()return'Test Name'end
    env.GetConvar=function(_,fallback)return fallback end
    env.GetGameTimer=function()return state.now end
    env.GetPlayerPed=function()return 0 end
    env.GetPlayerTimeOnline=function()return 0 end
    env.ExecuteCommand=function()end
    env.exports=function()end
    env.print=function()end
    env.DropPlayer=function(_,reason)error(reason)end
    env.TriggerEvent=function(name,...)state.events[#state.events+1]={name=name,args=table.pack(...)}end
    env.TriggerClientEvent=function(name,target,...)state.events[#state.events+1]={name=name,target=target,args=table.pack(...)}end
    env.Player=function()return{state={set=function(_,key,value)state.sets[key]=value end}}end
    env.GlobalState={}
    env.Wait=function()error('unexpected asynchronous wait')end
    env.CreateThread=function(fn)fn()end
    env.json={encode=stable,decode=function(value)return value=='countries' and COUNTRIES or type(value)=='table' and value or {} end}
    env.LoadResourceFile=function(resource,file)assert(resource=='esx_lib' and file=='imports/nationality/countries.json');return'countries'end
    env.xLib={isEnhanced=function()return false end}
    env.xLib.nationality=assert(load(SOURCES.nationality,'nationality','t',env))()
    env.MySQL={prepare=setmetatable({await=function(query,params)
        if query:find('INSERT',1,true) then
            state.insert=params;state.row.nationality=params[10]~='' and params[10] or nil
            return 1
        end
        return state.row
    end},{__call=function(_,query,params,cb)
        state.writes[#state.writes+1]={query=query,params=params}
        assert(params[10]=='license:test' and #params==10)
        state.row.nationality=params[9]~='' and params[9] or nil
        cb(1)
    end})}
    for _,name in ipairs({'base','player','context','create','load','save'}) do assert(load(SOURCES[name],name,'t',env))() end
    local class=env.Core.PlayerClass
    class.AttachAccounts=function(self)
        self.getAccounts=function()return self.accounts end;self.getMoney=function()return 100 end
    end
    class.AttachInventory=function(self)
        self.getInventory=function()return self.inventory end;self.getWeight=function()return self.weight end
        self.getMaxWeight=function()return self.maxWeight end
    end
    class.AttachJob=function()end
    class.AttachWeapons=function(self)self.getLoadout=function()return self.loadout end end
    class.AttachNotifications=function()end
    class.AttachMetadata=function(self)self.getMeta=function()return self.metadata end end
    class.BuildInventory=function()return{},0 end
    env.Core.PlayerSession.IsPlayerLoadActive=function()return true end
    function state.load(nationality)
        state.row.nationality=nationality
        env.ESX.Players={};env.Core.playersByIdentifier={}
        env.loadESXPlayer('license:test',7,false)
        local player=assert(env.ESX.Players[7]);player.spawned=true
        return player
    end
    function state.save(player)
        local done=false
        env.Core.SavePlayer(player,function(ok)assert(ok);done=true end)
        assert(done)
    end
    return env,state
end

test('country allowlist normalizes every supported country and rejects malformed values',function()
    local env=fixture()
    for _,country in ipairs(COUNTRIES) do assert(env.xLib.nationality.normalize(country.value)==country.value)end
    assert(env.xLib.nationality.normalize('  sPaIn  ')=='Spain')
    for _,value in ipairs({'','Atlantis',{},true,5,string.rep('a',53)})do assert(not env.xLib.nationality.normalize(value))end
end)
test('saved nationality is restored in xPlayer, state bags and player-loaded payload',function()
    local env,state=fixture();local player=state.load('Spain')
    assert(player.getNationality()=='Spain' and player.nationality=='Spain' and state.sets.nationality=='Spain')
    local found=false
    for _,event in ipairs(state.events)do
        if event.name=='esx:playerLoaded' and event.target==7 then assert(event.args[1].nationality=='Spain');found=true end
    end
    assert(found)
end)
test('legacy NULL country loads and saves without changing the identity',function()
    local _,state=fixture();local player=state.load(nil)
    assert(player.getNationality()==nil and player.getName()=='Test Name')
    state.save(player);assert(state.writes[1].params[9]=='' and state.row.nationality==nil)
end)
test('changing nationality bypasses unchanged-save suppression and survives reconnect',function()
    local _,state=fixture();local player=state.load('Spain')
    state.save(player);state.save(player);assert(#state.writes==1)
    assert(player.setNationality('Mexico'))
    state.save(player);assert(#state.writes==2 and state.row.nationality=='Mexico')
    local reconnected=state.load(state.row.nationality)
    assert(reconnected.getNationality()=='Mexico')
end)
test('invalid setter values do not alter data or trigger another save',function()
    local _,state=fixture();local player=state.load('Spain');state.save(player)
    assert(player.setNationality("Spain'; DROP TABLE users; --")==false)
    assert(player.setNationality({})==false and player.getNationality()=='Spain')
    state.save(player);assert(#state.writes==1)
end)
test('clearing nationality persists SQL NULL and updates client/state',function()
    local _,state=fixture();local player=state.load('Spain');state.save(player)
    assert(player.setNationality(nil));state.save(player)
    assert(state.row.nationality==nil and state.writes[2].params[9]=='')
    assert(state.writes[2].query:find('NULLIF',1,true) and state.sets.nationality==nil)
    local found=false
    for _,entry in ipairs(state.events)do
        if entry.name=='esx:updatePlayerData' and entry.args[1]=='nationality' then found=true end
    end
    assert(found)
end)
test('new multichar inserts align nationality SQL parameters',function()
    local env,state=fixture()
    env.Core.PlayerSession.CreateESXPlayer('license:test',7,{firstname='Test',lastname='Name',dateofbirth='01/01/1990',sex='m',height=180,nationality='colombia'})
    assert(state.insert[10]=='Colombia' and #state.insert==10)
    assert(env.ESX.Players[7].getNationality()=='Colombia')
end)
test('nationality migration runs independently of old version markers and is idempotent',function()
    local env=fixture();local exists=false;local alters=0
    env.GetResourceKvpInt=function()error('must not use a previous version marker')end
    env.MySQL.query={await=function(query)
        if query:find('ALTER TABLE',1,true)then exists=true;alters=alters+1;return{}end
        return exists and {{DATA_TYPE='varchar',CHARACTER_MAXIMUM_LENGTH=52}} or {}
    end}
    env.xLib.schema=assert(load(SOURCES.schema,'schema','t',env))()
    assert(load(SOURCES.migration,'migration','t',env))()
    assert(env.Core.Migrations['v1.17.1'].nationality()==true)
    assert(env.Core.Migrations['v1.17.1'].nationality()==false and alters==1)
end)
test('starting inventory follows nationality without shifting INSERT values',function()
    local env,state=fixture({inventory={bread=2}})
    env.Core.PlayerSession.CreateESXPlayer('license:test',7,{firstname='Test',lastname='Name',dateofbirth='01/01/1990',sex='m',height=180,nationality='Spain'})
    assert(state.insert[10]=='Spain' and state.insert[11]==stable({bread=2}) and #state.insert==11)
end)
test('creation without multichar keeps the original parameter list',function()
    local env,state=fixture({multichar=false})
    env.Core.PlayerSession.CreateESXPlayer('license:test',7)
    assert(#state.insert==4 and env.ESX.Players[7].getNationality()==nil)
end)
test('catalog startup adds the country column before exposing readiness',function()
    local env=fixture();local exists=false;local altered=0;local ready=0
    local catalog=assert(load(SOURCES.catalog,'catalog','t',env))()
    local db={
        scalar={await=function(query)
            if query:find('SELECT ENGINE',1,true)then return'InnoDB'end
            if query:find('information_schema.COLUMNS',1,true)then return exists and 1 or 0 end
            return 1
        end},
        query={await=function(query)
            if query:find('ALTER TABLE `users` ADD COLUMN `nationality`',1,true)then exists=true;altered=altered+1 end
            return{}
        end},
        single={await=function()return{version='test',locale='default'}end},
        transaction={await=function()return true end},
    }
    local reconcile=catalog.service(db,{version='test',keys={},schemas={},resources={es_extended={schema={},columns={NATIONALITY_COLUMN},seeds={},locales={}}}},function()
        assert(exists);ready=ready+1
    end)
    reconcile('es_extended','en');reconcile('es_extended','en')
    assert(altered==1 and ready==2)
end)
print(('Passed %d nationality persistence regressions.'):format(count))
