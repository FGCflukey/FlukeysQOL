--[[
    Repairable Gloveboxes & Heaters
    Vehicle-area path overrides.

    For most vehicles the default "Engine" area is fine for heater repair
    and the vanilla fixing menu handles glove-box pathing on its own. Some
    modded vehicles have unusual cabin layouts where a part lives behind a
    different door — drop an entry here to redirect path-finding for those
    cases.

    Outer key (matched in order):
        1. Vehicle script full name, e.g. "Base.OffRoad"
        2. Vehicle script short name, e.g. "OffRoad"
        3. "*" wildcard

    Inner key (matched in order):
        1. Part id, e.g. "GloveBox" or "Heater"
        2. Part id with spaces, e.g. "Glove Box"
        3. "*" wildcard

    Value: the vehicle-area name to path to, e.g. "RearDoor",
    "FrontPassenger", "Trunk", ...

    Example:

        return {
            ["Base.SomeVan"] = {
                Heater   = "FrontPassenger",
                GloveBox = "RearDoor",
            },
        }
]]

return {
    -- The 97bushmaster / 97bushAmbulance modded vehicles tuck the glove box
    -- into the rear cabin; pathing via the rear door is the working access.
    ["97bushAmbulance"] = {
        GloveBox = "RearDoor",
    },
    ["97bushmaster"] = {
        GloveBox = "RearDoor",
    },
}
