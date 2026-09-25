local test, eq, copy = ...

local function fixture(configure)
    local s = { now=0,ped=1,vehicle=10,driver=true,authority=true,control=true,driveable=true,
        model='sultan',signedSpeed=5,coords={x=0,y=0,z=0},destination={x=100,y=0,z=0},
        pending=false,hit=false,distance=20,manual=false,axis=0,task=false }
    local calls = { starts=0,stops=0,speeds={},controls={},messages={},probes=0,commands={},keys={},events={},threads={} }
    local queries={}
    local env=setmetatable({ NGEAutodrive={}, print=function() end },{__index=_G})
    local function load(path) assert(loadfile(path,'t',env))() end
    env.GetHashKey=function(name) return name end
    env.PlayerPedId=function() return s.ped end
    env.PlayerId=function() return 1 end
    env.DoesEntityExist=function(id) return id ~= 0 end
    env.IsEntityDead=function() return s.dead or false end
    env.IsPlayerControlOn=function() return s.control end
    env.GetVehiclePedIsIn=function() return s.vehicle end
    env.GetPedInVehicleSeat=function() return s.driver and s.ped or 999 end
    env.GetEntityModel=function() return s.model end
    env.IsVehicleDriveable=function() return s.driveable end
    env.NetworkHasControlOfEntity=function() return s.authority end
    env.GetEntityCoords=function() return s.coords end
    env.GetEntitySpeedVector=function() return {x=0,y=s.signedSpeed,z=0} end
    env.GetModelDimensions=function() return {x=-1,y=-2,z=-0.5},{x=1,y=2,z=1} end
    env.GetOffsetFromEntityInWorldCoords=function(_,x,y,z)
        return {x=s.coords.x+x,y=s.coords.y+y,z=s.coords.z+z}
    end
    env.StartShapeTestCapsule=function(x,y,z,tx,ty,tz,radius,mask,ignored,options)
        eq(mask,31); eq(ignored,s.vehicle); eq(options,7)
        calls.probes=calls.probes+1
        queries[calls.probes]={x=x,y=y,z=z,direction=ty>y and 1 or -1}
        return calls.probes
    end
    env.GetShapeTestResult=function(handle)
        if s.sensorError then error('injected native failure') end
        if s.pending then return 1,false,{x=0,y=0,z=0} end
        local q=assert(queries[handle])
        return 2,s.hit,{x=q.x,y=q.y+q.direction*s.distance,z=q.z}
    end
    env.IsWaypointActive=function() return s.destination ~= nil end
    env.GetFirstBlipInfoId=function() return 8 end
    env.GetBlipInfoIdCoord=function() return s.destination end
    env.TaskVehicleDriveToCoordLongrange=function() calls.starts=calls.starts+1; s.task=true end
    env.GetScriptTaskStatus=function() return s.taskStatus or (s.task and 1 or 7) end
    env.ClearPedTasks=function() calls.stops=calls.stops+1; s.task=false end
    env.SetDriveTaskCruiseSpeed=function(ped,speed) calls.speeds[#calls.speeds+1]=speed end
    env.IsControlPressed=function() return s.manual end
    env.GetControlNormal=function() return s.axis end
    env.DisableControlAction=function() end
    env.SetControlNormal=function(_,control,value)
        calls.controls[#calls.controls+1]={control=control,value=value,at=s.now}
    end
    env.IsPauseMenuActive=function() return s.paused or false end
    env.IsNuiFocused=function() return s.focused or false end
    env.GetGameTimer=function() return s.now end
    env.BeginTextCommandThefeedPost=function() end
    env.AddTextComponentSubstringPlayerName=function() end
    env.EndTextCommandThefeedPostTicker=function() end
    env.SendNUIMessage=function(m) calls.messages[#calls.messages+1]=m end
    env.RegisterCommand=function(name,fn,restricted) calls.commands[name]={fn=fn,restricted=restricted} end
    env.RegisterKeyMapping=function(command,label,mapper,key) calls.keys[command]=key end
    env.AddEventHandler=function(name,fn) calls.events[name]=fn end
    env.GetCurrentResourceName=function() return 'nge_autodrive' end
    env.CreateThread=function(fn) calls.threads[#calls.threads+1]=coroutine.create(fn) end
    env.Wait=function() coroutine.yield() end
    -- Any attempt to restore unsafe network/economy operations fails this harness.
    for _,name in ipairs({'RegisterNetEvent','TriggerServerEvent','TriggerClientEvent',
        'SetVehicleBrake','SetVehicleHandbrake','PerformHttpRequest'}) do
        env[name]=function() error('forbidden API in recovery preview: '..name) end
    end
    load('config.lua'); if configure then configure(env.Config) end
    load('shared/core.lua'); load('client/sensors.lua'); load('client/controller.lua')
    load('client/hud.lua'); load('client/main.lua')
    local function frame(time)
        s.now=time
        for _,co in ipairs(calls.threads) do
            local ok,why=coroutine.resume(co); assert(ok,why)
        end
    end
    local function command(name) assert(calls.commands[name],name).fn() end
    return s,calls,frame,command,env,load
end

test('runtime boots only the expected remappable commands', function()
    local _,c,frame=fixture(); frame(0); frame(50)
    eq(c.keys.nge_ad_toggle,'K'); eq(c.keys.nge_ad_assistance,'J')
    eq(c.keys.nge_ad_faster,'PAGEUP'); eq(c.keys.nge_ad_slower,'PAGEDOWN')
    eq(#c.threads,1)
end)
test('runtime starts on fresh data and changes actual native speed', function()
    local _,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    eq(c.starts,1); cmd('nge_ad_faster'); eq(#c.speeds,1)
    assert(math.abs(c.speeds[1]-55/3.6)<0.000001)
end)
test('runtime manual input cancels the owned drive task', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    s.manual=true; frame(100); eq(c.stops,1)
end)
test('runtime never clears an unrelated task', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    s.taskStatus=7; s.manual=true; frame(100); eq(c.stops,0)
end)
test('runtime speed key cannot target a task after vehicle change', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    s.vehicle=11; cmd('nge_ad_faster'); eq(#c.speeds,0)
end)
test('runtime forward obstacle uses brake and releases on clear sample', function()
    local s,c,frame=fixture(); s.hit=true; s.distance=1
    frame(0); frame(50); eq(c.controls[#c.controls].control,72)
    local count=#c.controls; s.hit=false; frame(100); eq(#c.controls,count)
end)
test('runtime reverse obstacle uses reverse-direction braking', function()
    local s,c,frame=fixture(); s.signedSpeed=-5; s.hit=true; s.distance=1
    frame(0); frame(50); eq(c.controls[#c.controls].control,71)
end)
test('runtime query work is bounded when a native never completes', function()
    local s,c,frame=fixture(); s.pending=true
    for t=0,10000,10 do frame(t) end
    eq(c.probes,1); eq(#c.controls,0)
end)
test('runtime sensor loss cancels drive and never invents a clear result', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    s.pending=true; frame(100); frame(400); eq(c.stops,1)
    eq(c.messages[#c.messages].safety,'unavailable')
end)
test('runtime change to passenger disables assistance', function()
    local s,c,frame=fixture(); s.hit=true; s.distance=1; frame(0); frame(50)
    local count=#c.controls; s.driver=false; frame(200)
    eq(#c.controls,count); eq(c.messages[#c.messages].visible,false)
end)
test('runtime loses network authority without taking control back', function()
    local s,c,frame=fixture(); frame(0); frame(50); s.authority=false; frame(200)
    eq(c.messages[#c.messages].visible,false); eq(#c.controls,0)
end)
test('runtime stopped vehicle receives no acceleration/braking input', function()
    local s,c,frame=fixture(); s.signedSpeed=0; s.hit=true; s.distance=0.1
    frame(0); frame(50); eq(#c.controls,0)
end)
test('runtime resource stop hides HUD and cancels its own task', function()
    local _,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    c.events.onResourceStop('unrelated'); eq(c.stops,0)
    c.events.onResourceStop('nge_autodrive'); eq(c.stops,1)
    eq(c.messages[#c.messages].visible,false)
end)
test('runtime disabled assistance stops new sensor work', function()
    local _,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_assistance')
    frame(100); local probes=c.probes; frame(500); frame(1000); eq(c.probes,probes)
end)
test('invalid configuration starts no control thread or keybind', function()
    local _,c=fixture(function(cfg) cfg.Cruise.Max=0/0 end)
    eq(#c.threads,0); eq(next(c.commands),nil)
end)
test('server preview exposes no install or full-table sync network events', function()
    local _,c,_,_,_,load=fixture(); load('server/main.lua')
    eq(c.commands.nge_autodrive_status.restricted,true)
    eq(c.events['smartcar:installModuleOnVehicle'],nil)
    eq(c.events['smartcar:requestModules'],nil)
    c.events.onResourceStart('nge_autodrive')
end)
test('legacy install flag cannot reopen an unsafe endpoint', function()
    local _,c,_,_,env,load=fixture()
    env.Config.MechanicModule={Enabled=true,RequireJob=false}
    load('server/main.lua'); eq(c.events['smartcar:installModuleOnVehicle'],nil)
end)

test('runtime cannot start waypoint drive toward a stationary obstruction', function()
    local s,c,frame,cmd=fixture(); s.signedSpeed=0; s.hit=true; s.distance=0.1
    frame(0); frame(50); cmd('nge_ad_toggle'); eq(c.starts,0); eq(#c.controls,0)
end)
test('runtime detects an externally interrupted drive task without clearing it', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    s.task=false; frame(400); eq(c.stops,0)
    eq(c.messages[#c.messages].reason,'drive_task_interrupted')
end)
for _,field in ipairs({'paused','focused'}) do
    test('runtime releases assistance when '..field, function()
        local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
        s[field]=true; frame(200); eq(c.stops,1); eq(c.messages[#c.messages].visible,false)
    end)
end
test('runtime native failure cancels owned task and prevents restart until reload', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); cmd('nge_ad_toggle')
    s.sensorError=true
    frame(200); frame(250); eq(c.stops,1); eq(c.messages[#c.messages].visible,false)
    cmd('nge_ad_toggle'); eq(c.starts,1)
end)
test('runtime changed ped cannot reuse a fresh sensor result for the same vehicle', function()
    local s,c,frame,cmd=fixture(); frame(0); frame(50); s.ped=2
    cmd('nge_ad_toggle'); eq(c.starts,0)
end)

test('manifest paths exist, are local, explicit, and all Lua scripts compile', function()
    local scripts,files={},{}
    local function add(target,value)
        if type(value)=='table' then for _,v in ipairs(value) do add(target,v) end
        else target[#target+1]=value end
    end
    local env={}
    for _,name in ipairs({'fx_version','game','name','author','description','version'}) do env[name]=function() end end
    for _,name in ipairs({'shared_scripts','client_scripts','server_script'}) do
        env[name]=function(value) add(scripts,value) end
    end
    env.files=function(value) add(files,value) end
    local ui
    env.ui_page=function(value) ui=value end
    assert(loadfile('fxmanifest.lua','t',env))()
    eq(ui,'html/index.html'); eq(#scripts,7)
    local seen={}
    for _,path in ipairs(scripts) do
        assert(not seen[path], 'duplicate script'); seen[path]=true
        assert(not path:find('..',1,true) and not path:find('*',1,true))
        assert(loadfile(path),path..' syntax error')
    end
    for _,path in ipairs(files) do local f=assert(io.open(path,'rb'),path); f:close() end
    assert(not seen['client.lua'] and not seen['server.lua'], 'legacy entrypoint still active')
end)
