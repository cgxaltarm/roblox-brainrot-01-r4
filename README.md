[![roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/cgxaltarm/roblox-brainrot-01-r4/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/cgxaltarm/roblox-brainrot-01-r4/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

# Brainrot Night Market — roblox-brainrot-01

A 3D Roblox brainrot game for make.fun's "Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01). Original Indonesian street-food brainrots, a night-market world, and the full Steal-a-Brainrot loop — built fresh in a sealed recording.

Play it on Roblox: see `PLAY.json` for the public place link.

## The game

You spawn in a night market facing the conveyor. Brainrots ride past on the belt — buy one (hold E on its prompt, or click it), carry it home, click a glowing pad in your base to place it, and it earns cash every second into your pile. Hit COLLECT to bank the pile, then buy rarer ones.

- **30 original brainrots** — Tahu Gejrot ($50) up to Dewi Sri Padi ($12,000), across Common, Rare, Epic, Legendary and Mythic, with Golden (x2), Rainbow (x5) and Diamond (x10) mutations shown as ★ on the conveyor cards. The belt always keeps at least one slot at $100 or less, and refreshes replace the oldest slot so a rare pull is never eaten.
- **Steal and defend** — slap rivals with F to make them drop what they carry, steal brainrots off rival pads, or lock your base for $1,500. Dying while carrying returns the brainrot to your hands on respawn.
- **Progression** — Fuse Machine: fuse two brainrots of the same rarity into the next rarity up. Rebirth ($5,000): reset cash and base for a permanent x2 income multiplier and +2 pads (4 start, 8 max). Gear shop: Slap Power and Speed upgrades.
- **5 chained missions** — buy, place, collect $500, steal or fuse, rebirth — with cash bonuses at every step, tracked in the HUD.
- **Timed events** — Rush Hour (conveyor refreshes every 6s), Golden Hour (more Golden mutations), Festival (2x income), announced on the one timer line in the HUD.
- **Save** — cash, placed brainrots, rebirth count and upgrades persist in a DataStore across sessions.

## Controls

- **WASD** move, **E (hold)** buy from the conveyor, **click** a brainrot / a pad to buy / place / steal, **F** slap the nearest player, **COLLECT** banks your pile, **LOCK BASE** locks your base for 2 minutes, **MENU** opens GEAR / BUFF / INDEX / MISI / FUSE / REBIRTH / TOP 5. Clicking the Fuse Machine, leaderboard board or Coins Shop in the world opens the matching menu tab.

## Layout

- `main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy, unchanged.
- `game.rbxl` is the place Rojo builds from `src/` and `default.project.json`; `screenshots/` holds Studio captures of it (the first by name is the game's Roblox thumbnail); `PLAY.json` names the published public place.
- `src/shared/Catalog.luau` — the 30-brainrot catalogue, rarities and mutation rolls.
- `src/server/GameServer.server.luau` — server authority: buy/carry/place/collect, steal/slap/lock/fuse/rebirth, missions, events, income tick, DataStore saves.
- `src/client/Game.client.luau` — HUD (money, timer, mission, MY BASE panel, MENU/LOCK/COLLECT, conveyor strip, pad KLIK hints) and input.

Run it as the grader does, writing `out/` in place of `/output`:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

Build the place with Rojo 7.7.1:

    ~/workspace/tools/rojo-7.7.1/rojo build default.project.json --output game.rbxl

The rules are on the bounty's page (https://make.fun/bounty/roblox-brainrot-01) and in the kit's RULES.txt.
