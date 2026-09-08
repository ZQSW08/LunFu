# MotionFusionMATLAB

The maintained implementation is under `src/`. Run user-facing examples from `scripts/`; the three independent batch runners are in `scripts/batch/`. Development and validation scripts are kept under `experiment/scripts/`, with reports/logs and an output archive under `experiment/`.

## Run a single video

Open `scripts/run_user_video.m` in MATLAB, set the input video and ROI/reference configuration, and run the script. It adds `src/` to the MATLAB path automatically. Outputs remain under `outputs/`.

## Run batches

Run one of these files after commenting/uncommenting the desired entries:

- `scripts/batch/batch_process_0723_windtunnel.m`
- `scripts/batch/batch_process_0726_single.m`
- `scripts/batch/batch_process_0819_all.m`

The 0723 runner adds acceleration figures in a separate `batch_acceleration` subfolder; the core method outputs are unchanged.

The six user entry scripts are explained in [`scripts/USER_ENTRY_SCRIPTS_GUIDE.md`](scripts/USER_ENTRY_SCRIPTS_GUIDE.md).

## Traceability

Before modifying maintained source, run `backup_core.ps1 -Label <label>`. The resulting snapshot is stored in `backups/`. Git commits are used for source history; videos, generated outputs, and backups are not published.
