local C = NGEAutodrive.Core

function NGEAutodrive.newSensors(cfg)
    local probe = C.newProbe(GetShapeTestResult, cfg.MaxAgeMs)
    local self = { probe = probe, vehicle = nil, ped = nil, direction = nil, epoch = 0,
        lastStart = -cfg.IntervalMs, front = 2, back = -2 }

    function self:reset()
        self.epoch = self.epoch + 1
        self.vehicle, self.ped, self.direction = nil, nil, nil
        self.lastStart = -cfg.IntervalMs
        probe:invalidate()
    end

    function self:update(ctx, now)
        probe:poll(now)
        if not ctx then
            if self.vehicle then self:reset() end
            return nil
        end
        -- A rear camera/UI flag never selects the safety direction.
        local direction = C.direction(ctx.signedSpeed) == -1 and -1 or 1
        if ctx.vehicle ~= self.vehicle or ctx.ped ~= self.ped or direction ~= self.direction then
            self.epoch = self.epoch + 1
            probe:invalidate()
            self.vehicle, self.ped, self.direction = ctx.vehicle, ctx.ped, direction
            local min, max = GetModelDimensions(GetEntityModel(ctx.vehicle))
            self.front, self.back = max.y + 0.15, min.y - 0.15
            self.lastStart = -cfg.IntervalMs
        end
        local key = tostring(self.epoch) .. ':' .. tostring(ctx.vehicle) .. ':' .. direction
        if now < self.lastStart or now - self.lastStart >= cfg.IntervalMs then
            if probe:start(key, now, function()
                local offset = direction == 1 and self.front or self.back
                local from = GetOffsetFromEntityInWorldCoords(ctx.vehicle, 0, offset, 0.4)
                local to = GetOffsetFromEntityInWorldCoords(ctx.vehicle, 0, offset + direction * cfg.Range, 0.4)
                -- World, vehicles, peds, ragdolls and objects. World hits need no entity handle.
                local handle = StartShapeTestCapsule(from.x, from.y, from.z,
                    to.x, to.y, to.z, cfg.Radius, 31, ctx.vehicle, 7)
                return handle, { x = from.x, y = from.y, z = from.z }
            end) then self.lastStart = now end
        end
        return probe:get(key, now)
    end

    return self
end
