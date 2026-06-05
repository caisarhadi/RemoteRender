# Render Scripts

This folder contains the automation scripts for launching and managing Movie Render Queue (MRQ) renders via Unreal Engine — both locally and on remote PCs via Plastic SCM.

> **API Reference:** See [MRQ_API_Reference.md](MRQ_API_Reference.md) for documentation on the Unreal Python APIs used by these scripts.

## 🚀 1. The Main GUI Launcher (Recommended)
**File:** `NK_RenderLauncher.vbs`

This is the primary tool for rendering. Double-clicking this file will open a dark-themed GUI instantly (with zero command prompt windows flashing) that allows you to render multiple sequences and passes in a single click — locally or on remote machines.

**Features:**
- **Plastic SCM Auto-Sync:** Automatically pull the latest changes from the server before launching a render.
- Select multiple songs (sequences).
- Select specific passes by job index (Pass 1, Pass 2, etc.). Each queue is assumed to have the same job ordering.
- Set global overrides for Spatial Samples, Temporal Samples, Warm-up frames, and Resolution.
- **No Sound toggle:** Checkbox to enable/disable `-nosound` (enabled by default). Disabling it allows WAV audio export from MRQ.
- Includes a handy "Output Folder" button to jump straight to your rendered frames.
- Runs headlessly (Unreal Engine loads in the background without stealing your screen).
- **Cancel propagation:** If you cancel a render in Unreal (Escape), the entire pipeline stops — no subsequent passes are launched.
- **Responsive GUI:** The window remains interactive while renders are running.

### Remote Rendering
- **Target PC selector:** Choose which machine should execute the render (Local, PC 002, PC 003, PC 004).
- **Listening Mode:** Check "Enable Listening Mode" on a remote PC to have it automatically poll Plastic SCM every 30 seconds for incoming render jobs.
- **Crash-safe job claiming:** When a remote PC picks up a job, it removes the job from Plastic SCM *before* starting the render. If the PC crashes mid-render, the job won't be re-executed on restart or picked up by another machine.
- **Human activity detection:** The listener skips execution if Unreal Editor is already open (assumes a human is working).

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

### Path Configuration
All batch files and the GUI will remember your Engine and Project paths. Both the `.bat` files and the GUI share and store this configuration in a `RenderConfig.bat` file. The GUI also saves **PC Identity** and **Listen Mode** state to this file, so each machine remembers its role across restarts.

```
set ENGINE="C:\...\UnrealEditor-Cmd.exe"
set PROJECT="D:\...\MyProject.uproject"
set IDENTITY="PC 002"
set LISTEN="TRUE"
```

> **Note:** `RenderConfig.bat` should be **cloaked** in Plastic SCM on remote PCs so each machine keeps its own private config without overwriting others.

### Pass Filtering Logic
When you select specific passes (e.g., Pass 1 and Pass 3), the Python executor (`MRQ_Python_Executor.py`) receives the selected job indices and removes all other jobs from the active queue before rendering. This is index-based — the order of jobs in your Render Queue asset determines which pass number corresponds to which render graph preset.

### Cancel Propagation
If a render is cancelled inside Unreal, the Python executor writes a `render_cancelled.marker` file. The PowerShell launcher detects this and halts the entire pipeline.

### Headless Execution
The Python scripts require `-unattended` editor mode to inject variables. The engine will run in the background (you will see a log window, but no viewport).

### Remote Render Dispatch Flow
1. On your local PC, select a remote Target PC and click **Launch Render**.
2. The script generates `.json` job files in `RemoteRender\Jobs\` and commits them to Plastic SCM.
3. On the remote PC (with Listen Mode enabled), the 30-second timer polls Plastic SCM via `cm update`.
4. When a matching job is found, the remote PC **claims it** (`cm remove` + `cm checkin`) — consuming it from the server.
5. It syncs the heavy Unreal project (`cm update` from the project directory).
6. It launches `UnrealEditor-Cmd.exe` headlessly to render.

> **Branch Workflow:** Remote PCs pull from whatever branch their workspace is set to. Job files must be committed to that same branch. If you dispatch from a feature branch but remote PCs are on `main`, they will never see the jobs.

---

## 📁 File List

| File | Purpose |
|:-----|:--------|
| `NK_RenderLauncher.vbs` | Entry point — launches the GUI without a console window |
| `NK_RenderLauncher.ps1` | Main GUI script (WinForms) — local/remote rendering + listening |
| `NK_RenderLauncher.bat` | Alternative entry point (shows console) |
| `MRQ_Python_Executor.py` | Unreal Python script executed inside `UnrealEditor-Cmd.exe` |
| `RenderConfig.bat` | Per-machine config (engine path, project path, identity, listen mode) |
| `MRQ_API_Reference.md` | Unreal MRQ Python API reference |
| `Jobs/` | Directory for `.json` job files dispatched to remote PCs |
| `Render_Single_Sequence.bat` | Standalone: render one sequence with live viewport |
| `Render_All_Sequences.bat` | Standalone: render all sequences sequentially |
| `Advanced_Python_Render.bat` | Legacy text-based render launcher |
