-- TowFromVehicle_Actions.lua
-- Monkey-patches vanilla's real ISAttachTrailerToVehicle /
-- ISDetachTrailerFromVehicle timed actions (client/Vehicles/
-- TimedActions/) so they also work when triggered from the in-vehicle
-- radial menu (TowFromVehicle_Menu.lua) instead of only the normal
-- outside-the-vehicle right-click flow.
--
-- Ported in from the Workshop mod "Tow In Your Car" (SportXAI, Steam
-- id 3473214630) and FIXED here -- as published it showed the
-- progress bar and played the sound, but never actually attached or
-- detached anything in this in-vehicle path (confirmed via a Workshop
-- comment reporting exactly that). Root cause, found by reading
-- vanilla's real source directly:
--
-- ATTACH: vanilla's real ISAttachTrailerToVehicle:start() does four
-- things -- animation, sound, vehicleA:beginAttachingTrailer(), and
-- self:attachTrailer() (which is what actually sends the real
-- sendClientCommand(..., 'vehicle', 'attachTrailer', ...) that
-- performs the attach). The original mod's in-vehicle override of
-- :start() skipped ALL of it except the sound -- attachTrailer() was
-- simply never called, so the network command that does the real work
-- never went out. Fixed by still calling beginAttachingTrailer() and
-- attachTrailer() in the in-vehicle case, just skipping the
-- stand-up/walk animation (setActionAnim), which doesn't make sense
-- while seated in a car anyway.
--
-- DETACH: the real network command lives in vanilla's :perform(),
-- gated by `character:DistTo(hitchPos) > 4` -- and hitchPos is only
-- ever computed by vanilla's real :waitToStart()/:update(), via
-- vehicle:getTowingWorldPos(attachment, hitchPos). The original mod's
-- in-vehicle overrides of BOTH of those skipped calling through to
-- vanilla's versions entirely, so hitchPos stayed at its default
-- (0,0,0) for the whole action. By the time :perform() ran its
-- distance check, the player was never going to be within 4 tiles of
-- (0,0,0), so the check always failed and the detach command was
-- silently never sent. Fixed by still computing hitchPos every frame
-- via getTowingWorldPos() in the in-vehicle case, just skipping the
-- faceLocationF() turn-to-face-it call (again, doesn't make sense
-- while seated).

local D_WaitToStart = ISDetachTrailerFromVehicle.waitToStart
local A_WaitToStart = ISAttachTrailerToVehicle.waitToStart
local A_Start = ISAttachTrailerToVehicle.start
local D_Start = ISDetachTrailerFromVehicle.start
local D_Stop = ISDetachTrailerFromVehicle.stop
local A_Stop = ISAttachTrailerToVehicle.stop
local D_Perform = ISDetachTrailerFromVehicle.perform
local A_Perform = ISAttachTrailerToVehicle.perform
local D_Update = ISDetachTrailerFromVehicle.update
local A_Update = ISAttachTrailerToVehicle.update
local D_New = ISDetachTrailerFromVehicle.new
local A_New = ISAttachTrailerToVehicle.new

--Start
function ISAttachTrailerToVehicle:start()
	if not self.isAttachingInVehicle then
		A_Start(self)
		return
	end
	-- In-vehicle case: skip the stand-up/walk animation, but keep the
	-- two calls that actually matter -- beginAttachingTrailer() (native
	-- vehicle-side state flag) and attachTrailer() (the real
	-- sendClientCommand that performs the attach). These were the two
	-- calls silently missing in the original mod.
	self.sound = self.character:getEmitter():playSound("VehicleTowAttach")
	self.vehicleA:beginAttachingTrailer()
	self:attachTrailer()
end

function ISDetachTrailerFromVehicle:start()
	if not self.isAttachingInVehicle then
		D_Start(self)
		return
	end
    self.sound = self.character:getEmitter():playSound("VehicleTowAttach")
end

--Update
function ISAttachTrailerToVehicle:update()
	if not self.isAttachingInVehicle then
		A_Update(self)
		return
	end

    if not self.character:getVehicle():isStopped() then self:forceStop() return end
end

function ISDetachTrailerFromVehicle:update()
	if not self.isAttachingInVehicle then
		D_Update(self)
		return
	end

	if not self.character:getVehicle():isStopped() then self:forceStop() return end

	-- Still compute hitchPos every frame (same as vanilla's real
	-- update()), just without the faceLocationF() turn-to-face-it call
	-- -- this is what :perform()'s distance check needs to actually
	-- pass. Missing this is why detach silently never completed.
	self.vehicle:getTowingWorldPos(self.attachment, self.hitchPos)
end

--Wait to start
function ISAttachTrailerToVehicle:waitToStart()
	if self.isAttachingInVehicle then
		return false
	else
		A_WaitToStart(self)
		return getSpecificPlayer(0):shouldBeTurning()
	end
end

function ISDetachTrailerFromVehicle:waitToStart()
	if self.isAttachingInVehicle then
		-- Same fix as update() -- compute hitchPos here too, since
		-- waitToStart() runs before update() ever gets a chance to.
		self.vehicle:getTowingWorldPos(self.attachment, self.hitchPos)
		return false
	else
		D_WaitToStart(self)
		return getSpecificPlayer(0):shouldBeTurning()
	end
end

--Stop
function ISAttachTrailerToVehicle:stop()
	getSpecificPlayer(0):setVariable("IsAttachingInVehicle", false)
	A_Stop(self)
end

function ISDetachTrailerFromVehicle:stop()
	getSpecificPlayer(0):setVariable("IsAttachingInVehicle", false)
	D_Stop(self)
end

--Perform
function ISAttachTrailerToVehicle:perform()
	getSpecificPlayer(0):setVariable("IsAttachingInVehicle", false)
	A_Perform(self)
end

function ISDetachTrailerFromVehicle:perform()
	getSpecificPlayer(0):setVariable("IsAttachingInVehicle", false)
	D_Perform(self)
end

--New
function ISDetachTrailerFromVehicle:new(...)
	local o = D_New(self, ...)
	o.isAttachingInVehicle = getSpecificPlayer(0):getVariableBoolean("IsAttachingInVehicle") --Flip Or Attach Trailer In Vehicle
	return o
end

function ISAttachTrailerToVehicle:new(...)
	local o = A_New(self, ...)
	o.isAttachingInVehicle = getSpecificPlayer(0):getVariableBoolean("IsAttachingInVehicle") --Flip Or Attach Trailer In Vehicle
	return o
end
