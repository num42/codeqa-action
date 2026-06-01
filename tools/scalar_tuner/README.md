# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.

## Generating `metric_report.json`

The tuner expects `public/metric_report.json` to exist (loaded via `fetch('/metric_report.json')` in `src/App.jsx`).

This file is **not committed** because it's a multi-megabyte regeneratable artifact. To produce it from the parent project:

```bash
# From the repo root
mix run -e 'CodeQA.CombinedMetrics.SampleRunner.dump_metric_report("tools/scalar_tuner/public/metric_report.json")'
```

(Or whatever the actual generation command is — check `lib/codeqa/combined_metrics/sample_runner.ex`. If unsure, copy a sample from a CI artifact or generate via the health-report command.)
