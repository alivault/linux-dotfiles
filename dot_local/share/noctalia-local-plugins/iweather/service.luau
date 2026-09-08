local busy = false
local pending = nil
local started = false
local function run(action, payload)
    if busy then pending = { action, payload }; return end
    busy = true
    noctalia.state.set("loading", true)
    local accepted = noctalia.runAsync({ "python3", noctalia.pluginDir() .. "/weather.py",
        "--data-dir", noctalia.pluginDataDir(), action, payload or "" }, function(result)
        busy = false
        local data = nil
        if result.exitCode == 0 and not result.stdoutTruncated and #result.stdout <= 16384 then
            data = noctalia.json.decode(result.stdout)
        end
        data = data or { error = "Weather helper failed. Try refresh." }
        if action == "search" then
            noctalia.state.set("search", data)
        else
            noctalia.state.set("weather", data)
        end
        noctalia.state.set("loading", false)
        if pending then
            local nextRequest = pending
            pending = nil
            run(nextRequest[1], nextRequest[2])
        end
    end)
    if not accepted then
        busy = false
        noctalia.state.set("loading", false)
        noctalia.state.set("weather", { error = "Could not launch weather helper." })
    end
end

noctalia.state.watch("command", function(command)
    if type(command) ~= "table" then return end
    noctalia.state.set("command", nil)
    if command.action == "select" then
        run("select", noctalia.json.encode(command.location))
    elseif command.action == "search" then
        run("search", command.query or "")
    elseif command.action == "units" or command.action == "refresh" then
        run(command.action)
    end
end)

function onIpc(event)
    if event == "refresh" or event == "units" then run(event) end
end

function update()
    noctalia.setUpdateInterval(900000)
    if busy then return end
    run(started and "refresh" or "snapshot")
    started = true
end
