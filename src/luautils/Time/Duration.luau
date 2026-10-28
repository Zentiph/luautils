--!strict

-- Duration type
-- by @vuppyan

local Core = require("../Core")
local repr = require("../_internal").repr

--- A fixed-length span of time with nanosecond precision and no upper bound.
---
--- Internally, a `Duration` is represented by two `number` fields. The first
--- represents whole seconds with any sign, unbounded. The second represents a
--- nanosecond adjustment in [0, 999_999_999], which is always non-negative,
--- since the sign of the `Duration` lives in the seconds field. This avoids
--- float64 mantissa loss, as a single `number` storing nanoseconds closes
--- precision beyond ~104 days. Splitting into seconds and nanoseconds gives
--- exact time arithmetic at both scales without any practical upper limit.
---
--- @class Duration
local Duration = {}
Duration.__index = Duration

type DurationData = {
    read _secs: number,
    read _nanos: number,
}

--- A fixed-length span of time.
---
--- @type Duration Duration
--- @within Duration
export type Duration = typeof(setmetatable({} :: DurationData, Duration))
