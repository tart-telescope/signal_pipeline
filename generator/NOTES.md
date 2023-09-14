---
title: "*Notes for Assigning TART DSP Pairs*"
author:
 - Patrick Suggate
 - Tim Molteno
date: 18^th^ August, 2023
geometry: margin=2cm
papersize: a4
fontsize: 11pt
colorlinks: true
---

# TART DSP Pairs

For $n$ antennas, computing the visibilities requires $\frac{1}{2}n(n-1)$ multiply-accumulates per incoming set of samples from the radio frontend, with $n$ complex signals, `Z[n-1:0]`, so with real components, `Q[n-1:0]`, and imaginary components, `I[n-1:0]`. The visibilities are computed over some time-interval, $T = [t_0, t_1] \subset \mathbb{R}, 0 \le t_0 < t_1, (t_0, t_1) \in \mathbb{R} \times \mathbb{R}$, consisting of partial sums, $\Sigma_{ab}$, of products of samples (discretized values taken at regular intervals within $T$, with constant spacing, $\Delta t$). The visibilities are thus:
\begin{align*}
  \mathcal{V}_{ab} & = \sum_{k=1}^N Z_a(t_k) \cdot \bar{Z}_b(t_k) \, , &
  \mathcal{V}_{ba} & = \sum_{k=1}^N Z_b(t_k) \cdot \bar{Z}_a(t_k) =
  \sum_{k=1}^N \overline{Z_a(t_k) \cdot \bar{Z}_b(t_k)} =
  \bar{\mathcal{V}}_{ab} \, , &
\end{align*}
for antennas $a, b$, where $k$ is the time-series index, of which there are $N$ samples.

Beliefs about solutions:

+ The number of repetitions of each node, edge, and pair is close to uniform, and the mean of each is close to the minimum possible

+ For realistic solutions^[A "realistic" solution has a large number of correlators, exceeding the number of antennas.], a node does not need to be placed within both the A-MUX and B-MUX of the same correlator unit.

+ Not all pairs need to be accounted for; e.g., the default 8 antennas, 12x multiplier solutions.

+ Given a $K_{w,w}$ biclique cover-ish^[A true biclique cover does not necessarily have fixed-size bicliques, and each edge of the original graph should only be found once in the biclique cover. Also, graphs typically do not have the self-loop edges that we have, due to the signal-means calculations.], where $w \in \mathbb{N}$ is the input *"MUX width"* for each correlator, for the visibilities calculation, edges can be pruned from this set of bicliques to yield a bipartite cover-ish of the calculation -- without requiring extra correlator units?

Figures of merit:

+ smallest edge score?

+ smallest pair score?

+ smallest node score?

What is the relative importance of each of these?

Todo:

+ after a solution is found, re-arrange correlators and edges, so that all valid calculations precede the "idle" calculations?

## Definitions

A **pair** is a pair of nodes that occurs within the same MUX (both in A or both in B, and belonging to any correlator). To compute a contribution to a visibility, a (complex) product is formed from an A input, and a B input. So pairs do not count towards the computations available to a correlator unit.

A **unit** is a correlator/visibility function unit, of the TART DSP hardware.

## Bounds

The number of visibilites, $n_v \in \mathbb{N}$, for $n \in \mathbb{N}$ antennas/sources, $\{ z_i \,|\, z_i \in \mathbb{C}, |z_i|^2 \le 1, \, 0 \le i < n \}$, and the total number of visibilities plus *signal means*, $\bar{z}_i$, are given by:
\begin{align*}
  n_v & \equiv \frac{n(n-1)}{2} , &
  n_{\operatorname{total}} & \equiv \frac{n^2}{2} . &
\end{align*}

For a some A-/B- MUX, $\operatorname{MUX}_i$, with width of $w$, each pair of nodes, $(a, b) \in \operatorname{nodes}\{ \operatorname{MUX}_i \}$, there must be some other correlator where this pair of nodes each belong in opposing MUXs -- one in the A-MUX, the other in the B-MUX.

The greater the number of occurences of node-pairs, the greater the required repetitions of each node.

Minimum repetitions for each antenna source, $r_{\min} \in \mathbb{N}$, within the input (A- & B-) MUXs is:
\begin{align*}
  r_{\min} & \equiv \left\lceil (n - 1) / w \right\rceil , &
  r_{\min} & \equiv \left( \begin{array}{c} w \\ 2 \end{array} \right) , &
\end{align*}
where:

+ $n \in \mathbb{N}$ is the number of antennas/sources; and

+ $w \in \mathbb{N}$ is the number of inputs to each MUX.

The minimum number of correlators, $c_{\min} \in \mathbb{N}$, is the maximum of either:
\begin{align*}
  c_{\min} \equiv \mathcal{O} \left( \max \left\{
    \left\lceil \frac{r_{\min} \, n}{2\,w} \right\rceil \, ,
    \left\lceil
      \frac{f_{\operatorname{source}} \cdot n^2}{2\,f_{\operatorname{correlator}}}
    \right\rceil
    \right\} \right) ,
\end{align*}
because either the MUX width, $w$ (because each source is repeated at least $r_{\min}$ times, filling up one input of one of the two input MUXs), or the correlator operating frequency, $f_{\operatorname{correlator}}$ (in Hz), will determine the minimum number of correlators.

## Outputs

Need:

+ permutation vector

+ per-correlator *"taps"* from the full set of antenna signals, to each MUX

+ MUX '`sel`' values for each time-slice

+ auto-correlation flags

\clearpage

# Graph Theory

A **matching** (or, **independent edge set**) in an undirected graph is a set of edges without common vertices.
