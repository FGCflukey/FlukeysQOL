-- ServerRules_Shared.lua
-- Names shared by the client UI and the server, so the two can't drift apart.

ServerRules = ServerRules or {}

ServerRules.MODULE = "ServerRules"       -- sendClientCommand / sendServerCommand module name

-- Client -> server
ServerRules.CMD_CHECK   = "Check"        -- "have I accepted the current rules?"
ServerRules.CMD_ACCEPT  = "Accept"       -- args: { version = n, steamId = "..." }
ServerRules.CMD_DECLINE = "Decline"      -- args: { reason = "declined" | "timeout" }

-- Server -> client
ServerRules.CMD_SHOW     = "Show"        -- args: { version, title, welcome, rules = {...}, timeLimit }
ServerRules.CMD_ACCEPTED = "Accepted"    -- already accepted this version, nothing to show
ServerRules.CMD_RECORDED = "Recorded"    -- acceptance saved, close the window
ServerRules.CMD_NONE     = "None"        -- no rules configured, nothing to show
