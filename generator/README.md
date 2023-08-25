# README for `tart-dsp`

For $n$ antennas, computing the visibilities requires $\frac{1}{2}n(n-1)$ multiply-accumulates per incoming set of samples from the radio frontend, with signals `Q[n-1:0], I[n-1:0]`. The each partial sum, $\Sigma_{ab}$:
\begin{align*}
  \mathcal{V}_{ab} = \Sigma_{i=1}^n Q[a][i]*Q[b][i]
\end{align*}

## Generator Configuration

The the TART DSP generator utility computes TART DSP configurations based for some given TART. Command line options are used when configuring the TART DSP, based on the number of
antennas, and the relative frequencies of the antenna source signals, vs
that of the correlators. For example, the first TART DSP used 16.384 MHz as
the sampling-rate/-clock, and the correlators operated at 12x the sampling
clock frequency, so $196.608$ MHz; i.e., $12 \times 16.384$ MHz .

*Note:* the default settings is to generate a correlator configuration that also computes the (real) signals-means for each antenna/source. Therefore the total number of correlator computations (per incoming set of sample) is $n^2 / 2$.

# Learnings

Questions:

+ Multiple banks of correlators, to simultaneously compute visibilities for multiple, narrower frequency bands?
