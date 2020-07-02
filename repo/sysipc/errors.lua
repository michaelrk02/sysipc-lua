local errors = {}

errors.n = 0
errors.error = nil
errors.dummy = function() end

function errors.suppress(suppress)
    if suppress then
        errors.n = errors.n + 1
        if errors.n == 1 then
            errors.error = _G.error
            _G.error = errors.dummy
        end
    else
        if errors.n > 0 then
            errors.n = errors.n - 1
            if errors.n == 0 then
                _G.error = errors.error
                errors.error = nil
            end
        end
    end
end

return errors
