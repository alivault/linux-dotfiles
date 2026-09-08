local editing = false
local query = ""
local render
-- 12pt at 96dpi = 16 logical pixels. Noctalia handles output scaling.
local BASE = 16
local function send(action, fields)
    fields = fields or {}
    fields.action = action
    noctalia.state.set("command", fields)
end
local function label(text, size, color, width, textAlign, weight)
    return ui.label({ text = tostring(text), fontSize = size or BASE, fontFamily = "sans-serif", fontWeight = weight or "semibold",
        color = color or "on_surface", width = width, textAlign = textAlign, maxLines = 1 })
end
local function cell(width, child, align)
    return ui.column({ width = width, minWidth = width, align = align or "start", justify = "center" }, { child })
end
local function degrees(value) return tostring(value) .. "°" end
local function hourLabel(value)
    local hour, period = value:match("^(%d+)%s*([AP]M)$")
    if not hour then return value end
    return string.format("%02d", tonumber(hour) % 12 + (period == "PM" and 12 or 0))
end
local function search()
    send("search", { query = query })
end
local function rangeBar(day, low, high)
    local total = math.max(1, high - low)
    local left = math.max(0, (day.low - low) / total)
    local fill = math.max(0.01, (day.high - day.low) / total)
    local pieces = {}
    if left > 0 then pieces[#pieces + 1] = ui.box({ width = 0, flexGrow = left, height = 5, fill = "surface_variant", radius = 3 }) end
    pieces[#pieces + 1] = ui.image({ path = "gradient.png", width = 0, flexGrow = fill, height = 5, radius = 3, fit = "stretch" })
    local right = math.max(0, 1 - left - fill)
    if right > 0 then pieces[#pieces + 1] = ui.box({ width = 0, flexGrow = right, height = 5, fill = "surface_variant", radius = 3 }) end
    return ui.row({ gap = 0, align = "center", width = 0, flexGrow = 1 }, pieces)
end

render = function()
    local data = noctalia.state.get("weather") or {}
    local loading = noctalia.state.get("loading") == true
    local rows = {}
    if data.temp == nil then
        rows[#rows + 1] = ui.button({ text = "Choose location", variant = "ghost",
            onClick = function() editing = not editing; render() end })
    end
    if editing or data.needs_location then
        rows[#rows + 1] = ui.row({ gap = 6 }, {
            ui.input({ key = "city-search", value = query, placeholder = "City or ZIP code", flexGrow = 1,
                focus = true, submitOnEnter = true, onChange = function(value) query = value end,
                onSubmit = function(value) query = value; search() end }),
            ui.button({ glyph = "search", enabled = not loading, onClick = search }),
            ui.button({ text = "°" .. (data.units or "C"), variant = "ghost", onClick = function() send("units") end }),
            ui.button({ glyph = "refresh", variant = "ghost", enabled = not loading, onClick = function() send("refresh") end }),
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
        rows[#rows + 1] = ui.row({ justify = "space_between", align = "start", height = 74 }, {
            ui.column({ gap = 0, align = "start", onClick = function() editing = not editing; render() end }, {
                label((data.name or "Location"):match("^[^,]+"), 19),
                label(degrees(data.temp), 50, "on_surface", nil, nil, "light"),
            }),
            ui.column({ gap = 2, align = "end", paddingV = 3 }, {
                ui.glyph({ name = data.glyph, size = 24 }),
                label(data.description, BASE),
                label("H:" .. degrees(data.high) .. " L:" .. degrees(data.low), BASE),
            }),
        })
        rows[#rows + 1] = ui.column({ paddingV = 14 }, {
            ui.box({ height = 1, fill = "on_surface/0.12", radius = 0, softness = 0 }),
        })
        local hours = {}
        for _, hour in ipairs(data.hours or {}) do
            hours[#hours + 1] = ui.column({ gap = 10, align = "center" }, {
                label(hourLabel(hour.label), 14, "on_surface_variant"),
                ui.glyph({ name = hour.glyph, size = 24 }), label(degrees(hour.temp), BASE),
            })
        end
        rows[#rows + 1] = ui.row({ justify = "space_between", gap = 0 }, hours)
        rows[#rows + 1] = ui.column({ paddingV = 14 }, {
            ui.box({ height = 1, fill = "on_surface/0.12", radius = 0, softness = 0 }),
        })
        local low, high = 1000, -1000
        for _, day in ipairs(data.days or {}) do low = math.min(low, day.low); high = math.max(high, day.high) end
        for _, day in ipairs(data.days or {}) do
            rows[#rows + 1] = ui.row({ gap = 12, align = "center", height = 40 }, {
                cell(60, label(day.label:sub(1, 1) .. day.label:sub(2):lower())),
                cell(28, ui.glyph({ name = day.glyph, size = 26 }), "center"),
                cell(80, cell(52, label(degrees(day.low), BASE, "on_surface/0.45"), "center"), "end"),
                rangeBar(day, low, high),
                cell(44, label(degrees(day.high)), "end"),
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
    rows[#rows + 1] = ui.row({ justify = "center", paddingV = 6,
        onClick = function() noctalia.runAsync({ "xdg-open", "https://open-meteo.com/" }) end }, {
        label("Open-Meteo / GeoNames · CC BY 4.0", 10, "on_surface_variant"),
    })
    panel.render(ui.scroll({ gap = 0, paddingH = 4, paddingV = 0, align = "stretch", height = 440 }, rows))
end

noctalia.state.watch("weather", function() render() end)
noctalia.state.watch("loading", function() render() end)
noctalia.state.watch("search", function() render() end)
function onOpen() render() end
