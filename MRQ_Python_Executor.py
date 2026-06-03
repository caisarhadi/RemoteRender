import unreal
import re

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

def on_executor_finished(executor, success):
    unreal.log("Render finished. Quitting editor.")
    unreal.SystemLibrary.quit_editor()

def run_render():
    global active_executor, active_delegate

    queue_path = get_arg("Queue")
    if not queue_path:
        unreal.log_error("No Queue provided!")
        unreal.SystemLibrary.quit_editor()
        return

    pass_filter = get_arg("PassFilter", "")
    spatial = get_arg("Spatial")
    temporal = get_arg("Temporal")
    warmup = get_arg("WarmUp")
    resx = get_arg("RenderResX")
    resy = get_arg("RenderResY")

    unreal.log(f"--- MRQ Python Executor ---")
    unreal.log(f"Queue: {queue_path}")
    unreal.log(f"PassFilter: {pass_filter}")

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
    for job in active_queue.get_jobs():
        unreal.log(f"  --> Found Job Name: '{job.job_name}'")

    jobs_to_delete = []

    for job in active_queue.get_jobs():
        job_name = job.job_name
        
        try:
            graph_preset = job.get_graph_preset()
        except AttributeError:
            graph_preset = job.get_configuration() # Fallback for legacy queues
            
        if not graph_preset:
            unreal.log_warning(f"No graph preset found for job {job_name}")
            continue

        preset_name = graph_preset.get_name()
        
        # Pass Filtering uses the Graph Preset Name (Settings column)
        # Matches the pass name at the end, allowing optional _SO suffix.
        # e.g. filter "House" matches "MRG_NK_Passes_House" and "MRG_NK_Passes_House_SO"
        #      but NOT "MRG_NK_Passes_House_Back" or "MRG_NK_Passes_House_Back_SO"
        if pass_filter:
            pattern = rf'_{re.escape(pass_filter)}(_SO)?$'
            if not re.search(pattern, preset_name, re.IGNORECASE):
                jobs_to_delete.append(job)
                continue
            
        unreal.log(f"Configuring Job: {job_name} with Preset: {preset_name}")

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
        unreal.log_error(f"No jobs left to render after filtering for: {pass_filter}")
        unreal.SystemLibrary.quit_editor()
        return

    # Start Render
    active_executor = unreal.MoviePipelinePIEExecutor()
    
    active_delegate = unreal.OnMoviePipelineExecutorFinished()
    active_delegate.add_callable(on_executor_finished)
    active_executor.set_editor_property('on_executor_finished_delegate', active_delegate)

    unreal.EditorPythonScripting.set_keep_python_script_alive(True)
    subsystem.render_queue_with_executor_instance(active_executor)

if __name__ == "__main__":
    run_render()
