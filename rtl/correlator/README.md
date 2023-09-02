# README for the TART Correlator

## Theory of Operation

Accumumates `COUNT` samples from each antenna, in order to efficiently batch-compute partially-summed visibilities. These are then forwarded onto a wider accumulator, to compute the sum of the desired number of cross-correlations.

## Truth Table for the Correlator

For the calculation of $v_{ab}$, for antenna sources $Z_a, Z_b$:
\begin{align*}
  Z_a & = I_a + j\,Q_a \, , &
  Z_b & = I_b + j\,Q_b \, , & \\
  v_{ab} & = Z_a \cdot Z_b^* = \mathcal{R}_{ab} + j\,\mathcal{I}_{ab} \, , & \\
  \mathcal{R}_{ab} & \equiv I_a \cdot I_b + Q_a \cdot Q_b \, , &
  \mathcal{I}_{ab} & \equiv Q_a \cdot I_b - I_a \cdot Q_b \, . &
\end{align*}
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
