# LunFu

Source-only collection of core MATLAB and Python implementations for video-based motion and vibration measurement research.

## Layout

Each directory is an independent project with its own README and entry points:

- `MotionFusionMATLAB/` — reference-relative pixel displacement and vibration measurement.
- `MPME/` — multi-scale phase-based large-motion estimation.
- `AP-CV/`, `BPAF/`, `Crossline_Phase/`, `LoG-Gabor/`, `Pixel_Selection/`, `PLT/`, `PNL/`, `SPOF/`, `TDDM/` — MATLAB reproduction cores.
- `Pixel_Selection_py/` — Python implementation of the pixel-selection pipeline.
- `shared/RMPTF/` — optional measurement-preserving tracking frontend shared by selected projects.

Start with the README inside the project you want to run. MATLAB scripts expect MATLAB R2022b or later; toolbox requirements are documented per project. Python dependencies for `Pixel_Selection_py` are listed in [`requirements.txt`](requirements.txt).

## Data and optional dependencies

Videos, sensor files, calibration files, generated outputs, and historical experiment artifacts are external inputs. Configure their paths locally; none are included here. Generated data and outputs are ignored by the repository.

Some optional MATLAB routes use third-party packages such as fDSST/ECO, `matlabPyrTools`, or ADIC2D. They are deliberately not bundled. Obtain and install them separately, review their licenses, and add their paths only when using the corresponding route. The core implementations include fallbacks where documented by each project.

## Source policy

This repository contains source code and concise project usage notes. It excludes local datasets, result files, figures, videos, papers, reports, backups, credentials, and unrelated external code. See [`.gitignore`](.gitignore) for generated and private files excluded from future commits.
