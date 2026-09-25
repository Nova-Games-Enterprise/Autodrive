local C = NGEAutodrive.Core

-- Native calls are injected so lifecycle rules can run in plain Lua regression tests.
function NGEAutodrive.newController(api, cfg, units)
    local self = { active = nil, state = 'off', reason = 'idle', speed = cfg.Default }

    function self:stop(reason, state)
        local active = self.active
        self.active = nil
        self.state = state or 'interrupted'
        self.reason = reason
        if active then api.stop(active.ped, active.vehicle) end
    end

    function self:setSpeed(speed)
        self.speed = C.clamp(speed, cfg.Min, cfg.Max)
        if self.active then api.speed(self.active.ped, C.toMps(self.speed, units), self.active.vehicle) end
    end

    function self:start(ctx, destination, now, safety)
        if self.active then self:stop('driver_cancelled', 'off'); return true end
        if not ctx or ctx.hasControl ~= true then return false, 'driver_required' end
        if not C.finite(ctx.signedSpeed) or not C.finite(now) then return false, 'invalid_state' end
        if safety ~= 'ready' then return false, 'fresh_clear_sensor_required' end
        if C.direction(ctx.signedSpeed) == -1 then return false, 'forward_motion_required' end
        local distance = C.distance(ctx.coords, destination)
        if not distance or distance > 20000 then return false, 'valid_waypoint_required' end
        if distance <= cfg.ArrivalDistance then return false, 'already_at_destination' end
        local dest = { x = destination.x, y = destination.y, z = destination.z }
        api.start(ctx.ped, ctx.vehicle, dest, C.toMps(self.speed, units), cfg.DrivingStyle)
        self.active = { ped = ctx.ped, vehicle = ctx.vehicle, destination = dest,
            bestDistance = distance, progressAt = now, startedAt = now }
        self.state, self.reason = 'driving', 'route_active'
        return true
    end

    function self:tick(ctx, destination, now, manual, safety)
        local a = self.active
        if not a then return end
        if not ctx or ctx.ped ~= a.ped or ctx.vehicle ~= a.vehicle or not ctx.hasControl then
            self:stop('driver_or_vehicle_changed'); return
        end
        if not C.finite(now) then self:stop('invalid_clock'); return end
        if manual then self:stop('manual_override'); return end
        if api.running and now - a.startedAt > 250 and not api.running(a.ped, a.vehicle) then
            self:stop('drive_task_interrupted'); return
        end
        local destinationDelta = C.distance(destination, a.destination)
        if not destinationDelta then self:stop('waypoint_removed'); return end
        if destinationDelta > 1 then self:stop('waypoint_changed'); return end
        if safety ~= 'ready' then self:stop('assistance_' .. safety); return end
        local distance = C.distance(ctx.coords, a.destination)
        if not distance or not C.finite(ctx.signedSpeed) then self:stop('invalid_state'); return end
        if distance <= cfg.ArrivalDistance and math.abs(ctx.signedSpeed) <= 1 then
            self:stop('destination_reached', 'arrived'); return
        end
        if now < a.progressAt then self:stop('clock_reset'); return end
        if distance < a.bestDistance - 0.5 then
            a.bestDistance, a.progressAt = distance, now
        elseif now - a.progressAt >= cfg.StallTimeoutMs then
            self:stop('no_route_progress')
        end
    end

    return self
end
