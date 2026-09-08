# MotionFusionMATLAB organization and experiment ledger

Date: 2026-09-08

## Code layout

- `src/`: maintained measurement implementation (`+mfm`) and public measurement/evaluation functions.
- `scripts/`: user-facing entry scripts and `scripts/batch/` for the three independent batch runners.
- `experiment/scripts/`: exploratory, ablation, synthetic-validation, and review scripts.
- `experiment/tests/`: contract and regression checks used during development.
- `experiment/docs/` and `experiment/logs/`: development reports and run logs.
- `experiment/outputs_archive_20260908/`: reversible archive of research-only output trees moved out of the primary `outputs/` directory. `MOVED_OUTPUTS.txt` records the exact directory names.
- `outputs/`: retained primary/user output trees; no raw videos or source backups were deleted.
- `backups/`: source snapshots created before source changes; never delete these snapshots.

## Batch runners

1. `scripts/batch/batch_process_0723_windtunnel.m` enumerates the 0723 root and `xinjiasuduji` videos. Each entry is independently commentable. It calls `run_real_video` and additionally writes acceleration time and normalized acceleration spectrum figures under each video's `batch_acceleration` folder.
2. `scripts/batch/batch_process_0726_single.m` enumerates the seven videos in `D:\07-26_single` and calls the same measurement method without acceleration post-processing.
3. `scripts/batch/batch_process_0819_all.m` enumerates the D:, C:, and E: `0819` videos and calls the same measurement method without acceleration post-processing.

All three runners use interactive target/reference ROIs, direct target registration, flow reference tracking, no prior frequency band, and no denoise by default. Change the configuration block in the selected runner when an experiment requires a different declared setup.

## Archive policy

The archive move is reversible and was done to keep the main output directory usable. It does not change measurement code or raw input videos. New experiments should use a new output tag and should not overwrite a managed run.
