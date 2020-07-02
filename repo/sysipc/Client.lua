local FileDispatch = require("sysipc.FileDispatch")

local Client = {}

function Client:__init(router, name)
    self.router = router
    self.name = name
    self.server_dispatch = FileDispatch(self:server_address())
    self.request = FileDispatch(self:server_address()..".request")
    self.response = FileDispatch(self:server_address()..".response")
    return self
end

function Client:server_address()
    return self.router.name.."/"..self.name
end

function Client:call(method, args)
    if args == nil then args = {} end
    local ret, err
    if type(method) == "string" and type(args) == "table" then
        err = self.server_dispatch:lock()
        if err == nil then
            local req = {}
            req.call_id = os.time() + math.floor(os.clock() * 1000) -- guaranteed to be unique although not random
            req.method = method
            req.args = args
            err = self.request:send(req, true)
            if err == nil then
                while self.server_dispatch:is_locked() and not self.response:exists() do end
                if self.server_dispatch:is_locked() then
                    err = self.response:lock()
                    if err == nil then
                        local res
                        res, err = self.response:receive()
                        if err == nil then
                            if req.call_id == res.call_id then
                                self.response:remove()
                                ret = res["return"]
                                if type(res.error) == "string" and #res.error > 0 then
                                    err = "remote: "..res.error
                                end
                            else
                                err = "server responded with different call ID"
                            end
                        end
                        self.response:unlock()
                    end
                else
                    err = "server was unlocked by another process"
                end
            end
            self.server_dispatch:unlock()
        end
    else
        err = "invalid argument types supplied to Client.call()"
    end
    return ret, err
end

return function(router, name)
    local self = {}
    for k, v in pairs(Client) do
        if type(v) == "function" then
            self[k] = v
        end
    end
    return self:__init(router, name)
end
