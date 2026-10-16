Companion code for the newsletter [*A Journey Through Climate Modelling*](https://ajourneythroughclimatemodelling.substack.com/): climate models built from the ground up, one piece of physics at a time.

Climate models can feel like black boxes. Here we open them up. We start with the simplest models (heat conduction in soil, a basic energy balance) and add one process at a time, so you can see how a single equation grows into a full climate model.

## How the series works

Every post follows the same template, and every post has a runnable model in this repository:

1. **The idea**: the physical process and why it matters for climate
2. **The equations**: derived step by step
3. **The code**: a minimal implementation in Julia
4. **The results**: plots and animations
5. **The limits**: what the model cannot explain, which motivates the next one

No expertise needed: curiosity, basic maths and a bit of code reading are enough.

## Quick start

```bash
git clone https://github.com/hadronnez/AJourneyThroughClimateModelling.git
cd AJourneyThroughClimateModelling
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia include("run_experiment.jl")
```

A run is controlled by three YAML files in `cfgs/`:

| File | Controls |
|---|---|
| `exp_cfg.yaml` | experiment id and what to save |
| `sim_cfg.yaml` | grid, physics, initial and boundary conditions |
| `plot_cfg.yaml` | figures: language, style, which plots and animations |

Change a parameter, run again, and compare.

## Outputs

Each run writes to `experiments/<id>/`:

- `cfgs/`: the three configs exactly as used (defaults filled in). Copy them back into `cfgs/` to reproduce the run.
- `data/`: results in NetCDF
- `plots/`: figures and animations
- `log/`: run log

## Follow along

New posts and the code that goes with them appear on the [Substack](https://ajourneythroughclimatemodelling.substack.com/). Questions and suggestions are welcome as issues.
…]()
