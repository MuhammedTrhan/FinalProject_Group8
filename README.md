# Split

A top-down stealth-horror game made in Godot 4.6 for INF2556 Game Development.

A girl is held in a house by one captor who wakes up as a different personality
every day. Each personality wants something different and notices her
differently, so the same house has to be played in three different ways. She has
to work out a three-digit exit code and enter it on the keypad at the front
door before she runs out of days.

## Trailer

*(link here)*

## How to run it

**Windows build.** Run the exported `.exe` that ships with the submission. No
installation is needed.

**From source.** Open the project folder with Godot **4.6** and press F5. The
main scene is `Scenes/UI/main_menu.tscn`.

> If the first launch reports "Unrecognized UID" errors, delete the local
> `.godot/` folder and let the editor rescan. That folder is a local cache and
> is not tracked by Git.

## Controls

| Key | Action |
|---|---|
| **W A S D** / arrow keys | Move |
| **Space** | Interact |
| **E** | Lock or unlock a door, where that is possible |
| **Tab** | Open the inventory |
| **1** – **8**, mouse wheel, click | Pick a hotbar slot |
| Click the slot you are holding, or an item in the inventory | Use that item |
| **Esc** | Pause |

Whatever sits in the picked hotbar slot is in her hand. That is enough on its
own for a tool that switches on and off: the UV flashlight lights up the moment
you select it, and goes out when you pick another slot. A one-shot tool like the
crowbar does nothing while merely held and has to be clicked.

## How the game works

The run opens on **Night 1**, locked in her room with a computer holding the
captor's case files. That night has no timer: it ends once she has read all
three files, which is how the player learns who the personalities are before
meeting any of them.

After that the run alternates **Day (90 s) → escort (5 s) → Night (15 s)**, up
to seven days. Play happens during the day; the escort is the captor walking
her back to her room.

Each personality gives up one tool once the player gives it what it wants, and
each tool opens one puzzle that reveals one digit:

| Personality | What it wants | Tool | Puzzle |
|---|---|---|---|
| **The Loud Guy** | Quiet — switch off the noisy furniture | UV flashlight | Writing on the floor, visible only under UV |
| **The Happy One** | Company — stay inside his circle | Crowbar | A floorboard that does not sit flush |
| **The Scary One** | To be followed, unseen | Three diary pieces | Combine the pieces in the bag |

Solving a digit retires that personality for the rest of the run. Being caught
costs one of **three lives**: the first two end the day early, the third ends
the run.

If the player goes fifteen seconds without making progress, a hint appears
naming the next step, so it is possible to finish the game without outside help.

## Project structure

```
Scenes/          Level, player, enemy, furniture, UI screens
Scripts/
  Autoload/      GameEvents (signal bus), GameManager, Inventory, ...
  Enemy/         State machine, perception, personality modules
  Player/        Movement, interaction, tool use
  Interactables/ Doors, furniture, containers, hiding spots
  Puzzles/       UV clue, floorboard
Resources/       Item and personality data (.tres)
docs/            Mini-GDD and the team contract
```

The three developers' code meets only through `Scripts/Autoload/GameEvents.gd`,
a single autoload that declares every cross-system signal. Who may emit which
signal is written down in `docs/CONTRACT.md`; anyone may connect to anything,
but a developer only emits the signals in their own section. Screens that have
to survive a scene change — the day/night card, the HUD, the pause menu, the
keypad — are autoloaded canvas layers rather than children of the level.

## Team

| | Area |
|---|---|
| Muhammed Turhan | Antagonist AI, world, puzzles |
| Reyyan Pak | Game flow, inventory, user interface |
| Emelie Joline | Audio, menu, trailer |

## Documents

- `docs/MiniGDD.docx` — concept, mechanics, and the full list of asset sources
- `docs/CONTRACT.md` — the signal contract the three of us worked against

All third-party assets are free or used under the terms listed by their
authors; they are credited in the Mini-GDD.
