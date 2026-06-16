# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Xplace is a GPU-accelerated global placement framework for VLSI physical design, built on PyTorch with custom C++/CUDA extensions. It runs the full placement flow: parse LEF/DEF (or bookshelf), global placement (GP), legalization (LG), detailed placement (DP), with optional routability-driven placement, timing-driven placement, and GPU global routing.

## Build

The C++/CUDA extensions must be compiled before any Python entrypoint will work. They build into `cpp_to_py/cpybin/` as `*.so` pybind11 modules, imported via `cpp_to_py/__init__.py`.

```bash
mkdir build && cd build
cmake -DCMAKE_CUDA_ARCHITECTURES=native -DPYTHON_EXECUTABLE=$(which python) ..
make -j40 && make install   # `install` copies the .so files into cpp_to_py/cpybin/
```

- If `native` fails, pass the GPU compute capability directly, e.g. `-DCMAKE_CUDA_ARCHITECTURES=86` for an RTX 3090.
- CUDA is mandatory — CMake exits with `FATAL_ERROR` if Torch was built without CUDA. There is no CPU fallback.
- The build reads the installed PyTorch's path, version, and `_GLIBCXX_USE_CXX11_ABI` setting at configure time, so CMake must run against the same Python/PyTorch you run with.
- After editing any C++/CUDA source under `cpp_to_py/`, re-run `make -j40 && make install` from `build/`.

Requires CMake >= 3.24, GCC >= 7.5, Boost >= 1.56, CUDA >= 11.3, Python >= 3.8, PyTorch >= 1.12, Cairo. The only git submodule is `thirdparty/pybind11` (clone with `--recursive`); other thirdparty libs (flute, lemon, lefdef, placers) are vendored.

## Data

Benchmarks are not in the repo (`data/raw` and `data/cad` are gitignored).

```bash
cd data
./download_data.sh                                   # downloads ispd2005/2015/2018/2019, iccad2019 into data/raw
python convert_design_to_torch_data.py --dataset ispd2005   # preprocess raw -> data/cad/<dataset>/<design>.pt
```

`download_data.sh` also produces `ispd2015_fix` (errors patched so Innovus can detail-route it). Note `--dataset ispd2015` and `--dataset ispd2019` are auto-redirected to `ispd2015_fix` / `ispd2019_no_fence` because fence regions are unsupported.

## Run

All runs go through `main.py`. Output lands in `result/<exp_id>/{eval,log,output}`.

```bash
python main.py --dataset ispd2005 --design_name adaptec1        # single design
python main.py --dataset ispd2005 --run_all True                # whole dataset

# routability-driven
python main.py --dataset ispd2015_fix --run_all True --use_cell_inflate True
# timing-driven (iccad2015)
python main.py --dataset iccad2015 --design_name superblue4 --timing_opt True
# mixed-size
python main.py --dataset mms --run_all True --mixed_size True
# place + GPU global route (GGR) eval
python main.py --dataset ispd2015_fix --run_all True --load_from_raw True --detail_placement True --use_cell_inflate True --final_route_eval True

# custom designs (no registered dataset)
python main.py --custom_path lef:path.lef,def:path.def,design_name:toy,benchmark:test --load_from_raw True --detail_placement True
python main.py --custom_json examples/examples.json --load_from_raw True
```

Standalone GPU timer: edit design params in `tool/timer.py`, then `python tool/timer.py`.

### Key flags (see `main.py::get_option` for the full list)
- `--load_from_raw` — `True` parses LEF/DEF from scratch; `False` loads a preprocessed `.pt` (faster, recommended for GP development). Always use `True` when measuring total runtime. `.pt` mode is unsupported for routability-driven runs and needs the dataset registered in `utils/get_design_params.py`.
- `--deterministic` — on by default; set `False` for max speed without reproducibility.
- `--run_all` — iterate every design in the dataset, writing `run_all.csv`.
- Stage toggles: `--global_placement`, `--legalization`, `--detail_placement`, `--final_route_eval`.

## Architecture

The flow is orchestrated in Python; all compute-heavy kernels live in C++/CUDA extensions called through pybind11.

**Entry path:** `main.py` → `src/run_placement.py::run_placement_main` (single vs `run_all`) → `src/run_placement_nesterov.py::run_placement_main_nesterov`. The latter is the real driver: it loads the design, runs `global_placement_main` (the Nesterov optimization loop), then detailed placement, then optional routing eval.

**Data loading:** `utils/get_design_params.py` resolves a dataset+design_name (or `--custom_path`/`--custom_json`) into a params dict of file paths. `utils/setup_dataset.py::find_design_params` wraps this. `src/database.py::load_dataset` invokes the C++ `io_parser` (via `utils/io_parser.py`) to build `rawdb`/`gpdb` C++ databases, then materializes a `PlaceData` object — the central PyTorch tensor container (node positions/sizes, pin offsets, net connectivity, die bounds, movable/fixed indices) that every kernel consumes. `.preprocess()` and `.init_filler()` finalize it on-GPU.

**Global placement loop** (`run_placement_nesterov.py::global_placement_main`): an analytical placer minimizing weighted wirelength + density penalty.
- `NesterovOptimizer` (`src/nesterov_optimizer.py`) drives iterations; `src/calculator.py` builds the `obj_and_grad_fn`.
- `ElectronicDensityLayer` (`src/core/electronic_density_layer.py`) computes the eDensity electrostatic density penalty via FFT/DCT (`src/core/dct2_fft2.py`, `torch_dct.py`, backed by `dct_cuda`/`density_map_cuda`).
- Wirelength: weighted-average model in `src/core/wa_wirelength_hpwl.py` (backed by `wa_wirelength_hpwl_cuda`, `hpwl_cuda`).
- `ParamScheduler` (`src/param_scheduler.py`) governs the whole loop — density-weight ramping, overflow-based early stop, best-solution tracking, and the switching between plain GP, routability mode, mixed-size mode, and timing mode. **This is the place to understand scheduling/convergence behavior.**

**Optional modes interleaved into the GP loop:**
- *Routability* (`--use_cell_inflate` / `--use_route_force`): `src/core/route_force.py` periodically runs the GPU global router (`gpugr`, the GGR engine) to get congestion, then inflates cells or adds routing forces.
- *Timing* (`--timing_opt`): `GPUTimer` (`src/core/timing_opt.py`, backed by `gputimer` + `wirelength_timing_cuda`) does GPU static timing analysis with calibration and adds a per-pin, slack-driven extra wirelength force each iteration. See "Timing-driven internals" below.
- *Mixed-size* (`--mixed_size`): macros are placed and legalized (`src/core/macro_legalization.py`) mid-loop, then std cells re-placed with macros fixed.

**Detailed placement** (`src/detail_placement.py`): legalization + DP via the `gpudp`/`routedp` engines.

### Timing-driven internals (`--timing_opt`)
Timing optimization is *not* a separate optimizer — it injects an additive, per-pin wirelength gradient into the same Nesterov loop. The flow spans Python + the `gputimer` C++/CUDA extension; trace it in this order:

1. **Where the weight is computed:** `GPUTimer.step()` in `src/core/timing_opt.py` (NOT in `ParamScheduler`). The product is `timing_pin_weight`, a **per-pin** tensor (length = num_pins), not per-net.
2. **`ParamScheduler`'s only timing role** is bookkeeping: `push_timing_sol`/`get_best_timing_sol` keep the best (lowest-WNS) solution seen (gated on `overflow < stop_overflow`), and `timing_wl_weight` is used only as a weight floor. `timing_wl_weight` and several `GPUTimer` fields (`alpha`, `global_weight`, the `window`/`*_mean` rolling means) are declared-but-inert in the current code — the `*_mean` names actually take the latest value (`x[-1]`), not a mean.
3. **Init (`src/initializer.py`, `elif args.timing_opt:` branch):** sets `ps.timing_wl_weight = args.timing_init_weight` (default 0.05 — the global scale knob), `gputimer.beta = 5 * timing_init_weight` (so `beta=0.25` at runtime, *not* the `0` from the constructor — all three weight terms are live), and `ps.max_life = 50` (timing mode oscillates, so divergence tolerance is loosened).
4. **Weight formula** (3 additive terms): normalized endpoint violation `|slack|/|WNS|·β`, a mid-criticality term `(delay_k/last)·2β`, and a dominant exponential term `2^(delay_1/last)·pin_visited` over the most-critical paths. Then an **asymmetric EMA** smooths it: `decay = clamp(decay_factor·5^(Δweight⁺)/decay_boost, max=0.5)` (defaults 0.3/3 → base 0.1) blends new vs. history — fast to raise weight on newly-critical pins, slow to lower it (anti-oscillation).
5. **How it enters the gradient:** `src/calculator.py` (`if ps.enable_timing:`) calls `merged_wl_loss_grad_timing` (→ `wirelength_timing_cuda`) and *adds* the per-pin-weighted WA gradient on top of the base wirelength gradient — it does not replace it.
6. **Criticality source** (`cpp_to_py/gputimer/core/path.cpp` + `path.cu`): `report_criticality_threshold(thrs)` selects endpoints whose worst slack is within `thrs·WNS` (a **WNS-relative band**, self-shrinking as timing improves; `K=0` when timing is met), then `explore_path_kernel` walks each path back via the arrival-time predecessor pointers (`at_prefix_pin/arc/attr`), accumulating per-pin `from_pin_delay` discounted by endpoint rank `1/(1+k)²` and marking `pin_visited`. Net arcs credit the sink pin, cell arcs credit the driver. The `deterministic` variant uses fixed-point uint64 atomics for reproducibility.
7. **Calibration** (`update_timing_calibrated` vs. `update_timing`, driven from `run_placement_nesterov.py`): the cheap GPU RC/delay model drifts from the golden timer, so it is periodically recalibrated once overflow drops below a shrinking threshold (`timing_cali_thrs_overflow`, stepped by `--calibration_step`).

The numeric source under all of this is the RC/delay model in `gputimer` (`update_rc`), parameterized by `--wire_resistance_per_micron` / `--wire_capacitance_per_micron`, which turns placement geometry into arc delays.

**C++/CUDA extensions** (`cpp_to_py/`, each its own CMake subdir → one `.so`):
`io_parser` (LEF/DEF/bookshelf parsing + DB), `gpugr` (GGR global router — see its README), `gpudp`/`routedp` (detailed placement), `gputimer` + `wirelength_timing_cuda` (timing), `dct_cuda`/`density_map_cuda`/`hpwl_cuda`/`wa_wirelength_hpwl_cuda` (placement kernels), `flute_cpp` (RSMT wirelength), `draw_placement` (Cairo visualization), `common` (shared utilities/DB).

**Python package layout:** `src/` is the placement algorithm (`core/` = the differentiable/CUDA-backed building blocks); `utils/` is I/O, dataset resolution, logging (`utils/logger.py`), and visualization; `tool/` holds the standalone timer and external routability-eval flows (CU-GR, Innovus).

## Conventions
- `PlaceData` is the single source of truth for tensors passed between stages; new metrics or node attributes attach there.
- New datasets: register paths in `utils/get_design_params.py` (both `find_benchmark` and a `single_*`/`multiple` resolver).
- The whole pipeline assumes a single CUDA device selected by `--gpu`; tensors are moved with `data.to(device)`.
