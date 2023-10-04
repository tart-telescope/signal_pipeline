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

## Truth Table for the Correlator

For the calculation of $v_{ab}$, for antenna sources $Z_a, Z_b$:
\begin{eqnarray*}
  Z_a & = & I_a + j\,Q_a \\
  Z_b & = & I_b + j\,Q_b \\
  v_{ab} & = & Z_a \cdot Z_b^* = \mathcal{R}_{ab} + j \mathcal{I}_{ab} \\
  \mathcal{R}_{ab}  &  \equiv & I_a \cdot I_b + Q_a \cdot Q_b \\
  \mathcal{I}_{ab} & \equiv & Q_a \cdot I_b - I_a \cdot Q_b \
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
