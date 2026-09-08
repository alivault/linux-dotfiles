local editing = false
local query = ""
local render
local function send(action, fields)
    fields = fields or {}
    fields.action = action
    noctalia.state.set("command", fields)
end
local function label(text, size, color, width)
    return ui.label({ text = tostring(text), fontSize = size or 15,
        color = color or "on_surface", width = width, maxLines = 1 })
end
local function degrees(value) return tostring(value) .. "°" end
local function search()
    send("search", { query = query })
end
local function rangeBar(day, low, high)
    local total = math.max(1, high - low)
    local left = math.max(0, (day.low - low) / total * 164)
    local fill = math.max(2, (day.high - day.low) / total * 164)
    local pieces = {}
    if left > 0 then pieces[#pieces + 1] = ui.box({ width = left, height = 5, fill = "surface_variant", radius = 3 }) end
    pieces[#pieces + 1] = ui.image({ path = "gradient.png", width = fill, height = 5, radius = 3, fit = "stretch" })
    local right = math.max(0, 164 - left - fill)
    if right > 0 then pieces[#pieces + 1] = ui.box({ width = right, height = 5, fill = "surface_variant", radius = 3 }) end
    return ui.row({ gap = 0, align = "center", width = 164 }, pieces)
end

render = function()
    local data = noctalia.state.get("weather") or {}
    local loading = noctalia.state.get("loading") == true
    local rows = {}
    rows[#rows + 1] = ui.row({ gap = 4, align = "center" }, {
        ui.button({ text = string.upper(data.name or "CHOOSE LOCATION"), variant = "ghost", flexGrow = 1,
            contentAlign = "start", onClick = function() editing = not editing; render() end }),
        ui.button({ text = "°" .. (data.units or "C"), variant = "ghost", onClick = function() send("units") end }),
        ui.button({ glyph = "refresh", variant = "ghost", enabled = not loading, onClick = function() send("refresh") end }),
    })
    if editing or data.needs_location then
        rows[#rows + 1] = ui.row({ gap = 6 }, {
            ui.input({ key = "city-search", value = query, placeholder = "City or ZIP code", flexGrow = 1,
                focus = true, submitOnEnter = true, onChange = function(value) query = value end,
                onSubmit = function(value) query = value; search() end }),
            ui.button({ glyph = "search", enabled = not loading, onClick = search }),
        })
        local found = noctalia.state.get("search")
        if found then
            if found.error then rows[#rows + 1] = label(found.error, 13, "error") end
            if found.results and #found.results == 0 then rows[#rows + 1] = label("No matching locations.", 13) end
            for _, place in ipairs(found.results or {}) do
                local selected = place
                rows[#rows + 1] = ui.button({ text = place.label, variant = "ghost", contentAlign = "start",
                    onClick = function() editing = false; send("select", { location = selected }); render() end })
            end
        end
    end
    if data.temp ~= nil then
        rows[#rows + 1] = ui.row({ justify = "space_between", align = "center" }, {
            label(degrees(data.temp), 72, "on_surface"),
            ui.column({ gap = 5, align = "end" }, {
                ui.glyph({ name = data.glyph, size = 40, color = "on_surface_variant" }),
                label(data.description, 17, "on_surface_variant"),
                label("H:" .. degrees(data.high) .. "  L:" .. degrees(data.low), 14, "on_surface_variant"),
            }),
        })
        rows[#rows + 1] = ui.separator({ spacing = 8 })
        local hours = {}
        for _, hour in ipairs(data.hours or {}) do
            hours[#hours + 1] = ui.column({ gap = 9, align = "center", flexGrow = 1 }, {
                label(hour.label, 12, "on_surface_variant"),
                ui.glyph({ name = hour.glyph, size = 28 }), label(degrees(hour.temp), 17),
            })
        end
        rows[#rows + 1] = ui.row({ gap = 7 }, hours)
        rows[#rows + 1] = ui.separator({ spacing = 8 })
        local low, high = 1000, -1000
        for _, day in ipairs(data.days or {}) do low = math.min(low, day.low); high = math.max(high, day.high) end
        for _, day in ipairs(data.days or {}) do
            rows[#rows + 1] = ui.row({ gap = 8, align = "center", paddingV = 7 }, {
                label(day.label, 14, "on_surface", 34), ui.glyph({ name = day.glyph, size = 24, width = 24 }),
                label(degrees(day.low), 14, "on_surface_variant", 38), rangeBar(day, low, high),
                label(degrees(day.high), 14, "on_surface", 38),
            })
        end
    elseif data.error then
        rows[#rows + 1] = label(data.error, 14, "error")
    else
        rows[#rows + 1] = label(loading and "Loading weather…" or "Choose a location to get started.", 14)
    end
    if data.stale then
        rows[#rows + 1] = label("Offline · cached " .. noctalia.formatTime("%b %d, %H:%M", data.fetched_at),
            12, "on_surface_variant")
    end
    rows[#rows + 1] = ui.button({ text = "Open-Meteo / GeoNames · CC BY 4.0", fontSize = 11,
        variant = "ghost", onClick = function() noctalia.runAsync({ "xdg-open", "https://open-meteo.com/" }) end })
    panel.render(ui.scroll({ gap = 8, padding = 18, align = "stretch", height = 590 }, rows))
end

noctalia.state.watch("weather", function() render() end)
noctalia.state.watch("loading", function() render() end)
noctalia.state.watch("search", function() render() end)
function onOpen() render() end
