local C = NGEAutodrive.Core

function NGEAutodrive.newHud(send, cfg)
    local self = { last = nil, sentAt = nil }
    function self:update(snapshot, now, force)
        local elapsed = self.sentAt and (now - self.sentAt) or math.huge
        local changed = not C.same(self.last, snapshot)
        if not force and elapsed >= 0 then
            if elapsed < cfg.IntervalMs then return false end
            if not changed and elapsed < cfg.HeartbeatMs then return false end
        end
        local message = { type = 'state', version = 1 }
        self.last = {}
        for k, v in pairs(snapshot) do message[k] = v; self.last[k] = v end
        self.sentAt = now
        send(message)
        return true
    end
    return self
end
