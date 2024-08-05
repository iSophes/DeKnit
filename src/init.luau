--------------------------------------
-- DEKNIT
--
-- A FORK OF @sleitnick's KNIT BY
-- @iSophes
--
-- MIT LICENSE.
--
-- @iSophes 2024
--
--------------------------------------

local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(script.DeKnitServer)
end

if script.DeKnitServer and RunService:IsRunning() then
	script.DeKnitServer:Destroy()
end

return require(script.DeKnitClient)
