----------------------------------
-- unit.start --------------------
----------------------------------
local mainBoard = true --export
local numBatches = 10 --export
local hardStop = true --export
local allowIngredientLoss = false --export
local languageRu = true --export
local updateTime = 1 --export

local screens = {}
local factories = {}
local databanks = {}

local startedStatusFactories = {} -- to start it one time

----------------------------------
-- HTML module -------------------
local font_size = 4 --export: font size for the table
local font_color = "black" --export: font color for the table
local screen_color = "#979A9A" --export: screen background color
local table_border_color = "black" --export: table border color
local header_background_color = "#959595" --export: table header background color
local header_text_color = "white" --export: table header text color
local row_color_1 = "#ECF0F1" --export: table even line background color
local row_color_2 = "#D0D3D4" --export: table odd line background color
local message_text_color = "#FF8B00" --export: message text color

local htmlStyle = [[<style>
	div.screen {
		background-color:]]..screen_color..[[;
		width:100vw;
		height:100vh;
	}
	
	table {
		font-family:"Lucinda Sans";
		position:absolute;
		font-size:]]..font_size..[[vh;
		background-color:]]..screen_color..[[;
		border-collapse:collapse;
		margin:0px auto;
		color:]]..font_color..[[;
		width:90vw;
		left:10vh;
		top:5vh;
	}
	
	th {
		background-color:]]..header_background_color..[[;
		color:]]..header_text_color..[[;
	}
	
	td.cell {
		font-family:"Lucinda Sans";
		color:]]..font_color..[[;
	}
	
	th, td {
		border: solid 0.4vw ]]..table_border_color..[[;
		padding: 0.5vw;
		height:8vh;
	}
	
	tbody {
		background-color:]]..row_color_1..[[;
	}
	
	tbody.zebra tr:nth-child(even) {
		background-color:]]..row_color_2..[[;
	}
	
	div.message {
		position:absolute;
		font-family:"Lucinda Sans";
		color:]]..message_text_color..[[;
		top:40vh;
		height:20vh;
		width:90vw;
		font-size:10vh;
		text-align:center;
	}
</style>
]]
local backgroundHtml = "<div class='screen'></div>"
local tableTemplate = "<table><tr><th style='width:10vw'>N</th><th style='width:10vw'>id</th><th style='width:25vw'>class</th><th style='width:35vw'>status</th><th style='width:10vw'>done</th><th>time</th></tr><tbody class='zebra'>%s</tbody></table>"
if languageRu then
	tableTemplate = "<table><tr><th style='width:10vw'>N</th><th style='width:10vw'>id</th><th style='width:25vw'>класс</th><th style='width:35vw'>статус</th><th style='width:10vw'>сделано</th><th>время</th></tr><tbody class='zebra'>%s</tbody></table>"
end
local rowTemplate = "<tr><td class='cell'>%d</td><td class='cell'>%d</td><td class='cell'>%s</td><td class='cell'>%s</td><td class='cell'>%s</td><td class='cell'>%s</td></tr>"
local messageTemplate = "<div class='message'>%s</div>"
-- HTML module -------------------
----------------------------------

----------------------------------
-- functions ---------------------
local function initiateSlots()
	for _, slot in pairs(unit) do
		if type(slot) == "table" and type(slot.export) == "table" and slot.getElementClass then
			local elementClass = slot.getElementClass():lower()
			if elementClass == "databankunit" then
				table.insert(databanks,slot)
			elseif elementClass == "industryunit" then
				table.insert(factories,slot)
			elseif elementClass == "screenunit" then
				table.insert(screens,slot)
			end
		end
	end
	
	if #screens < 1 and mainBoard then
		local text = ""
		if languageRu then
			text = "Экран не подключен!"
		else
			text = "No screen connected!"
		end
		system.print(text)
	end
	
	if #databanks < 1 then
		local text = ""
		if languageRu then
			text = "Банк даннных не подключен!"
		else
			text = "No databank connected!"
		end
		system.print(text)
	end

	if #factories < 1 then
		local text = ""
		if languageRu then
			 text = "Заводы не подключены!"
		else
			 text = "No industry connected!"
		end
		system.showScreen(1)
		system.setScreen(htmlStyle .. string.format(messageTemplate, text))
		error(text)
	end
	
	table.sort(factories, function (a, b) return (a.getId() < b.getId()) end)
	table.sort(databanks, function (a, b) return (a.getId() < b.getId()) end)
	table.sort(screens, function (a, b) return (a.getId() < b.getId()) end)
end

local function stopIndustry()
    for k, v in ipairs(factories) do
		startedStatusFactories[k] = false
		if v.getStatus() ~= "STOPPED" then
			if hardStop then
				if allowIngredientLoss then
					v.hardStop(1)
				else
					v.hardStop(0)
				end
			else
				v.softStop()
			end
		end
    end
end

local function startIndustry(numBatches)
	local numBatches = numBatches or 0
	if numBatches > 0 then
		for k, v in ipairs(factories) do
			if not startedStatusFactories[k] and v.getStatus() == "STOPPED" then
				v.batchStart(math.floor(numBatches))
				startedStatusFactories[k] = true
			end
		end
	end
end

local function getAllIndustryStarted()
	for _, v in ipairs(startedStatusFactories) do
		if not v then
			return false
		end
	end
	
	return true
end

local function dateFormat(t)
	local t = type(t)=='number' and t>0 and t or 0
	local text = ""
	
	local day = math.floor(t/86400)
	t = t%(24*3600)
	local hour = math.floor(t/3600)
	t = t%3600
	local minute = math.floor(t/60)
	t = t%60
	local second = math.floor(t)

	if day > 0 then text = day.."d:" end
	if day > 0 or hour > 0 then text = text..hour.."h:" end
	if day > 0 or hour > 0 or minute > 0 then text = text..minute.."m:" end

	return text..second.."s"
end

local function showInfo()
	if screens[1] then
		local n = 0
		if databanks[1] then
			n = databanks[1].getIntValue("numBatches")
		else
			n = numBatches
		end
		local htmlRows = {}
		for k, v in ipairs(factories) do
			table.insert(htmlRows,string.format(rowTemplate,k,v.getId(),v.getElementClass(),v.getStatus(),v.getCycleCountSinceStartup().."/"..n,dateFormat(v.getUptime())))
		end

		screens[1].setHTML(htmlStyle .. backgroundHtml .. string.format(tableTemplate,table.concat(htmlRows)))
	end
end

function update()
	if getAllIndustryStarted() then
		if not screens[1] then
			unit.stopTimer("update")
		end
	else
		local n = 0
		if databanks[1] then
			n = databanks[1].getIntValue("numBatches")
		else
			n = numBatches
		end
		
		startIndustry(n)
	end
	showInfo()
end

function stop()
	local text = ""
	if languageRu then
		 text = "Скрипт остановлен"
	else
		 text = "Script stopped"
	end
	if screens[1] then
		screens[1].setHTML(htmlStyle .. backgroundHtml .. string.format(messageTemplate, text))
	else
		system.print(text)
	end
end
-- functions ---------------------
----------------------------------

----------------------------------
-- code --------------------------
initiateSlots()
stopIndustry()
showInfo()

if mainBoard and databanks[1] then
	databanks[1].setIntValue("numBatches", numBatches)
end

unit.setTimer("update", updateTime)
-- code --------------------------
----------------------------------



----------------------------------
-- unit.tick('update') -----------
----------------------------------
update()



----------------------------------
-- unit.stop ---------------------
----------------------------------
stop()
