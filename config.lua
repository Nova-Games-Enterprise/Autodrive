-- NGE Autodrive recovery preview. Distances: metres; policy speeds: metres/second.
-- No paid module installation is available in this increment.
Config = {
    Units = 'kmh',
    Vehicles = { sultan = true, tesla = true, gbschwartzers = true },
    Cruise = { Default = 50, Min = 20, Max = 80, Step = 5,
        DrivingStyle = 786603, ArrivalDistance = 8, StallTimeoutMs = 30000 },
    Safety = { Enabled = true, MinSpeed = 0.5,
        EmergencyDistance = 4, WarningDistance = 10,
        ReverseEmergencyDistance = 2, ReverseWarningDistance = 5 },
    Sensor = { IntervalMs = 50, MaxAgeMs = 250, Range = 30, Radius = 0.35 },
    Hud = { IntervalMs = 100, HeartbeatMs = 1000, Audio = false },
    Keys = { Toggle = 'K', Assistance = 'J', Faster = 'PAGEUP', Slower = 'PAGEDOWN' }
}
