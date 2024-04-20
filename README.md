# README for `signal_pipeline`

The signal processing and correlation components of the TART radio telescope. The following figure shows part of what we're building.

![First-stage of the visibilities calculation.](doc/diagrams/core-overview.pdf "First-stage of the visibilities calculation")

## Dependencies

Clone using:
```{.sh}
> git clone --recurse-submodules https://github.com/tart-telescope/signal_pipeline.git
```
in order to fetch the dependencies.

To build the documentation, [`pandoc`](https://pandoc.org/) is required.

The TART generator requires [Rust](https://rustup.rs/).

## Building using Docker

    docker compose build
