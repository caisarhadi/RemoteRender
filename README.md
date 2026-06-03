# Noah Kahan (NK26) Render Scripts

This folder contains the automation scripts for launching and managing Movie Render Queue (MRQ) renders for the NK26 Unreal Engine project.

## 🚀 1. The Main GUI Launcher (Recommended)
**File:** `NK_RenderLauncher.vbs`

This is the primary tool for rendering. Double-clicking this file will open a dark-themed GUI instantly (with zero command prompt windows flashing) that allows you to render multiple sequences and passes in a single click.

**Features:**
- **Plastic SCM Auto-Sync:** Automatically pull the latest changes from the server before launching a render. Safely skips updates if you are rendering locally on your own machine.
- Select multiple songs (sequences).
- Select multiple specific passes (e.g., `House`, `Env`, `Song`). 
- Automatically filters out unwanted passes.
- Set global overrides for Spatial Samples, Temporal Samples, Warm-up frames, and Resolution.
- Includes a handy "Output Folder" button to jump straight to your rendered frames.
- Runs headlessly (Unreal Engine loads in the background without stealing your screen).

*(Note: The GUI relies on `NK_RenderLauncher.ps1` and `MRQ_Python_Executor.py` to function. Do not delete them).*

---

## ⚡ 2. Fast/Standalone Batch Scripts (No Python)
These scripts launch Unreal Engine in `-game` mode, meaning a live render viewport will appear, allowing you to watch the render progress. They do **not** support pass-filtering or sample-overriding; they simply render the exact preset saved in your queue.

**`Select_MRQ_Render.bat`**
- Prompts you for a 4-digit sequence code (e.g., `0130`).
- Immediately launches the live render viewport for that specific sequence.
- Renders ALL passes defined in the queue.

**`Test_MRQ_Render.bat`**
- Hardcoded to run through **all 6** sequences sequentially.
- Opens the live viewport and renders everything overnight.

---

## 🐍 3. Advanced/Legacy Python Script
**File:** `Advanced_Python_Render.bat`

This is the text-based (Command Prompt) predecessor to the new GUI launcher. It functions similarly to the GUI by allowing you to inject sample overrides and filter by a single pass name via text prompts. It is kept for legacy/fallback purposes.

---

## 🛠️ How It Works (Technical Details)
- **Path Configuration:** All batch files and the GUI will remember your Engine and Project paths. Both the `.bat` files and the GUI share and store this configuration in a `RenderConfig.bat` file.
- **Pass Filtering Logic:** When you select "House" in the GUI, the Python executor (`MRQ_Python_Executor.py`) searches the job's Graph Preset names. It will match `_House` and `_House_SO`, but it explicitly ignores passes with completely different names (like `_House_Back`), ensuring you only render exactly what you checked.
- **Headless Execution:** The Python scripts require `-unattended` editor mode to inject variables. The engine will run in the background (you will see a log window, but no viewport).
