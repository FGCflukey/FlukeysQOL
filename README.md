# Flukeys QOL Mod for Project Zomboid.

# About it

Built for and run on a private dedicated server for a small friend group. Most features that touch
persistent or shared state (repairs, crafting from containers, vehicle locks, door locks, the vendor,
the heater, etc.) are server-authoritative -- the server re-validates and applies the real change
itself rather than trusting the client, so this holds up correctly in multiplayer, not just solo.

This mod pack is a bunch of QOL tweaks to the base game. This mod aims to fill in many gaps I feel are
not in the game or implemented well or completely. Everything here is authored by me. I was inspired 
by many great mods, past and present. I wrote this with major help from AI to help me in lua. This is
not cheaty in any way. Everything you can do was made with some thought/experience behind it. 

List of current things this mod does...

- Overrides UseDelta on BlowTorches and Propane Tanks because it just makes more sense!
- Overrides Canteens to hold more water, from 500ml to 1 Litre
- Added Zombie butchering to cleanup the dead around your base or other things... (animal corpses excluded)
- Added new version of PZ Bloodcure which utilizes the Zombie butchering. Multi-stage recipe. Magazine
- Added Carbon Fibre Combat Axe and Long Reach Axe, includes repairs. Long Reach is weird, but works.
- Added the old Hydrocraft looking Dolly and Toy Wagon for crazy hoarders like me
- Allows Climbing all obstacles, fences, windows and tall walls protecting Dolly/Toy Wagon in 2nd hand
- (Note to above. In some circumstance you can still drop it. 98% of time you wont.)
- Added Visual Learner trait, allows the player to get XP from books instead of the usual vanilla boost
- Added extra skill books for Axe, Blunt, Small Blunt, Small Blade, Spear, Sprinting, Nimble, Sneaking
  and Lightfooted, with their own boxed sets you can pack/unpack just like vanilla's skill book sets
- Added Lock picking for Doors & Vehicle Doors using screwdriver & paperclip. Success based on Mechanics
  level. Picking any one vehicle door also unlocks the trunk
- Added more packaging options such as 10 pack of Engine Parts, Syringes and Test Tubes
- Added some recipes in for re-purposing unusable metal and scrap.
- Dolly and Vehicle trunk capcaity increased
- Added Re-fuelling BlowTorch and Propane Tank at Gas Pumps -- requires power at the pump
- Added Security Gate cutting, rewards scrap. Think Gun Store security fence blocking the door. Welding 2 Req.
- Added Car Painting. Now you have a nice variety of colours to paint your ride with. Vanilla only.
- Added Vehicle Vinyl Swapping. Want a different look for your vehicle? (only vanilla for now)
- Added Bulk Weapon Magazine Reloading/Unloading. Right click your stack!
- Added ATM usage. Find credit cards and try them to get some money! Watch out, it can attract Zombies!
- Added Usable Money. Pack it in $500/$1000 money bags. Duffle<->Moneybag conversion. Vendor friendly.
- Added Emergency Vendor. Right-click on a Vending Machine. Buy/Sell items if you have the cash or need it!
- Added UnHotwire for Cars. Needs SmallSheetMetal and Screwdriver and right skills. Sit in to perform
- Added Car Key crafting. Got the skills use some metal and make your own car key.
- Added Crafting Nail boxes with Sheet Metals and Scrap Metal
- Added Faster Car Hood/engine access, overrides default annoying slowness
- Added Crafting Engine Parts, recipes for mechanic, welding and blacksmithing req.
- Added repair kits (Tire, Suspension, Brake, Muffler, Body, Gas Tank, Battery) to restore a worn car
  part's condition in place using a Blowtorch, Scrap Metal/Sheet Metal and the matching skill level --
  works from a backpack, dolly, or even a nearby crate, not just your main inventory
- Added Dismantling of General Car Parts, serves as a fill-in for missing stuff or as a 2nd option
- Added Repairing Broken Car Locks. Success is based on Mechanics level. But chance to fail exists.
- Added Vehicle Recycling and Parts making, from earlier 42 builds I did.
- Added Stop The Drop - When you flee & fall down, you won't drop your hat/other items. Idc for mechanic.
- Added Automaker - build a real, drivable vehicle from scratch. Read the magazines, gather the metal/
  electrical materials, meet the skill and recipe requirements, and build any installed vehicle mod's
  cars too, not just vanilla ones
- Added HomeHeat - a placeable, wall-mounted safehouse radiator with on/off and Cool/Normal/Hot presets,
  so you can keep a room warm without a constant fire or wood stove going
- Fixed Nepenthe's "Chocolate Milk From Brown Cows" mod (its own require() path was broken) and folded
  the fix in directly, so brown (simmental) cows give chocolate milk without needing that mod installed

## Installation

Make sure this is the last thing on your Mods= line. That's all.


# Disclaimer

This mod and all of its code were authored by me, justanothersteamclient. 
https://steamcommunity.com/id/justanothersteamclient. I am typically known as Starman and long time friends know
me by Flukey. You are not welcome to take this mod or use anything in it without giving me credit. This work is 
considered private and can only be used with my consent only. I would appreciate it if you reach out to me before 
trying to use/take this. Please show respect towards the people who took the time/patience and testing to make this 
work. Don't be a fraud. I don't ask for money or donations. Just appreciate the respect and kudos. Peace.