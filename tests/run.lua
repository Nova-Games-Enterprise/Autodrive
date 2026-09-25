-- Dependency-free regression suite. Run from the repository root with Lua 5.4.
assert(_VERSION == 'Lua 5.4', 'Tests require Lua 5.4')
local passed, failed = 0, 0
local function test(name, fn)
    local ok, why = xpcall(fn, debug.traceback)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; io.stderr:write('FAIL ' .. name .. '\n' .. why .. '\n') end
end
local function eq(a, b)
    assert(a == b, 'expected ' .. tostring(b) .. ', received ' .. tostring(a))
end
local function near(a, b) assert(math.abs(a - b) < 0.000001, 'numbers differ') end
local function copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end

dofile('config.lua')
dofile('shared/core.lua')
dofile('client/controller.lua')
dofile('client/hud.lua')
local C = NGEAutodrive.Core
local origin = {x=0,y=0,z=0}

test('default configuration validates', function() eq(C.validate(Config), true) end)
test('finite rejects NaN, infinities, strings, booleans and nil', function()
    for _, v in ipairs({0/0, math.huge, -math.huge, '5', true, {}}) do eq(C.finite(v), false) end
    eq(C.finite(nil), false); eq(C.finite(0), true)
end)
test('speed conversions use km/h and exact mph factor', function()
    near(C.toMps(36, 'kmh'), 10); near(C.toMps(60, 'mph'), 26.8224)
end)
test('direction has a standstill deadband', function()
    eq(C.direction(2), 1); eq(C.direction(-2), -1); eq(C.direction(0.1), 0)
    eq(C.direction(-0.1), 0); eq(C.direction(0/0), 0)
end)
test('distance rejects invalid coordinates', function()
    eq(C.distance(nil, origin), nil); eq(C.distance({x=0,y=0,z=math.huge}, origin), nil)
    near(C.distance({x=3,y=4,z=0}, origin), 5)
end)
for name, change in pairs({
    units=function(c) c.Units='knots' end,
    nan=function(c) c.Cruise.Max=0/0 end,
    negative=function(c) c.Sensor.IntervalMs=-1 end,
    order=function(c) c.Cruise.Default=c.Cruise.Max+1 end,
    warning=function(c) c.Safety.WarningDistance=1 end,
    age=function(c) c.Sensor.MaxAgeMs=c.Sensor.IntervalMs end,
    bool=function(c) c.Hud.Audio='yes' end,
    vehicle=function(c) c.Vehicles['INVALID NAME']=true end,
    key=function(c) c.Keys.Toggle='a;b' end,
    missing=function(c) c.Sensor=nil end,
    style=function(c) c.Cruise.DrivingStyle=0.5 end,
    range=function(c) c.Sensor.Range=5 end
}) do
    test('invalid config rejected: '..name, function()
        local c=copy(Config); change(c); eq(C.validate(c), false)
    end)
end
test('missing configuration fails closed', function() eq(C.validate(nil), false); eq(C.validate({}), false) end)
test('forward and reverse use different thresholds', function()
    eq(C.classify(8,3,Config.Safety,true), 'brake')
    eq(C.classify(-8,3,Config.Safety,true), 'warning')
    eq(C.classify(-8,1,Config.Safety,true), 'brake')
end)
test('stationary obstacle is not a clear road for waypoint activation', function()
    eq(C.classify(0,0.1,Config.Safety,true), 'brake')
end)
test('missing sensor result is never a clear road', function()
    eq(C.classify(8,nil,Config.Safety,true), 'unavailable')
    eq(C.classify(0,nil,Config.Safety,true), 'unavailable')
    eq(C.classify(8,false,Config.Safety,true), 'ready')
end)
test('malformed sensor distance is unavailable even at rest', function()
    for _, d in ipairs({true, '5', math.huge, 0/0, -1}) do
        eq(C.classify(0,d,Config.Safety,true), 'unavailable')
    end
end)
test('disabled assistance emits no braking request', function()
    eq(C.classify(8,0,Config.Safety,false), 'off')
end)
test('bounded deterministic distance/speed policy sweep', function()
    local states={ready=true,warning=true,brake=true,off=true,unavailable=true}
    for speed=-20,20 do for distance=0,60 do
        assert(states[C.classify(speed,distance,Config.Safety,true)])
    end end
end)

local function probeFixture()
    local status, hit, coords = 1, false, origin
    local starts = 0
    local p=C.newProbe(function() return status,hit,coords end,250)
    local function start() starts=starts+1; return starts,origin end
    local function finish(s,h,c) status=s; hit=h; coords=c or origin end
    return p,start,finish,function() return starts end
end
test('pending probe is not consumed as an empty result', function()
    local p,start,finish=probeFixture(); p:start('a',0,start); p:poll(50)
    eq(p:get('a',50),nil); assert(p.pending)
    finish(2,false); p:poll(100); eq(p:get('a',100),false)
end)
test('world hit is accepted without an entity handle', function()
    local p,start,finish=probeFixture(); p:start('a',0,start)
    finish(2,true,{x=3,y=4,z=0}); p:poll(50); near(p:get('a',50),5)
end)
test('numeric native hit value is supported', function()
    local p,start,finish=probeFixture(); p:start('a',0,start)
    finish(2,1,{x=0,y=1,z=0}); p:poll(50); eq(p:get('a',50),1)
end)
test('invalid native query is unavailable', function()
    local p,start,finish=probeFixture(); p:start('a',0,start); finish(0,false); p:poll(50)
    eq(p:get('a',50),nil); eq(p.pending,nil)
end)
test('stalled query cannot allocate additional handles', function()
    local p,start,_,count=probeFixture(); p:start('a',0,start)
    for now=1,10000 do p:poll(now); eq(p:start('a',now,start),false) end
    eq(count(),1); eq(p:get('a',10000),nil)
end)
test('late completion is discarded, not timestamped as fresh', function()
    local p,start,finish=probeFixture(); p:start('a',0,start)
    finish(2,false); p:poll(300); eq(p:get('a',300),nil)
end)
test('completed result expires and clock reset invalidates it', function()
    local p,start,finish=probeFixture(); p:start('a',100,start)
    finish(2,false); p:poll(150); eq(p:get('a',350),false)
    eq(p:get('a',351),nil); eq(p:get('a',99),nil)
end)
test('vehicle/direction context cannot reuse another probe', function()
    local p,start,finish=probeFixture(); p:start('a',0,start)
    finish(2,false); p:poll(50); eq(p:get('b',50),nil)
end)
test('invalidated in-flight probe remains drained but cannot publish', function()
    local p,start,finish=probeFixture(); p:start('a',0,start); p:invalidate()
    finish(2,false); p:poll(50); eq(p:get('a',50),nil); eq(p.pending,nil)
end)
test('native failure to allocate a handle is unavailable', function()
    local p=probeFixture(); eq(p:start('a',0,function() return 0,origin end),false)
end)
test('invalid hit coordinates cannot publish a distance', function()
    local p,start,finish=probeFixture(); p:start('a',0,start)
    finish(2,true,{x=0/0,y=0,z=0}); p:poll(50); eq(p:get('a',50),nil)
end)

local function controllerFixture()
    local calls={start=0,stop=0,speed=0}
    local controller=NGEAutodrive.newController({
        start=function() calls.start=calls.start+1 end,
        stop=function(ped,veh) calls.stop=calls.stop+1; calls.stoppedVehicle=veh end,
        speed=function(ped,speed) calls.speed=calls.speed+1; calls.lastSpeed=speed end
    },Config.Cruise,Config.Units)
    local ctx={ped=1,vehicle=10,coords=copy(origin),signedSpeed=5,hasControl=true}
    local dest={x=100,y=0,z=0}
    return controller,calls,ctx,dest
end
test('waypoint drive requires driver, authority and fresh clear sensors', function()
    local d,c,ctx,dest=controllerFixture()
    eq(d:start(nil,dest,0,'ready'),false); ctx.hasControl=false
    eq(d:start(ctx,dest,0,'ready'),false); ctx.hasControl=true
    eq(d:start(ctx,dest,0,'warning'),false); eq(d:start(ctx,nil,0,'ready'),false)
    eq(c.start,0)
end)
test('waypoint drive cannot activate while reversing', function()
    local d,_,ctx,dest=controllerFixture(); ctx.signedSpeed=-2
    eq(d:start(ctx,dest,0,'ready'),false)
end)
test('set speed updates the existing native task and clamps to limit', function()
    local d,c,ctx,dest=controllerFixture(); d:start(ctx,dest,0,'ready'); d:setSpeed(999)
    eq(d.speed,80); eq(c.start,1); eq(c.speed,1); near(c.lastSpeed,80/3.6)
end)
test('set speed before starting creates no native task', function()
    local d,c=controllerFixture(); d:setSpeed(65); eq(c.start,0); eq(c.speed,0)
end)
for _, scenario in ipairs({'manual','vehicle','ped','authority','waypoint_removed','waypoint_changed','sensor','obstacle','clock'}) do
    test('controller cancels on '..scenario, function()
        local d,c,ctx,dest=controllerFixture(); d:start(ctx,dest,100,'ready')
        local now,manual,safety=200,false,'ready'
        if scenario=='manual' then manual=true
        elseif scenario=='vehicle' then ctx.vehicle=11
        elseif scenario=='ped' then ctx.ped=2
        elseif scenario=='authority' then ctx.hasControl=false
        elseif scenario=='waypoint_removed' then dest=nil
        elseif scenario=='waypoint_changed' then dest={x=200,y=0,z=0}
        elseif scenario=='sensor' then safety='unavailable'
        elseif scenario=='obstacle' then safety='brake'
        elseif scenario=='clock' then now=50 end
        d:tick(ctx,dest,now,manual,safety); eq(d.active,nil); eq(c.stop,1)
        d:tick(ctx,dest,now+1,false,'ready'); eq(c.start,1); eq(c.stop,1)
    end)
end
test('arrival requires low speed and correct proximity', function()
    local d,c,ctx,dest=controllerFixture(); d:start(ctx,dest,0,'ready')
    ctx.coords={x=99,y=0,z=0}; d:tick(ctx,dest,100,false,'ready'); eq(c.stop,0)
    ctx.signedSpeed=0; d:tick(ctx,dest,200,false,'ready'); eq(d.state,'arrived'); eq(c.stop,1)
end)
test('no-progress watchdog interrupts route', function()
    local d,c,ctx,dest=controllerFixture(); d:start(ctx,dest,0,'ready')
    d:tick(ctx,dest,30000,false,'ready'); eq(d.reason,'no_route_progress'); eq(c.stop,1)
end)
test('route progress refreshes watchdog', function()
    local d,c,ctx,dest=controllerFixture(); d:start(ctx,dest,0,'ready')
    ctx.coords={x=10,y=0,z=0}; d:tick(ctx,dest,29999,false,'ready')
    d:tick(ctx,dest,30001,false,'ready'); eq(c.stop,0)
end)
test('toggle cancels once without starting another task', function()
    local d,c,ctx,dest=controllerFixture(); d:start(ctx,dest,0,'ready'); d:start(ctx,dest,100,'ready')
    eq(c.start,1); eq(c.stop,1); eq(d.state,'off')
end)
test('destination is copied instead of retaining a mutable reference', function()
    local d,_,ctx,dest=controllerFixture(); d:start(ctx,dest,0,'ready'); dest.x=200
    d:tick(ctx,dest,100,false,'ready'); eq(d.reason,'waypoint_changed')
end)
test('HUD deduplicates frames but emits a recovery heartbeat', function()
    local calls={}; local h=NGEAutodrive.newHud(function(m) calls[#calls+1]=m end,Config.Hud)
    h:update({visible=true},0)
    for t=1,999 do h:update({visible=true},t) end
    eq(#calls,1); h:update({visible=true},1000); eq(#calls,2)
end)
test('HUD changes respect the configured rate ceiling', function()
    local count=0; local h=NGEAutodrive.newHud(function() count=count+1 end,Config.Hud)
    h:update({speed=1},0); h:update({speed=2},50); eq(count,1)
    h:update({speed=2},100); eq(count,2)
end)
test('HUD cleanup hides immediately and copies state defensively', function()
    local sent={}; local h=NGEAutodrive.newHud(function(m) sent[#sent+1]=m end,Config.Hud)
    local value={visible=true}; h:update(value,0); value.visible=false
    eq(h.last.visible,true); h:update(value,1,true); eq(sent[2].visible,false)
end)

test('distance rejects scalars and overflow without throwing', function()
    for _, value in ipairs({true, false, '0', 42}) do eq(C.distance(value,origin),nil) end
    eq(C.distance({x=1e308,y=0,z=0},{x=-1e308,y=0,z=0}),nil)
end)
test('HUD heartbeat cannot exceed the UI stale-data budget', function()
    local cfg=copy(Config); cfg.Hud.HeartbeatMs=2500; eq(C.validate(cfg),false)
end)
test('waypoint activation rejects a non-finite speed or clock', function()
    local d,c,ctx,dest=controllerFixture(); ctx.signedSpeed=0/0
    eq(d:start(ctx,dest,0,'ready'),false); ctx.signedSpeed=0
    eq(d:start(ctx,dest,math.huge,'ready'),false); eq(c.start,0)
end)
assert(loadfile('tests/runtime.lua'))(test,eq,copy)
print(('Lua tests: %d passed, %d failed'):format(passed,failed))
if failed > 0 then os.exit(1) end
