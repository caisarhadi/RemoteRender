# Render Scripts

This folder contains the automation scripts for launching and managing Movie Render Queue (MRQ) renders via Unreal Engine.

> **API Reference:** See [MRQ_API_Reference.md](MRQ_API_Reference.md) for documentation on the Unreal Python APIs used by these scripts.

## 🚀 1. The Main GUI Launcher (Recommended)
**File:** `NK_RenderLauncher.vbs`

This is the primary tool for rendering. Double-clicking this file will open a dark-themed GUI instantly (with zero command prompt windows flashing) that allows you to render multiple sequences and passes in a single click.

**Features:**
- **Plastic SCM Auto-Sync:** Automatically pull the latest changes from the server before launching a render. Safely skips updates if you are rendering locally on your own machine.
- Select multiple songs (sequences).
- Select specific passes by job index (Pass 1, Pass 2, etc.). Each queue is assumed to have the same job ordering.
- Set global overrides for Spatial Samples, Temporal Samples, Warm-up frames, and Resolution.
- **No Sound toggle:** Checkbox to enable/disable `-nosound` (enabled by default). Disabling it allows WAV audio export from MRQ.
- Includes a handy "Output Folder" button to jump straight to your rendered frames.
- Runs headlessly (Unreal Engine loads in the background without stealing your screen).
- **Cancel propagation:** If you cancel a render in Unreal (Escape), the entire pipeline stops — no subsequent passes are launched.
- **Responsive GUI:** The window remains interactive while renders are running.

*(Note: The GUI relies on `NK_RenderLauncher.ps1` and `MRQ_Python_Executor.py` to function. Do not delete them).*

---

## ⚡ 2. Fast/Standalone Batch Scripts (No Python)
These scripts launch Unreal Engine in `-game` mode, meaning a live render viewport will appear, allowing you to watch the render progress. They do **not** support pass-filtering or sample-overriding; they simply render the exact preset saved in your queue.

**`Render_Single_Sequence.bat`**
- Prompts you for a 4-digit sequence code (e.g., `0130`).
- Immediately launches the live render viewport for that specific sequence.
- Renders ALL passes defined in the queue.

**`Render_All_Sequences.bat`**
- Hardcoded to run through **all 6** sequences sequentially.
- Opens the live viewport and renders everything overnight.

---

## 🐍 3. Advanced/Legacy Python Script
**File:** `Advanced_Python_Render.bat`

This is the text-based (Command Prompt) predecessor to the new GUI launcher. It functions similarly to the GUI by allowing you to inject sample overrides and filter by job index via text prompts. It is kept for legacy/fallback purposes.

---

## 🛠️ How It Works (Technical Details)
- **Path Configuration:** All batch files and the GUI will remember your Engine and Project paths. Both the `.bat` files and the GUI share and store this configuration in a `RenderConfig.bat` file.
- **Pass Filtering Logic:** When you select specific passes (e.g., Pass 1 and Pass 3), the Python executor (`MRQ_Python_Executor.py`) receives the selected job indices and removes all other jobs from the active queue before rendering. This is index-based — the order of jobs in your Render Queue asset determines which pass number corresponds to which render graph preset.
- **Cancel Propagation:** If a render is cancelled inside Unreal, the Python executor writes a `render_cancelled.marker` file. The PowerShell launcher detects this and halts the entire pipeline.
- **Headless Execution:** The Python scripts require `-unattended` editor mode to inject variables. The engine will run in the background (you will see a log window, but no viewport).
