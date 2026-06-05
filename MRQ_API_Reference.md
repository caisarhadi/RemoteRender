# MRQ Python API — Reference & Notes

> **Source of local examples:**  
> `C:\Program Files\Epic Games\UE_5.7\Engine\Plugins\MovieScene\MovieRenderPipeline\Content\Python\`

---

## File Inventory (10 files on disk)

| File | Purpose | Key APIs Used |
|---|---|---|
| `init_unreal.py` | Auto-imports `MoviePipelineExampleRuntimeExecutor` at engine startup | `import` |
| `MovieGraphEditorExample.py` | Editor-mode queue rendering with callbacks | `MoviePipelineQueueSubsystem`, `MoviePipelinePIEExecutor`, `on_executor_finished_delegate`, `on_individual_job_started_delegate` |
| `MovieGraphEditorExampleHelpers.py` | Helper functions: variable overrides, graph traversal, callbacks | `get_or_create_variable_overrides()`, `set_value_int32()`, `set_value_serialized_string()`, `set_variable_assignment_enable_state()`, `get_variable_by_name()` |
| `MoviePipelineEditorExample.py` | Editor-mode rendering with light manipulation between jobs | `OnQueueFinishedCallback(executor, success)`, `on_individual_job_work_finished_delegate`, `on_individual_shot_work_finished_delegate` |
| `MoviePipelineExampleRuntimeExecutor.py` | Custom runtime executor for `-game` mode / render farms | `MoviePipelinePythonHostExecutor`, `execute_delayed()`, `on_begin_frame()`, `on_movie_pipeline_finished()`, `get_completion_percentage()` |
| `MoviePipelineMiscExamples.py` | Filename resolution and versioning | `MoviePipelineLibrary.resolve_filename_format_arguments()`, `resolve_version_number()` |
| `MovieGraphCreateConfigExample.py` | Programmatic graph config creation | `create_node_by_class()`, `add_labeled_edge()`, `add_variable()`, `toggle_promote_property_to_pin()` |
| `MovieGraphQuickRenderExample.py` | Quick Render subsystem usage | `MovieGraphQuickRenderSubsystem`, `begin_quick_render()`, `MovieGraphQuickRenderModeSettings` |
| `MovieGraphScriptNodeExample.py` | Execute Script node callbacks (per-job, per-shot) | `MovieGraphScriptBase`, `on_job_start()`, `on_job_finished()`, `on_shot_start()`, `on_shot_finished()` |
| `mrq_stills.py` | Stills sequence creation for MRQ | `AssetToolsHelpers`, `LevelSequence`, `CameraCutTrack` |

---

## Key API Patterns

### 1. Executor Finished Callback — Cancel Detection

From `MovieGraphEditorExampleHelpers.py`:

```python
def on_queue_finished_callback(executor: unreal.MoviePipelineExecutorBase, success: bool):
    """Is called after the executor has finished rendering all jobs

    Args:
        success (bool): True if all jobs completed successfully, false if a job 
                        encountered an error (such as invalid output directory)
                        or user cancelled a job (by hitting escape)
        executor (unreal.MoviePipelineExecutorBase): The executor that run this queue
    """
```

> **Key takeaway:** `success=False` is the ONLY signal for user cancellation. There is no separate "cancelled" event. Cancellation and errors both produce `success=False`.

### 2. Executor Creation — PIE vs Runtime

**PIE Executor (Editor mode, used by our scripts):**
```python
executor = unreal.MoviePipelinePIEExecutor(subsystem)  # UE 5.7 takes subsystem arg
# OR
executor = unreal.MoviePipelinePIEExecutor()  # Also valid in some examples
```

**Runtime Executor (for `-game` mode / render farms):**
```python
@unreal.uclass()
class MyExecutor(unreal.MoviePipelinePythonHostExecutor):
    @unreal.ufunction(override=True)
    def execute_delayed(self, inPipelineQueue): ...
    @unreal.ufunction(override=True)
    def on_begin_frame(self): ...  # Called every tick — for progress polling
```

### 3. Variable Overrides (used by MRQ_Python_Executor.py)

From `MovieGraphEditorExampleHelpers.py`:

```python
graph = job.get_graph_preset()
variable_overrides = job.get_or_create_variable_overrides(graph)

# For simple types:
var_obj = graph.get_variable_by_name("SpatialSampleCount")
variable_overrides.set_value_int32(var_obj, 4)
variable_overrides.set_variable_assignment_enable_state(var_obj, True)

# For structs (like resolution):
variable_overrides.set_value_serialized_string(var_obj, 
    unreal.MovieGraphLibrary.named_resolution_from_profile("720p (HD)").export_text())
```

> **Note:** Variable names use `get_member_name()`, NOT `get_name()`. The latter returns internal object names.

### 4. Keep Script Alive

```python
unreal.EditorPythonScripting.set_keep_python_script_alive(True)
```
Required when using `-ExecutePythonScript` with async operations (like rendering). Without this, Python exits and the render never starts.

### 5. Global Variables for GC Prevention

All examples use global variables to prevent garbage collection from destroying the executor mid-render:
```python
active_executor = None  # Global
active_delegate = None  # Global
```

### 6. Queue Operations

```python
# Get subsystem
subsystem = unreal.get_editor_subsystem(unreal.MoviePipelineQueueSubsystem)

# Get active queue
pipeline_queue = subsystem.get_queue()

# Load a saved queue asset and copy into active queue
queue_asset = unreal.EditorAssetLibrary.load_asset("/Game/Path/To/Queue.Queue")
pipeline_queue.copy_from(queue_asset)

# Get jobs (ordered as they appear in the MRQ UI)
jobs = pipeline_queue.get_jobs()    # Returns array, 0-indexed

# Delete specific job
pipeline_queue.delete_job(job)

# Delete all
pipeline_queue.delete_all_jobs()

# Job properties
job.job_name                        # Display name
job.get_graph_preset()              # Returns the graph config (Settings column)
job.get_graph_preset().get_name()   # Internal name of the preset
```

### 7. Render Execution

```python
# Start render (non-blocking — returns immediately)
subsystem.render_queue_with_executor_instance(executor)

# The render runs asynchronously. The on_executor_finished delegate
# fires when ALL jobs in the queue complete (or are cancelled).
```

---

## `-nosound` Command Line Argument

**What it does:** Disables the engine's audio mixer entirely at startup. No audio subsystem is initialized.

**Effect on MRQ:** MRQ's WAV audio export relies on the engine's audio mixer to capture audio during the render. With `-nosound`, there is no audio mixer, so exported WAV files will be **silent**.

**Effect on rendering:** Prevents real-time audio playback (looping sounds, music) from playing during headless batch renders. This is desirable when rendering overnight or on remote machines where audio output is unwanted noise.

**Conclusion:** `-nosound` is correct for image-only renders. If WAV audio export is ever needed, it must be removed for those specific render jobs.

---

## Render Progress APIs (Not Currently Used)

These APIs exist inside the Unreal process for tracking render progress. Documented here for reference only.

| API | Where Available | Returns |
|---|---|---|
| `MoviePipelineLibrary.get_completion_percentage(pipeline)` | Runtime executor `on_begin_frame` | `float` 0.0–1.0 |
| `job.get_status_progress()` | Custom executor with job reference | `float` 0.0–1.0 |

Since the PowerShell GUI and Unreal are separate OS processes, real-time progress display would require file-based IPC (Python writes progress to a temp file, PowerShell reads it). This was evaluated and deemed not worth the complexity.
