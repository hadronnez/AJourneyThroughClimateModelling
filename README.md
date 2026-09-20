# A Journey Through Climate Modelling

# A journey through climate modelling

Code, data and figures for the newsletter **[A journey through climate modelling](SUBSTACK_URL)**.

The goal is to learn climate modelling from scratch, in public, one simple model at a time. Each step adds a single physical ingredient, so it is always clear what changed and why.

## Approach

Every experiment follows the same template, both here and in the newsletter:

1. **The idea:** which physical process we model and why it matters for climate.
2. **The equations:** where they come from, derived step by step.
3. **The code:** a minimal, runnable implementation.
4. **The results:** plots and animations showing what the model does.
5. **The limits:** what the model cannot explain, which motivates the next one.

## Experiments

| # | Experiment | What it adds | Post | Status |
|---|------------|--------------|------|--------|
| 01 | [1D soil heat conduction](01_Projects/01_soil_heat_conduction_1d/) · Experiment 1 | A four-layer soil column between two fixed temperatures | [Post](POST_URL) | Done |


## Repository structure

```
.
├── 01_Projects/
│   └── 01_soil_heat_conduction_1d/
│       ├── soil_heat_conduction_1d.jl   # model, plots, video and data export
│       └── results/
│           ├── data/                    # CSV files (temperatures, heat fluxes, energy)
│           └── plots/                   # PNG figures and MP4 animation
├── Project.toml
└── README.md
```

## Feedback

Questions, corrections and suggestions are welcome. Please open an [issue](../../issues) or leave a comment on the newsletter.

## Author

**[Your name]** · [Substack](SUBSTACK_URL) · [Contact or social link]

## License

[License, for example MIT. See `LICENSE`.]
