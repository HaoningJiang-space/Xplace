# Repository Guidelines

## Project Structure & Module Organization

Xplace is a GPU-accelerated global placement framework. `main.py` is the primary CLI and dispatches into `src/run_placement.py` and `src/run_placement_nesterov.py`. Algorithm code lives in `src/`, with differentiable and CUDA-backed building blocks in `src/core/`. `utils/` contains dataset lookup, parsers, logging, and visualization helpers. Native pybind11/C++/CUDA modules are under `cpp_to_py/`; built `.so` files install into `cpp_to_py/cpybin/`. Benchmark helpers are in `data/`, examples in `examples/`, images in `img/`, standalone tools in `tool/`, and research notes or experiment scripts in `research/`.

## Build, Test, and Development Commands

- `mkdir -p build && cd build && cmake -DCMAKE_CUDA_ARCHITECTURES=native -DPYTHON_EXECUTABLE=$(which python) ..`: configure CUDA/PyTorch extensions.
- `cmake --build build -j40 --target install`: compile and copy extension modules into `cpp_to_py/cpybin/`.
- `cd data && ./download_data.sh`: fetch standard benchmarks into `data/raw`.
- `python main.py --dataset ispd2005 --design_name adaptec1`: run one placement flow.
- `python tool/timer.py`: run standalone GPU timer after editing its design parameters.

CUDA-enabled PyTorch is required; there is no CPU fallback for the full placement flow.

## Coding Style & Naming Conventions

Use Python 3 with 4-space indentation and descriptive `snake_case` names for modules, functions, variables, and CLI flags. Keep C++/CUDA targets aligned with the existing one-module-per-directory pattern in `cpp_to_py/`. Register new native modules in both `cpp_to_py/CMakeLists.txt` and `cpp_to_py/__init__.py`. Prefer small, explicit changes in scheduler and core modules because placement modes share state through `PlaceData`.

## Testing Guidelines

There is no central pytest configuration. Use focused executable tests and smoke runs. Run `python tool/test_detour_timing.py` for the CPU finite-difference check of detour timing. After native changes, rebuild and install, then run a small benchmark such as `python main.py --dataset ispd2005 --design_name adaptec1`. Keep `--deterministic True` unless testing speed-only behavior.

## Commit & Pull Request Guidelines

Recent commits use concise, scope-first subjects with experiment identifiers when relevant, for example `bp_multi_top bridge pipeline...` or `DIVERGENCE_LAW...`. Keep the first line specific to the changed component or result. Pull requests should describe the affected flow, commands run, dataset and design used, and generated outputs under `result/<exp_id>/`. Link issues or research notes when applicable; include screenshots only for visualization changes.
