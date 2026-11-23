![Package Icon](icon.png)  

# 20s Jam - You Are What You Eat

## to-do

- [x] add a killfloor
- audio
  - [x] add music to scene
  - attach more sfx
    - [x] pickup sound
    - [ ] launcher
    - [ ] dash
- UI
  - [x] interaction text ("e to pick up", etc.)
  - [x] hotkey to quick-restart
  - [ ] volume sliders (master, music, sfx)
- models
  - start substituting placeholder level geometry
- shaders
  - [ ] something more obvious for the buttons/launchers
  - [ ] shader for tamale/pepper dash powerup (flame particle system? trails? shader?)
  - [ ] dissolve shader
- level
  - geometry
    - [x] lower start ramp to be able to walk up it
    - [x] hide the bar above the starter area, or make the pickup visible through it (if that pickup is supposed to be there in the first place?)
  - [ ] move the tamale pickup so picking it up is a choice...or make picking it up more showy

- routine browser upload tests

## notes

- need some solutions to make some version of this do-able in 20s
  - tune up movement speed
  - add teleporters
  - make the dash power the first power
    - maybe the starting position should be a choice between two valved directions, which allows some use of the current puzzle diversity
- the drop-down tunnel in the second scene didn't read to me as something I could drop into
- the pick-up ability seems to often roll the box undesirably/frustratingly far away...maybe just remove that moat in the first section, or add multiple boxes, or have the moat respawn the box?
- can't see player while int he first catapult...maybe use the xray effect on the  

## questions

- are the repeat powerups supposed to do something (second tofu right after the first box, or the upcoming tofu much later?)?
- is the pancake powerup supposed to stop you from fitting in the hole in the wall if you're still big?
- is the area below and to the left of the starting position supposed to do anything if you jump there?
- what's up with that box that falls off from the forward-left side of the map at game start?

## other changelog

- played with movement controls to facilitate faster play and snappier response

