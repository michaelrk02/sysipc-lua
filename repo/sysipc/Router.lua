local Router = {}

function Router:__init(name)
    self.name = name
    return self
end

return function(name)
    local self = {}
    for k, v in pairs(Router) do
        if type(v) == "function" then
            self[k] = v
        end
    end
    return self:__init(name)
end
