local function paint(data)
    if type(data) ~= "table" or data.temp == nil then
        barWidget.setGlyph("cloud")
        barWidget.setText("—")
        barWidget.setTooltip("iWeather · click to choose a location or refresh")
        return
    end
    barWidget.setGlyph(data.glyph)
    barWidget.setText(tostring(data.temp) .. "°")
    barWidget.setTooltip(data.name .. " · " .. data.description .. " · °" .. data.units
        .. (data.stale and " · cached, offline" or ""))
end

noctalia.state.watch("weather", paint)
function update()
    noctalia.setUpdateInterval(60000)
    paint(noctalia.state.get("weather"))
end
