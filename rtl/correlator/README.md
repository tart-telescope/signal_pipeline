# README for the TART Correlator

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

| $I_a$ | $Q_a$ | $I_b$ | $Q_b$ |   | $\mathcal{R}_{ab}$ |            | $\mathcal{I}_{ab}$ |   |
|:-----:|:-----:|:-----:|:-----:|---|:------------------:|:----------:|:------------------:|:-:|
| 0 | 0 | 0 | 0 | |  2 | 0b010  |  0 | 0b000  |
| 0 | 0 | 0 | 1 | |  0 | 0b000  |  2 | 0b010  |
| 0 | 0 | 1 | 0 | |  0 | 0b000  | -2 | 0b110  |
| 0 | 0 | 1 | 1 | | -2 | 0b110  |  0 | 0b000  |
| 0 | 1 | 0 | 0 | |  0 | 0b000  | -2 | 0b110  |
| 0 | 1 | 0 | 1 | |  2 | 0b010  |  0 | 0b000  |
| 0 | 1 | 1 | 0 | | -2 | 0b110  |  0 | 0b000  |
| 0 | 1 | 1 | 1 | |  0 | 0b000  |  2 | 0b010  |
| 1 | 0 | 0 | 0 | |  0 | 0b000  |  2 | 0b010  |
| 1 | 0 | 0 | 1 | | -2 | 0b110  |  0 | 0b000  |
| 1 | 0 | 1 | 0 | |  2 | 0b010  |  0 | 0b000  |
| 1 | 0 | 1 | 1 | |  0 | 0b000  | -2 | 0b110  |
| 1 | 1 | 0 | 0 | | -2 | 0b110  |  0 | 0b000  |
| 1 | 1 | 0 | 1 | |  0 | 0b000  | -2 | 0b110  |
| 1 | 1 | 1 | 0 | |  0 | 0b000  |  2 | 0b010  |
| 1 | 1 | 1 | 1 | |  2 | 0b010  |  0 | 0b000  |

where the $\mathcal{R,I}$ columns also include 3-bit, twos-complement values.
