# Team Collaboration & Git Workflow Rules
## INF2556 Game Development - Midpoint Project

To ensure a smooth development process, prevent data loss, and avoid devastating merge conflicts in Godot, every team member must strictly follow these rules.

---

## 1. The Golden Git Rules (Daily Routine)
* **PULL FIRST:** Before opening Godot or making any changes, open GitHub Desktop and click **Fetch origin** / **Pull origin**. Always ensure you are working on the absolute latest version of the project.
* **COMMIT OFTEN:** Make small, frequent commits with clear, descriptive English summaries (e.g., `feat: add player shooting logic`, `fix: resolve enemy health signal bug`). Do not bundle 5 hours of work into a single massive commit.
* **PUSH PROMPTLY:** Once a feature or task is finished and tested, commit and push it immediately so others can use your updated code.
* **NEVER PUSH BROKEN CODE:** Ensure your local game runs without crashing before pushing your changes to the remote repository.

---

## 2. Branching Strategy & Conflict Resolution (Based on VL3)
* **Use Feature Branches:** Never work directly on the `main` branch. Create a new branch for every task (e.g., `feature/player-movement`, `feature/ui-menus`, `feature/enemy-ai`).
* **Safe Merging Practice:** Before merging your feature branch back into `main`:
	1. Commit your current work on your feature branch.
	2. Switch to `main` and pull the latest changes.
	3. Switch back to your feature branch and merge `main` into your feature branch locally.
	4. Fix any conflicts on your own branch and test the game.
	5. Once everything works perfectly, merge your branch into `main` and push.
* *Rule of Thumb:* Always break things on your own branch, never on the shared `main` branch!

---

## 3. Godot Scene Modularization (Crucial for Conflict Prevention)
Godot scenes (`.tscn` files) are text-based but highly sensitive. If two people modify the same `.tscn` file at the same time, Git will corrupt the scene file.
* **Work in Isolated Scenes:** Build the game modularly. Person A creates `Player.tscn`, Person B creates `Enemy.tscn`, Person C creates `HUD.tscn`.
* **Scene Instancing:** Do not build everything directly inside a main level scene. Create your separate components as autonomous scenes first, then drag and drop them as instances into the shared level layout.
* **Do Not Touch Others' Scenes:** Never modify another team member's scene file without explicit permission.

---

## 4. Communication & Live Scene Locking
For files that *must* be shared (like `project.godot`, the Input Map, or the actual level environments like `level_1.tscn`):
* **The "Live Lock" Announcement:** Before you edit a shared scene, announce it clearly in the team chat (e.g., *"I am opening level_1.tscn right now to add assets. Please do not touch this scene!"*).
* **The Release Announcement:** As soon as you are done, save, commit, push, and release the lock in chat (e.g., *"Done with level_1.tscn, pushed to GitHub. It's free to use again!"*).

---

## 5. Handling Assets & Git LFS (LFS Maybe not necessary for our project, since we probably wont have that many big files for this small game)
* **Binary File Tracking:** Large binary assets (such as `.png` sprites, `.wav`/`.mp3` audio clips, and 3D models) must be tracked using Git LFS (Large File Storage) to prevent the repository from inflating.
* **File Extensions:** Ensure the project's `.gitattributes` file is correctly configured before importing new asset sets.
* **Clean Organization:** Put all assets into dedicated folders within the project structure (e.g., `res://assets/sprites/`, `res://assets/audio/`) so team members know exactly where to find and update files.