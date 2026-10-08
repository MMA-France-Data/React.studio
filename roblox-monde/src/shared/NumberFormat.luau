-- Display only: values and gameplay calculations remain unchanged.
local NumberFormat = {}
local units = { { 1e27, "Oc" }, { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
function NumberFormat.short(value: number, lang: string?): string
	if value ~= value then return "0" end
	if math.abs(value) == math.huge then return if value < 0 then "−∞" else "∞" end
	local sign, magnitude = if value < 0 then "−" else "", math.abs(value)
	local function digits(number: number): string
		local formatted = if number == math.floor(number) then string.format("%.0f", number) else string.format("%.1f", number)
		return if lang == "fr" then (formatted:gsub("%.", ",")) else formatted
	end
	for _, unit in units do
		if magnitude >= unit[1] then
			return sign .. digits(math.floor(magnitude / unit[1] * 10) / 10) .. unit[2]
		end
	end
	return sign .. digits(math.floor(magnitude * 10) / 10)
end
return NumberFormat
