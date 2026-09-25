NGEAutodrive = NGEAutodrive or {}
local C = {}
NGEAutodrive.Core = C

function C.finite(x)
    return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge
end

function C.clamp(x, lo, hi)
    if not C.finite(x) then return lo end
    return math.max(lo, math.min(hi, x))
end

function C.toMps(speed, units)
    return speed * (units == 'mph' and 0.44704 or (1 / 3.6))
end

function C.direction(speed)
    if not C.finite(speed) then return 0 end
    if speed > 0.2 then return 1 end
    if speed < -0.2 then return -1 end
    return 0
end

function C.distance(a, b)
    local ta, tb = type(a), type(b)
    if (ta ~= 'table' and ta ~= 'vector3') or (tb ~= 'table' and tb ~= 'vector3') then return nil end
    for _, k in ipairs({ 'x', 'y', 'z' }) do
        if not C.finite(a[k]) or not C.finite(b[k]) then return nil end
    end
    local distance = math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2 + (a.z - b.z)^2)
    return C.finite(distance) and distance or nil
end

function C.classify(speed, distance, cfg, enabled)
    if not enabled or not cfg.Enabled then return 'off' end
    if not C.finite(speed) then return 'unavailable' end
    -- nil means no fresh result; false is a completed, unobstructed probe.
    if distance == nil then return 'unavailable' end
    if distance ~= false and (not C.finite(distance) or distance < 0) then return 'unavailable' end
    -- Classify nearby obstacles even at rest; only actuation has a minimum speed.
    if distance == false then return 'ready' end
    local backwards = C.direction(speed) == -1
    local emergency = backwards and cfg.ReverseEmergencyDistance or cfg.EmergencyDistance
    local warning = backwards and cfg.ReverseWarningDistance or cfg.WarningDistance
    if distance <= emergency then return 'brake' end
    if distance <= warning then return 'warning' end
    return 'ready'
end

function C.same(a, b)
    if not a or not b then return false end
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

function C.validate(cfg)
    if type(cfg) ~= 'table' then return false, 'configuration must be a table' end
    if cfg.Units ~= 'kmh' and cfg.Units ~= 'mph' then return false, 'invalid units' end
    for _, key in ipairs({ 'Cruise', 'Safety', 'Sensor', 'Hud', 'Keys', 'Vehicles' }) do
        if type(cfg[key]) ~= 'table' then return false, key .. ' must be a table' end
    end
    local bounds = {
        {cfg.Cruise.Default, 1, 160}, {cfg.Cruise.Min, 1, 160},
        {cfg.Cruise.Max, 1, 160}, {cfg.Cruise.Step, 1, 20},
        {cfg.Cruise.DrivingStyle, 0, 2147483647},
        {cfg.Cruise.ArrivalDistance, 1, 20}, {cfg.Cruise.StallTimeoutMs, 5000, 120000},
        {cfg.Safety.MinSpeed, 0.2, 5}, {cfg.Safety.EmergencyDistance, 0.5, 30},
        {cfg.Safety.WarningDistance, 1, 30}, {cfg.Safety.ReverseEmergencyDistance, 0.5, 20},
        {cfg.Safety.ReverseWarningDistance, 1, 30},
        {cfg.Sensor.IntervalMs, 20, 1000}, {cfg.Sensor.MaxAgeMs, 50, 2000},
        {cfg.Sensor.Range, 5, 30}, {cfg.Sensor.Radius, 0.1, 1},
        {cfg.Hud.IntervalMs, 50, 1000}, {cfg.Hud.HeartbeatMs, 250, 2000}
    }
    for _, b in ipairs(bounds) do
        if not C.finite(b[1]) or b[1] < b[2] or b[1] > b[3] then
            return false, 'numeric configuration outside supported bounds'
        end
    end
    if cfg.Cruise.Min > cfg.Cruise.Default or cfg.Cruise.Default > cfg.Cruise.Max
        or cfg.Safety.EmergencyDistance >= cfg.Safety.WarningDistance
        or cfg.Safety.ReverseEmergencyDistance >= cfg.Safety.ReverseWarningDistance
        or cfg.Safety.WarningDistance > cfg.Sensor.Range
        or cfg.Safety.ReverseWarningDistance > cfg.Sensor.Range
        or cfg.Sensor.MaxAgeMs < cfg.Sensor.IntervalMs * 2
        or cfg.Hud.HeartbeatMs < cfg.Hud.IntervalMs then
        return false, 'inconsistent thresholds or intervals'
    end
    if type(cfg.Safety.Enabled) ~= 'boolean' or type(cfg.Hud.Audio) ~= 'boolean' then
        return false, 'feature flags must be boolean'
    end
    if cfg.Cruise.DrivingStyle % 1 ~= 0 then return false, 'driving style must be an integer' end
    for model, enabled in pairs(cfg.Vehicles) do
        if type(model) ~= 'string' or #model < 1 or #model > 64
            or not model:match('^[a-z0-9_]+$') or type(enabled) ~= 'boolean' then
            return false, 'invalid vehicle profile'
        end
    end
    for _, name in ipairs({ 'Toggle', 'Assistance', 'Faster', 'Slower' }) do
        local key = cfg.Keys[name]
        if type(key) ~= 'string' or #key < 1 or #key > 32
            or not key:match('^[A-Z0-9_]+$') then return false, 'invalid key mapping' end
    end
    return true
end

-- A single in-flight native query. Timed-out queries are drained, not replaced
-- repeatedly, so a stalled native cannot cause unbounded handle allocation.
function C.newProbe(resultFn, maxAge)
    local p = { pending = nil, sample = nil }
    function p:invalidate()
        self.sample = nil
        if self.pending then self.pending.discard = true end
    end
    function p:poll(now)
        local q = self.pending
        if not q then return end
        local status, hit, coords = resultFn(q.handle)
        if status == 1 then return end
        self.pending = nil
        if status ~= 2 or q.discard or now < q.at or now - q.at > maxAge then
            self.sample = nil
            return
        end
        local distance = false
        if hit == true or hit == 1 then
            distance = C.distance(q.origin, coords)
            if distance == nil then self.sample = nil; return end
        elseif hit ~= false and hit ~= 0 then
            self.sample = nil
            return
        end
        self.sample = { key = q.key, at = q.at, distance = distance }
    end
    function p:start(key, now, startFn)
        if self.pending then return false end
        local handle, origin = startFn()
        if not C.finite(handle) or handle <= 0 then self.sample = nil; return false end
        self.pending = { handle = handle, origin = origin, key = key, at = now }
        return true
    end
    function p:get(key, now)
        local s = self.sample
        if not s or s.key ~= key or now < s.at or now - s.at > maxAge then return nil end
        return s.distance
    end
    return p
end
