local json = require("json")
local errors = require("sysipc.errors") -- to suppress 3rd-party library errors (to provide friendly support for locking mechanism)

local FileDispatch = {}

function FileDispatch:__init(name)
    self.name = name
    self.lockname = name..".lock"
    return self
end

function FileDispatch:exists()
    local f = io.open(self.name)
    if f ~= nil then
        f:close()
        return true
    end
    return false
end

function FileDispatch:remove()
    os.remove(self.name)
end

function FileDispatch:is_locked()
    local f = io.open(self.lockname)
    if f ~= nil then
        f:close()
        return true
    end
    return false
end

function FileDispatch:lock()
    local err
    while self:is_locked() do end
    local f = io.open(self.lockname, "w")
    if f ~= nil then
        f:close()
    else
        err = "unable to lock "..self.name
    end
    return err
end

function FileDispatch:unlock()
    if self:is_locked() then
        os.remove(self.lockname)
    end
end

function FileDispatch:send(obj, lock)
    if lock == nil then lock = false end
    local err
    if lock then
        err = self:lock()
    end
    if err == nil then
        local f = io.open(self.name, "w")
        if f ~= nil then
            errors.suppress(true)
            f:write(json.encode(obj))
            errors.suppress(false)

            f:flush()
        else
            err = "unable to write "..self.name
        end
    end
    if lock then
        self:unlock()
    end
end

function FileDispatch:receive(lock)
    if lock == nil then lock = false end
    local obj, err
    if lock then
        err = self:lock()
    end
    if err == nil then
        local f = io.open(self.name, "r")
        if f ~= nil then
            local size = f:seek("end")
            f:seek("set")

            errors.suppress(true)
            obj = json.decode(f:read(size))
            errors.suppress(false)

            if obj == nil then
                err = "unable to parse JSON on "..self.name
            end
        else
            err = "unable to read "..self.name
        end
        if lock then
            self:unlock()
        end
    end
    return obj, err
end

return function(name)
    local self = {}
    for k, v in pairs(FileDispatch) do
        if type(v) == "function" then
            self[k] = v
        end
    end
    return self:__init(name)
end
