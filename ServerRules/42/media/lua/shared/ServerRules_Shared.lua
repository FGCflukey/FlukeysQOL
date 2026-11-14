-- ServerRules_Shared.lua
-- Names shared by the client UI and the server, so the two can't drift apart.

ServerRules = ServerRules or {}

ServerRules.MODULE = "ServerRules"       -- sendClientCommand / sendServerCommand module name

-- Client -> server
ServerRules.CMD_CHECK   = "Check"        -- "have I accepted the current rules?"
ServerRules.CMD_ACCEPT  = "Accept"       -- args: { version = n, steamId = "..." }
ServerRules.CMD_DECLINE = "Decline"      -- args: { reason = "declined" | "timeout" }
ServerRules.CMD_VIEW    = "View"         -- keybind: "show me the rules again" (read-only if already accepted)

-- Server -> client
ServerRules.CMD_SHOW     = "Show"        -- args: { version, title, banner, welcome, rules = {...}, timeLimit, previousVersion, readOnly }
ServerRules.CMD_ACCEPTED = "Accepted"    -- already accepted this version, nothing to show
ServerRules.CMD_RECORDED = "Recorded"    -- acceptance saved, close the window
ServerRules.CMD_NONE     = "None"        -- no rules configured, nothing to show
