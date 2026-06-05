import unreal  # type: ignore  # Only available inside UE Python runtime
import re
import os

# Global variables to prevent garbage collection freezing the process
active_executor = None
active_delegate = None

def get_arg(arg_name, default=None):
    cmd_line = unreal.SystemLibrary.get_command_line()
    # Safely extract the argument, handling quotes
    pattern = rf'-{arg_name}=(?:"([^"]*)"|(\S+))'
    match = re.search(pattern, cmd_line, re.IGNORECASE)
    if match:
        return match.group(1) if match.group(1) is not None else match.group(2)
    return default

def get_script_dir():
    """Get the directory where this script lives, for sentinel file placement."""
    cmd_line = unreal.SystemLibrary.get_command_line()
    match = re.search(r'-ExecutePythonScript=(?:"([^"]*)"|(\S+))', cmd_line, re.IGNORECASE)
    if match:
        script_path = match.group(1) if match.group(1) is not None else match.group(2)
        return os.path.dirname(os.path.abspath(script_path))
    return os.getcwd()

def on_executor_finished(executor, success):
    """Called when the render queue finishes.
    
    Args:
        executor: The executor that ran the queue.
        success: True if all jobs completed successfully.
                 False if a job encountered an error or the user cancelled
                 (e.g. by hitting Escape in the viewport).
    """
    if success:
        unreal.log("Render completed successfully. Quitting editor.")
    else:
        unreal.log_warning("Render was CANCELLED or encountered an error.")
        # Write a sentinel file so the external launcher (PowerShell) knows
        # to stop launching subsequent render passes.
        marker_path = os.path.join(get_script_dir(), "render_cancelled.marker")
        try:
            with open(marker_path, 'w') as f:
                f.write("cancelled")
            unreal.log(f"Cancel marker written to: {marker_path}")
        except Exception as e:
            unreal.log_error(f"Failed to write cancel marker: {e}")
    
    unreal.SystemLibrary.quit_editor()

def run_render():
    global active_executor, active_delegate

    queue_path = get_arg("Queue")
    if not queue_path:
        unreal.log_error("No Queue provided!")
        unreal.SystemLibrary.quit_editor()
        return

    # Index-based job filtering: comma-separated 1-based indices (e.g. "1,3,4")
    job_indices_str = get_arg("JobIndices", "")
    spatial = get_arg("Spatial")
    temporal = get_arg("Temporal")
    warmup = get_arg("WarmUp")
    resx = get_arg("RenderResX")
    resy = get_arg("RenderResY")

    unreal.log(f"--- MRQ Python Executor ---")
    unreal.log(f"Queue: {queue_path}")
    unreal.log(f"JobIndices: {job_indices_str}")

    # Parse job indices (1-based from GUI, convert to 0-based set)
    selected_indices = set()
    if job_indices_str:
        for part in job_indices_str.split(','):
            part = part.strip()
            if part.isdigit():
                selected_indices.add(int(part) - 1)  # Convert to 0-based

    # Load Queue
    queue_asset = unreal.EditorAssetLibrary.load_asset(queue_path)
    if not queue_asset:
        unreal.log_error(f"Failed to load queue asset: {queue_path}")
        unreal.SystemLibrary.quit_editor()
        return

    subsystem = unreal.get_editor_subsystem(unreal.MoviePipelineQueueSubsystem)
    active_queue = subsystem.get_queue()
    active_queue.delete_all_jobs() 
    
    # Duplicate jobs from the saved queue into the active subsystem queue
    active_queue.copy_from(queue_asset)

    unreal.log("Jobs found in Queue before filtering:")
    all_jobs = active_queue.get_jobs()
    for i, job in enumerate(all_jobs):
        unreal.log(f"  [{i+1}] Job Name: '{job.job_name}'")

    jobs_to_delete = []

    for i, job in enumerate(active_queue.get_jobs()):
        job_name = job.job_name
        
        # Index-based filtering: if indices were specified, only keep matching jobs
        if selected_indices and i not in selected_indices:
            jobs_to_delete.append(job)
            unreal.log(f"  Filtering out [{i+1}]: {job_name} (not in selected indices)")
            continue

        try:
            graph_preset = job.get_graph_preset()
        except AttributeError:
            graph_preset = job.get_configuration() # Fallback for legacy queues
            
        if not graph_preset:
            unreal.log_warning(f"No graph preset found for job {job_name}")
            continue

        preset_name = graph_preset.get_name()
        unreal.log(f"Configuring Job [{i+1}]: {job_name} with Preset: {preset_name}")

        # Overrides - uses the correct API from Epic's MovieGraphEditorExampleHelpers.py
        # Variable overrides require the actual variable OBJECT, not a string name.
        try:
            overrides = job.get_or_create_variable_overrides(graph_preset)
            
            if overrides:
                if spatial is not None:
                    var_obj = graph_preset.get_variable_by_name("SpatialSampleCount")
                    if var_obj:
                        overrides.set_value_int32(var_obj, int(spatial))
                        overrides.set_variable_assignment_enable_state(var_obj, True)
                        unreal.log(f"  Override -> SpatialSampleCount = {spatial}")
                    else:
                        unreal.log_warning("  Variable 'SpatialSampleCount' not found in graph")
                    
                if temporal is not None:
                    var_obj = graph_preset.get_variable_by_name("TemporalSampleCount")
                    if var_obj:
                        overrides.set_value_int32(var_obj, int(temporal))
                        overrides.set_variable_assignment_enable_state(var_obj, True)
                        unreal.log(f"  Override -> TemporalSampleCount = {temporal}")
                    else:
                        unreal.log_warning("  Variable 'TemporalSampleCount' not found in graph")
                    
                if warmup is not None:
                    var_obj = graph_preset.get_variable_by_name("NumWarmUpFrames")
                    if var_obj:
                        overrides.set_value_int32(var_obj, int(warmup))
                        overrides.set_variable_assignment_enable_state(var_obj, True)
                        unreal.log(f"  Override -> NumWarmUpFrames = {warmup}")
                    else:
                        unreal.log_warning("  Variable 'NumWarmUpFrames' not found in graph")
                    
                if resx is not None and resy is not None:
                    var_obj = graph_preset.get_variable_by_name("OutputResolution")
                    if var_obj:
                        try:
                            named_res = unreal.MovieGraphLibrary.named_resolution_from_size(int(resx), int(resy))
                            overrides.set_value_serialized_string(var_obj, named_res.export_text())
                            overrides.set_variable_assignment_enable_state(var_obj, True)
                            unreal.log(f"  Override -> OutputResolution = {resx}x{resy}")
                        except Exception as e:
                            unreal.log_error(f"  Failed to set OutputResolution: {e}")
                    else:
                        unreal.log_warning("  Variable 'OutputResolution' not found in graph")
                        
        except Exception as e:
            unreal.log_warning(f"Failed to apply overrides for {job_name}: {e}")

    # Remove filtered jobs
    for job in jobs_to_delete:
        active_queue.delete_job(job)
        
    if len(active_queue.get_jobs()) == 0:
        unreal.log_error(f"No jobs left to render after filtering (indices: {job_indices_str})")
        unreal.SystemLibrary.quit_editor()
        return

    unreal.log(f"Starting render with {len(active_queue.get_jobs())} job(s)...")

    # Start Render
    active_executor = unreal.MoviePipelinePIEExecutor()
    
    active_delegate = unreal.OnMoviePipelineExecutorFinished()
    active_delegate.add_callable(on_executor_finished)
    active_executor.set_editor_property('on_executor_finished_delegate', active_delegate)

    unreal.EditorPythonScripting.set_keep_python_script_alive(True)
    subsystem.render_queue_with_executor_instance(active_executor)

if __name__ == "__main__":
    run_render()
