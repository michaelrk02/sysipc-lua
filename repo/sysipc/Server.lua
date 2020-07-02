local FileDispatch = require("sysipc.FileDispatch")

local Server = {}

function Server:__init(router, name, logger)
    self.router = router
    self.name = name
    self.logger = logger
    self.dispatch = FileDispatch(self:address())
    self.request = FileDispatch(self:address()..".request")
    self.response = FileDispatch(self:address()..".response")
    self.handlers = {}
    return self
end

function Server:address()
    return self.router.name.."/"..self.name
end

function Server:handle(method, handler)
    local err
    if self.handlers[method] == nil then
        if type(handler) == "function" then
            self.handlers[method] = handler
        else
            err = "attempted to handle `"..method.."` with non-function"
        end
    else
        err = "handler for "..method.." is already defined"
    end
    return err
end

function Server:handle_methods(object)
    if type(object) == "table" then
        for k, v in pairs(object) do
            if type(v) == "function" then
                self:handle(k, v)
            end
        end
    end
end

function Server:run()
    self.dispatch:unlock()
    self.request:remove()
    self.request:unlock()
    self.response:remove()
    self.response:unlock()
    while true do
        local err = self:_intercept()
        if err ~= nil then
            if self.logger ~= nil then
                self.logger:write(string.format("SysIPC [%s]: %s\n", self:address(), err))
                self.logger:flush()
            end
        end
    end
end

function Server:_intercept()
    local err

    while not self.request:exists() do end

    local req
    self.request:lock()
    req, err = self.request:receive()
    self.request:remove()
    self.request:unlock()
    if err == nil then
        local res = {}
        res.call_id = req.call_id
        res.error = ""

        local handler = self.handlers[req.method]
        if handler ~= nil then
            res["return"], res.error = handler(req.args)
        else
            res.error = "no handler is associated for method: `"..req.method.."`"
        end

        err = self.response:send(res, true)
    end

    return err
end

return function(router, name, logger)
    local self = {}
    for k, v in pairs(Server) do
        if type(v) == "function" then
            self[k] = v
        end
    end
    return self:__init(router, name, logger)
end
