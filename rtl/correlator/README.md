---
title: "*Overview and Design Notes for the Correlator Core*"
author:
 - Patrick Suggate
 - Timothy Molteno
date: 8^th^ September, 2023
pagesize: a4
geometry: margin:2cm
fontsize: 11pt
colorlinks: true
---

# README for the TART Correlator

Pseudocode:
```rust
for i in 0..TRATE {
  // Select the timeseries (arrays) for the subsequent correlations
  let ai = i[muxa[i]];
  let aq = q[muxa[i]];
  let bi = i[muxa[i]];
  let bq = q[muxa[i]];
  
  // Accumulate in two stages, and forward partial-sums to the accumulator
  for j in 0..COUNT[1] {
    let mut vr = 0;
    let mut vi = 0;
    
    for k in 0..COUNT[0] {
      let l = j*COUNT[0] + k;
      vr += ai[l] * bi[l] + aq[l] * bq[l];
      vi += aq[l] * bi[l] - ai[l] * bq[l];
    }
    out.send((vr, vi))?;
  }
}
```
demonstrating the order that the antenna signals are read out of the buffer SRAMs.

![Diagram](../../doc/diagrams/tart_correlator.pdf "salad")

## Theory of Operation

Accumumates `COUNT` samples from each antenna, in order to efficiently batch-compute partially-summed visibilities. These are then forwarded onto a wider accumulator, to compute the sum of the desired number of cross-correlations.

## Truth Table for the Correlator {#sec:vis-calc}

For the calculation of $v_{ab}$, for antenna sources $Z_a, Z_b$:
\begin{eqnarray*}
  Z_a & = & I_a + j\,Q_a \\
  Z_b & = & I_b + j\,Q_b \\
  v_{ab} & = & Z_a \cdot Z_b^* = \mathcal{R}_{ab} + j \mathcal{I}_{ab} \\
  \mathcal{R}_{ab}  &  \equiv & I_a \cdot I_b + Q_a \cdot Q_b \\
  \mathcal{I}_{ab} & \equiv & Q_a \cdot I_b - I_a \cdot Q_b 
\end{eqnarray*}
For 1-bit signals, we have the following truth-table:

| $I_a$ | $Q_a$ | $I_b$ | $Q_b$ |   | $\mathcal{R}_{ab}$ |    | $\mathcal{I}_{ab}$ |    |
|:-----:|:-----:|:-----:|:-----:|---|:------------------:|:--:|:------------------:|:--:|
| 0     | 0     | 0     | 0     |   | 0b010              | 2  | 0b000              | 0  |
| 0     | 0     | 0     | 1     |   | 0b000              | 0  | 0b010              | 2  |
| 0     | 0     | 1     | 0     |   | 0b000              | 0  | 0b110              | -2 |
| 0     | 0     | 1     | 1     |   | 0b110              | -2 | 0b000              | 0  |
| 0     | 1     | 0     | 0     |   | 0b000              | 0  | 0b110              | -2 |
| 0     | 1     | 0     | 1     |   | 0b010              | 2  | 0b000              | 0  |
| 0     | 1     | 1     | 0     |   | 0b110              | -2 | 0b000              | 0  |
| 0     | 1     | 1     | 1     |   | 0b000              | 0  | 0b010              | 2  |
| 1     | 0     | 0     | 0     |   | 0b000              | 0  | 0b010              | 2  |
| 1     | 0     | 0     | 1     |   | 0b110              | -2 | 0b000              | 0  |
| 1     | 0     | 1     | 0     |   | 0b010              | 2  | 0b000              | 0  |
| 1     | 0     | 1     | 1     |   | 0b000              | 0  | 0b110              | -2 |
| 1     | 1     | 0     | 0     |   | 0b110              | -2 | 0b000              | 0  |
| 1     | 1     | 0     | 1     |   | 0b000              | 0  | 0b110              | -2 |
| 1     | 1     | 1     | 0     |   | 0b000              | 0  | 0b010              | 2  |
| 1     | 1     | 1     | 1     |   | 0b010              | 2  | 0b000              | 0  |

where the $\mathcal{R,I}$ columns include 3-bit, twos-complement (binary) values, as well as base-10.

Todo:

1. Instead of using two's-complement, just add two to each value (and account for it at the end)?

## Partial-Sum Output Chain (PSOC)

Every `COUNT` cycles, each correlator unit produces a complex, partially-summed visibility. Accumulating each of these requires two additions (one each for the real and imaginary components), and these are full-width accumulators (for the two-stage-accumulator designs). Therefore, `CORES` correlator units requires `2*CORES` additions every `COUNT` cycles.

\pagebreak

# Functional Units

Modules:

- [Radio-signal buffer](#sec:sig-buf) and read-back SRAMs
- [Signal-source multiplexors](#sec:sig-mux) that feed into the correlator-blocks
- [Correlator blocks](#sec:correlate) that perform the initial (partial-) visibility computations, for each radio-pair
- [Partial-accumulators](#sec:vis-acc) that chain together, to compute and distribute intermediate sums for each visibility computation
- [Final accumulator](#sec:fin-acc) that produces visibilities for each radio-pair
- [Output buffer SRAMs](#sec:out-buf), connected to the system bus, for transmission to the host

## Signal Buffer {#sec:sig-buf}

**Synopsis:** *Buffers incoming IQ data from the radios, using two banks and bank-switching as each bank fills up, while streaming out radio-data at a higher clock-rate, to the correlators.*

Module:

- Source file(s): `sigbuffer.v`
- Clock domain(s): signal and correlator domains (synchronous with the signal clock-domain)
- Parameter(s):
  + `WIDTH` -- number of radios
  + `TRATE` -- clock ratio for correlator frequency to signal frequency
  + `LOOP0` -- inner-loop counter
  + `LOOP1` -- outer-loop counter

Description:

- One samples-buffer is recording samples (radio-signal capture frequency), while the other samples-buffer is emitting stored samples (at `TRATE` times the radio frequency) to downstream cores.
- Output data is produced at `TRATE` times the radio-signal source frequency.
- Each bank of data contains `LOOP0 * LOOP1` radio-signal samples.
- Therefore, each set of (`LOOP0 * LOOP1`) samples is repeated `TRATE` times, as each `correlate` core implements `TRATE` time-multiplexing.
- After each set of (`LOOP0 * LOOP1`) samples has been iterated over, MUX-selects are changed in the downstream `sigsource` core (see Subsection \ref{sec:sig-mux}), until `TRATE` iterations, and then the samples-buffers are switched.

Notes:

- Values of `LOOP0` and `LOOP` should be chosen such that the adder-resources required are minimal, and that correlators can be tiled, and connected, in a manner to maximise the sharing of adder resources in subsequent accumulator stages/cores.

## Correlator Input Multiplexor {#sec:sig-mux}

**Synopsis:** *Multiplexes radio-signal input pairs for the correlator, switching sources for each time-slice.*

Module:

- Source file(s): `sigsource.v`
- Clock domain(s): correlator clock domain
- Parameter(s):
  + `WIDTH` -- number of radios
  + `MUX_N` -- number of inputs for each signal-source MUX
  + `TRATE` -- clock ratio for correlator frequency to signal frequency
  + `ATAPS`, `BTAPS` -- radio channel index for each A/B MUX inputs
  + `ASELS`, `BSELS` -- MUX -selects/-indices for each A/B MUX

Description:

- During the first cycle of every `LOOP0` iterations, strobes `next`, which indicates to the attached `correlate` core that it is starting a new partial-calculation.
- During the last cycle of every `LOOP0` iterations, strobes `last`, which indicates to the `correlate` core that it should place the current partial-calculation onto the accumulator-bus.

## Correlator (1st Stage) {#sec:correlate}

**Synopsis:** *Correlates radio-source pairs, accumulating the product using a narrow accumulator, and streaming out partial-sums before the accumulator overflows.*

Module:

- Source file(s): `correlate.v`
- Clock domain(s): correlator clock domain
- Parameter(s):
  + `WIDTH` -- number of radios

Description:

- Performs single-steps of the calculation outlined in Subsection \ref{sec:vis-calc}.
- OR, if the `auto` input is asserted, then the `correlate` instance just counts the number of ones, for each input, and this is used to check that the radio sources have zero-means.
- Begins a new partial-calculation whenever `next` is asserted.
- Outputs current partial-calculation whenever `last` is asserted.
- Normally the outputs are pushed onto a linear `vismerge` chain, where these partial computations are accumulated into wider sums.

## Visibilities Accumulators {#sec:vis-acc}

**Synopsis:** *Accumulates narrower partial-sums into wider partial-sums, and streaming out these wider sums periodically, to avoid accumulator overflows.*

Module:

- Source file(s): `vismerge.v`, `visaccum.v`, and `visfinal.v`
- Clock domain(s): correlator clock domain
- Parameter(s):
  + `IBITS` -- input (partial-sum) bit-width
  + `OBITS` -- output (partial-sum) bit-width, and accumulator bit-width
  + `PSUMS` -- number of partial-sums in the `vismerge` input-chain
  + `COUNT` -- number of input partial-sums to accumulate (for each partial-visibility), before producing each output

Description:

- Every `PSUMS` iterations (which has to be at least as large as `LOOP0`, or else values will be lost), an attached `correlate` core pushes a partial-visibility onto `vismerge` chain, and these are linearly-clocked until they reach a `visaccum` core.
- A `vismerge` instance is essentially a pipeline register and an input MUX, so that multiple `correlate` outputs can be fed into a `vismerge` chain, which ends at a `visaccum` instance.
- The `visaccum` core accumulates the input from its `vismerge` input-chain with its corresponding partial-visibility (stored in a local SRAM).
- After `COUNT` contributions, a `visaccum` core outputs each of the partial-visibility results, to be passed to the final accumulator (see Subsection \ref{sec:fin-acc}).
- Inputs from multiple `visaccum` instances, via another (wider) `vismerge` chain, are accumulated within a `visfinal` instance, producing interleaved $\mathcal{R}$ and $\mathcal{I}$ components of the visibility computations.
- A `visfinal` instance contains just one SRAM for interleaved Re and Im components of the partial-visibilities.

Notes:

- These can be connected as trees of chains, so that as accumulators get wider they also manage an increasingly larger set of partial-visibilities, so that fewer wider accumulators are required.

## Alternate Final Accumulator {#sec:fin-acc}

**Synopsis:** *Final accumulator for the visibilities computations, with a single adder being time-shared by many radio-pair visibility results.*

Module:

- Source file(s): `accumulator.v`
- Clock domain(s): correlator clock domain
- Parameter(s):
  + `CORES` -- number of correlators in the `vismerge` input-chain
  + `TRATE` -- number of (time-multiplexed) antenna-pairs from each source correlator
  + `WDITH` -- final accumulator bit-width
  + `SBITS` -- bit-widths of the input partial-visibilities

Description:

- Alternative to `visfinal`, for when interleaved $\mathcal{R}$ and $\mathcal{I}$ components are not desired.
- Accumulates all of the partial-sums, for each visibility calculation, until the desired correlation-time has been reached, as determined by the value of the input-port, `count_i` (times the integration-time represented by the input sources).

## Output Buffer {#sec:out-buf}

**Synopsis:** *Multi-bank SRAM buffer, for visibilities read-back, by the host computer.*

Module:

- Source file(s): `axis_afifo.v`
- Clock domain(s): correlator clock domain, and chip bus-clock domains
- Parameter(s):
  + `WIDTH` -- visibility bit-width (per $\mathcal{R}$- and $\mathcal{I}$- component)
  + `ABITS` -- FIFO pointer-bits, so the FIFO size is `1 << ABITS` entries

Description:

- As the accumulator finishes each antenna-pair visibility calculation, this core stores that result in one of the output-buffer SRAM banks.
- Multiple banks, and bank-switches when each set of visibilities has been computed.

\pagebreak

# Appendix A: Example TART Configurations

### Example: Four Radios

Correlator parameters:

- `parameter TRATE = 8`{.v} -- 1x correlator ??
- `parameter LOOP0 = 3`{.v} -- 4-bit adder ??
- `parameter LOOP1 = 5`{.v} -- 7-bit adder ??
- `parameter WIDTH = 32`{.v} -- 32-bit final accumulator ??

Pairs:
```
  {(0,1), (0,2), (0,3), (1,2), (1,3), (2,3), (0*,1*), (2*,3*)}
```
where the final two pairs are for the signal-means calculations.

### Example: 24 Radios

Correlator parameters:

- `parameter TRATE = 12`{.v} -- 24 correlators ??
- `parameter LOOP0 = 3`{.v} -- 5-bit adder ??
- `parameter LOOP1 = 5`{.v} -- 8-bit adder ??
- `parameter WIDTH = 32`{.v} -- final accumulator ??

Perhaps?
