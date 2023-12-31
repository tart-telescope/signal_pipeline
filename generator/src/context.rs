use log::{debug, error, info, warn};
use serde::{Deserialize, Serialize};
use std::fmt;

use crate::chunked::Chunked;

/**
 * Stores the working data for partitioning the set of visibility calculations
 * amongst the available correlators.
 *
 * Each correlator unit has A- & B- inputs, and each of these has a multiplexor
 * (MUX) that selects a source from just a subset of all available antennas. The
 * maximum MUX width ('num_mux_inputs') affects performance, so this should be
 * minimised.
 *
 * The arrays of MUX inputs, 'a_mux_inputs' & 'b_mux_inputs', store the indices
 * of the antenna signals, and the 'a_mux_counts' & 'b_mux_counts' arrays store
 * the current number of inputs assigned to each MUX.
 */
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq)]
pub struct Context {
    /* Basic graph settings and properties */
    pub num_antennas: usize,
    pub clock_multiplier: usize,
    pub no_means: bool,
    pub verbose: bool,
    pub num_edges: usize,
    pub num_units: usize,
    pub mux_width: usize,

    /* Lists of edges, nodes, and their number of occurrences */
    pub edges_array: Vec<(usize, usize)>,
    pub edges_count: Vec<usize>,
    pub pairs_count: Vec<usize>,
    pub nodes_count: Vec<usize>,

    /* (Current, A- & B-) MUX assignments */
    pub a_mux_array: Chunked<usize>,
    pub b_mux_array: Chunked<usize>,
    pub means_array: Chunked<(usize, usize)>,
}

impl fmt::Display for Context {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "Context {{")?;
        writeln!(f, "    num_antennas: {}", self.num_antennas)?;
        writeln!(f, "    clock_multiplier: {}", self.clock_multiplier)?;
        writeln!(f, "    no_means: {}", self.no_means)?;
        writeln!(f, "    verbose: {}", self.verbose)?;
        writeln!(f, "    num_edges: {}", self.num_edges)?;
        writeln!(f, "    num_units: {}", self.num_units)?;
        writeln!(f, "    mux_width: {}", self.mux_width)?;

        fn from_count(prefix: &'static str, c: usize) -> String {
            if c > 0 {
                format!("{}{:2}", prefix, c)
            } else {
                " ".to_string().repeat(prefix.len() + 2)
            }
        }

        if !self.is_complete() || self.verbose {
            writeln!(f, "    edges_pairs {{")?;
            for (i, (s, d)) in self.edges_array.clone().into_iter().enumerate()
            {
                let c = from_count("count: ", self.edges_count[i]);
                let p = from_count("pairs: ", self.pairs_count[i]);
                writeln!(
                    f,
                    "        Edge: '{} -> {}'   \t(index: {:3},  {},  {})",
                    s, d, i, c, p
                )?;
            }
            writeln!(f, "    }}")?;
        }
        writeln!(f, "    nodes_count: {:?}", self.nodes_count)?;

        writeln!(f, "    mux {{")?;
        for u in 0..self.num_units {
            let x = Vec::from(&self.a_mux_array[u]);
            let s = format!("{:?}", x);
            let y = Vec::from(&self.b_mux_array[u]);
            let pads = " ".repeat(2 + (self.mux_width * 4 - s.len()) % 8);
            let tabs = "\t".repeat(1 + (self.mux_width * 4 - s.len()) / 8);
            write!(f, "        COR{}\tA:{}", u, s)?;
            writeln!(f, "{}{}B:{:?}", pads, tabs, y)?;
        }
        writeln!(f, "    }}")?;

        writeln!(f, "}}")
    }
}

impl Context {
    pub fn new(
        num_antennas: usize,
        clock_multiplier: usize,
        no_means: bool,
        extra_bits: usize,
    ) -> Self {
        let edges_array = Context::make_edges(num_antennas);
        let num_edges: usize = edges_array.len();
        let num_calcs: usize = if no_means {
            num_edges
        } else {
            (num_antennas * num_antennas) >> 1
        };
        let num_units: usize =
            (num_calcs as f64 / clock_multiplier as f64).ceil() as usize;

        // If using means, then '+1', and if fewer correlators than antennas,
        // then another '+1'?
        let mut extras: usize = if !no_means { 1 } else { 0 };
        if num_units < num_antennas {
            extras += 1;
        }
        let width0: usize =
            ((clock_multiplier + extras) as f64).sqrt().ceil() as usize;
        let width1: usize = num_antennas >> 1;
        let mux_width: usize = width1.min(width0 + extra_bits);

        Self {
            num_antennas,
            clock_multiplier,
            no_means,
            verbose: false,
            num_edges,
            num_units,
            mux_width,

            edges_array,
            edges_count: vec![0; num_edges],
            pairs_count: vec![0; num_edges],
            nodes_count: vec![0; num_antennas],

            a_mux_array: Chunked::new(mux_width, num_units),
            b_mux_array: Chunked::new(mux_width, num_units),
            means_array: Chunked::new(mux_width, num_units),
        }
    }

    // -- PRIVATE NODES FUNCTIONS -- //

    pub fn can_insert_a_node(&self, unit: usize, node: usize) -> bool {
        (self.a_mux_array[unit].contains(&node)
            || self.a_mux_array[unit].len() < self.mux_width)
            && !self.b_mux_array[unit].contains(&node)
    }

    pub fn can_insert_b_node(&self, unit: usize, node: usize) -> bool {
        (self.b_mux_array[unit].contains(&node)
            || self.b_mux_array[unit].len() < self.mux_width)
            && !self.a_mux_array[unit].contains(&node)
    }

    /**
     *  Attempts to insert the indicated A-MUX node, and then updates the edge-
     *  set if any new edges result. Then, returns the number of new edges.
     */
    fn insert_a_node(&mut self, unit: usize, node: usize) -> usize {
        let mut edges = 0;
        if !self.can_insert_a_node(unit, node) {
            return edges;
        }

        // Update all node pairs-counts due to the other MUX inputs
        for dest in self.a_mux_array[unit].iter() {
            // For each A-MUX node, increase the corresponding A-A pairs count
            let index = self.calc_edge_index(node, *dest);
            self.pairs_count[index] += 1;
        }

        self.a_mux_array.push(unit, node);
        self.nodes_count[node] += 1;

        // Compute any new edges due to the new A-MUX node
        for dest in self.b_mux_array[unit].iter() {
            // For each B-MUX node, increase the corresponding A-B edge count
            let index = self.calc_edge_index(node, *dest);
            let e_num = self.edges_count[index];

            // The edge is new, so increment the new-edge counter
            if e_num == 0 {
                edges += 1;
            }

            self.edges_count[index] += 1;
        }

        edges
    }

    /**
     *  Attempts to insert the indicated B-MUX node, and then updates the edge-
     *  set if any new edges result. Then, returns the number of new edges.
     */
    fn insert_b_node(&mut self, unit: usize, node: usize) -> usize {
        let mut edges = 0;
        if !self.can_insert_b_node(unit, node) {
            return edges;
        }

        // Update all node pairs-counts due to the other MUX inputs
        for dest in self.b_mux_array[unit].iter() {
            // For each B-MUX node, increase the corresponding B-B pairs count
            let index = self.calc_edge_index(node, *dest);
            self.pairs_count[index] += 1;
        }

        self.b_mux_array.push(unit, node);
        self.nodes_count[node] += 1;

        // Compute any new edges due to the new B-MUX node
        for dest in self.a_mux_array[unit].iter() {
            // For each A-MUX node, increase the corresponding A-B edge count
            let index = self.calc_edge_index(node, *dest);
            let e_num = self.edges_count[index];

            // The edge is new, so increment the new-edge counter
            if e_num == 0 {
                edges += 1;
            }

            self.edges_count[index] += 1;
        }

        edges
    }

    // -- PUBLIC NODES FUNCTIONS -- //

    pub fn insert_node_pair(
        &mut self,
        unit: usize,
        node_a: usize,
        node_b: usize,
    ) -> usize {
        if node_a == node_b {
            panic!("RETARTED!!");
        }
        // Insert the A-MUX node, if not present, and update edge-counts
        self.insert_a_node(unit, node_a) + self.insert_b_node(unit, node_b)
    }

    // -- PRIVATE EDGES FUNCTIONS -- //

    /**
     *  Computed by expanding out the expressions for the upper-triangular
     *  matrix coordinates to array-index.
     */
    pub fn calc_edge_index(&self, node_a: usize, node_b: usize) -> usize {
        let src = if node_a > node_b { node_b } else { node_a };
        let dst = if node_a > node_b { node_a } else { node_b };
        assert!(src < dst);

        ((src * ((self.num_antennas << 1) - 3 - src)) >> 1) + dst - 1
    }

    fn make_edges(num_antennas: usize) -> Vec<(usize, usize)> {
        let num_edges: usize = (num_antennas * (num_antennas - 1)) >> 1;
        let mut edges: Vec<(usize, usize)> =
            Vec::<(usize, usize)>::with_capacity(num_edges);

        for i in 0..num_antennas {
            for j in i + 1..num_antennas {
                edges.push((i, j));
            }
        }

        edges
    }

    // -- PUBLIC EDGES FUNCTIONS -- //

    /**
     *  Returns the number of times that the indicated edge is found within the
     *  TART DSP context.
     */
    pub fn contains_edge(&self, node_a: usize, node_b: usize) -> usize {
        let index = self.calc_edge_index(node_a, node_b);
        self.edges_count[index]
    }

    pub fn is_complete(&self) -> bool {
        self.edges_count.iter().all(|x| *x > 0)
    }

    /**
     *  Attempts to insert the A-B edge for the indicated correlator, and then
     *  returns the number of new edges (i.e., not duplicates) that were added.
     */
    pub fn insert_edge(&mut self, unit: usize, edge: usize) -> usize {
        let (mut node_a, mut node_b) = self.edges_array[edge];

        // Determine the required A- & B- nodes for the edge
        if self.a_mux_array[unit].contains(&node_b) {
            if self.b_mux_array[unit].contains(&node_a) {
                // Already present, so zero new edges
                return 0;
            } else {
                (node_a, node_b) = (node_b, node_a); // SWAP
            }
        } else if self.b_mux_array[unit].contains(&node_a) {
            (node_a, node_b) = (node_b, node_a); // SWAP
        }

        self.insert_node_pair(unit, node_a, node_b)
    }

    // -- MORE PRIVATE PARTS -- //

    /**
     *  Allocates to each correlator the per-antenna autocorrelation nodes, as
     *  these are used to compute the average signal-level over the integration
     *  period.
     *
     *  Note: means are placed first, so resets the given context before
     *    placing any MUX inputs, for the means calculations.
     */
    fn place_means(&mut self) -> usize {
        let mut unit = 0;
        let mut node = 0;
        let mut edges = 0;

        debug!("Clearing any current edge & mean assignments.");
        // std::process::exit(1);
        self.reset();

        while node < self.num_antennas {
            // Handle the case where we need multiple passes, over each of the
            // correlators, to place all of the sources/antennas/nodes.
            if unit >= self.num_units {
                unit = 0;
            }

            let temp = node + 1;
            if temp >= self.num_antennas {
                // Only insert just the 'A' node, and update the edge-set
                edges += self.insert_a_node(unit, node);
                // self.means_array.push(unit, (node, usize::MAX));
            } else {
                edges += self.insert_node_pair(unit, node, temp);
                // self.means_array.push(unit, (node, temp));
            }

            unit += 1;
            node += 2;
        }

        edges
    }

    // -- PUBLIC PARTS -- //

    pub fn num_nodes_at(&self, unit: usize) -> usize {
        self.a_mux_array[unit].len() + self.b_mux_array[unit].len()
    }

    pub fn get_mux_width(&self) -> usize {
        self.mux_width
    }

    pub fn get_num_antennas(&self) -> usize {
        self.num_antennas
    }

    pub fn get_clock_multiplier(&self) -> usize {
        self.clock_multiplier
    }

    pub fn get_num_units(&self) -> usize {
        self.num_units
    }

    /**
     *  Global score for the given node, where large counts for edges, pairs,
     *  and nodes, lowers the priority for it to be considered for placement.
     */
    fn node_score(&self, node: usize) -> (usize, usize, usize) {
        let mut edge_score = 0;
        let mut pair_score = 0;
        let mut index = 0;

        for i in 0..self.num_antennas {
            for j in i + 1..self.num_antennas {
                if i == node || j == node {
                    edge_score += self.edges_count[index];
                    pair_score += self.pairs_count[index];
                }

                index += 1;
            }
        }

        (edge_score, pair_score, self.nodes_count[node])
    }

    /**
     *  Compute the A-MUX score for the indicated node. The number of new edges
     *  that it will contribute to is good. Repetitions of edges, pairs, and
     *  nodes count against it.
     */
    fn a_mux_score(&self, unit: usize, node: usize) -> (usize, usize, usize) {
        // Can not insert into both A- & B- MUXs, or already in A-MUX
        if self.b_mux_array[unit].contains(&node)
            || self.a_mux_array[unit].contains(&node)
        {
            return (usize::MAX, usize::MAX, usize::MAX);
        }

        // To start with, compute the global score
        let (edges, pairs, nodes) = self.node_score(node);
        let mut edge_score = 0;
        let mut dups_score = edges + pairs;

        // Update the edge-score due to insertion of 'node'
        for r in self.b_mux_array[unit].iter() {
            let e = self.calc_edge_index(node, *r);
            if self.edges_count[e] > 0 {
                edge_score += 1;
                dups_score += self.edges_count[e] + 1;
            }
        }

        // Update the pair-score due to insertion of 'node'
        for r in self.a_mux_array[unit].iter() {
            let e = self.calc_edge_index(node, *r);
            dups_score += self.pairs_count[e] + 1;
        }

        (edge_score, dups_score, nodes + 1)
    }

    fn b_mux_score(&self, unit: usize, node: usize) -> (usize, usize, usize) {
        // Can not insert into both A- & B- MUXs, or already in B-MUX
        if self.a_mux_array[unit].contains(&node)
            || self.b_mux_array[unit].contains(&node)
        {
            return (usize::MAX, usize::MAX, usize::MAX);
        }

        // To start with, compute the global score
        let (edges, pairs, nodes) = self.node_score(node);
        let mut edge_score = 0;
        let mut dups_score = edges + pairs;

        // Update the edge-score due to insertion of 'node'
        for r in self.a_mux_array[unit].iter() {
            let e = self.calc_edge_index(node, *r);
            if self.edges_count[e] > 0 {
                edge_score += 1;
                dups_score += self.edges_count[e] + 1;
            }
        }

        // Update the pair-score due to insertion of 'node'
        for r in self.b_mux_array[unit].iter() {
            let e = self.calc_edge_index(node, *r);
            dups_score += self.pairs_count[e] + 1;
        }

        (edge_score, dups_score, nodes + 1)
    }

    fn place_a_mux(&mut self, unit: usize) -> &mut Self {
        let mut scores: Vec<((usize, usize, usize), usize)> =
            Vec::with_capacity(self.num_antennas);

        for i in 0..self.num_antennas {
            scores.push((self.a_mux_score(unit, i), i));
        }

        scores.sort_unstable();
        self.insert_a_node(unit, scores[0].1);
        self
    }

    fn place_b_mux(&mut self, unit: usize) -> &mut Self {
        let mut scores: Vec<((usize, usize, usize), usize)> =
            Vec::with_capacity(self.num_antennas);

        for i in 0..self.num_antennas {
            // todo: why is this different to the above version (for A)?
            let score = self.b_mux_score(unit, i);
            if score.0 == usize::MAX || score.1 == usize::MAX {
                continue;
            }
            scores.push((score, i));
        }

        scores.sort_unstable();
        self.insert_b_node(unit, scores[0].1);
        self
    }

    pub fn fill_unit(&mut self, unit: usize) {
        while self.num_nodes_at(unit) < 2 * self.mux_width {
            // Add node to the emptiest MUX
            let mux_b: bool =
                self.a_mux_array[unit].len() > self.b_mux_array[unit].len();

            if mux_b {
                self.place_b_mux(unit);
            } else {
                self.place_a_mux(unit);
            }
        }
    }

    fn calc_mux_score(&self, a_mux: Vec<usize>, b_mux: Vec<usize>) -> usize {
        let mut score = 0;
        for a in a_mux.iter() {
            for o in a_mux.iter() {
                if *o > *a {
                    score += self.pairs_count[self.calc_edge_index(*a, *o)] - 1;
                }
            }
            for b in b_mux.iter() {
                let e = self.calc_edge_index(*a, *b);
                score += self.edges_count[e] - 1;
            }
            score += self.nodes_count[*a] - 1;
        }
        for b in b_mux.iter() {
            for o in b_mux.iter() {
                if *o > *b {
                    score += self.pairs_count[self.calc_edge_index(*b, *o)] - 1;
                }
            }
            score += self.nodes_count[*b] - 1;
        }
        score
    }

    fn improve_unit_score(&self, unit: usize) -> usize {
        let a_mux: Vec<usize> = self.a_mux_array[unit].to_vec();
        let b_mux: Vec<usize> = self.b_mux_array[unit].to_vec();
        self.calc_mux_score(a_mux, b_mux)
    }

    pub fn unit_scores(&self) {
        let mut scores = Vec::new();
        for u in 0..self.num_units {
            scores.push(self.improve_unit_score(u));
        }
        info!("Scores: {:?}", scores);
    }

    /**
     *  Clear all current node, edge, and MUX assignments.
     */
    pub fn reset(&mut self) {
        self.edges_count.fill(0);
        self.nodes_count.fill(0);
        self.pairs_count.fill(0);

        self.a_mux_array.reset();
        self.b_mux_array.reset();
    }

    /**
     *  Sorts the nodes-order for each MUX, if each set of MUX inputs is full.
     */
    pub fn sort_inputs(&mut self) {
        self.a_mux_array.sort_chunks();
        self.b_mux_array.sort_chunks();
    }

    pub fn replace(&mut self, unit: usize, curr: usize, next: usize) {
        let mut index = 0;

        if self.a_mux_array[unit].contains(&curr) {
            for (i, r) in self.a_mux_array[unit].iter().enumerate() {
                if *r == curr {
                    index = i;
                    for j in self.b_mux_array[unit].iter() {
                        let e = self.calc_edge_index(curr, *j);
                        self.edges_count[e] -= 1;
                        let e = self.calc_edge_index(next, *j);
                        self.edges_count[e] += 1;
                    }
                    self.nodes_count[curr] -= 1;
                    self.nodes_count[next] += 1;
                } else {
                    let e = self.calc_edge_index(curr, *r);
                    self.pairs_count[e] -= 1;
                    let e = self.calc_edge_index(next, *r);
                    self.pairs_count[e] += 1;
                }
            }
            self.a_mux_array[unit][index] = next;
        } else if self.b_mux_array[unit].contains(&curr) {
            for (i, r) in self.b_mux_array[unit].iter().enumerate() {
                if *r == curr {
                    index = i;
                    for j in self.a_mux_array[unit].iter() {
                        let e = self.calc_edge_index(curr, *j);
                        self.edges_count[e] -= 1;
                        let e = self.calc_edge_index(next, *j);
                        self.edges_count[e] += 1;
                    }
                    self.nodes_count[curr] -= 1;
                    self.nodes_count[next] += 1;
                } else {
                    let e = self.calc_edge_index(curr, *r);
                    self.pairs_count[e] -= 1;
                    let e = self.calc_edge_index(next, *r);
                    self.pairs_count[e] += 1;
                }
            }
            self.b_mux_array[unit][index] = next;
        }
    }

    /// TODO:
    pub fn replace_score(
        &self,
        unit: usize,
        node: usize,
        _next: usize,
    ) -> usize {
        // Compute score for removing an unnecessary node
        let score = if self.a_mux_array[unit].contains(&node) {
            // todo: score of zero if any edges_count is less than two
            Vec::from(&self.b_mux_array[unit])
                .iter()
                .map(|b| {
                    let e = self.calc_edge_index(node, *b);
                    self.edges_count[e] + self.pairs_count[e]
                })
                .sum::<usize>()
                + self.nodes_count[node]
        } else if self.b_mux_array[unit].contains(&node) {
            Vec::from(&self.a_mux_array[unit])
                .iter()
                .map(|a| {
                    let e = self.calc_edge_index(node, *a);
                    self.edges_count[e] + self.pairs_count[e]
                })
                .sum::<usize>()
                + self.nodes_count[node]
        } else {
            0
        };

        // Compute score for inserting the new node

        score
    }

    pub fn find_unneeded(&self) -> Chunked<usize> {
        let mut unneeded =
            Chunked::<usize>::new(self.mux_width << 1, self.num_units);

        for u in 0..self.num_units {
            for a in self.a_mux_array[u].iter() {
                if Vec::from(&self.b_mux_array[u])
                    .iter()
                    .all(|b| self.edges_count[self.calc_edge_index(*a, *b)] > 1)
                {
                    unneeded.push(u, *a);
                }
            }

            for b in self.b_mux_array[u].iter() {
                if Vec::from(&self.a_mux_array[u])
                    .iter()
                    .all(|a| self.edges_count[self.calc_edge_index(*a, *b)] > 1)
                {
                    unneeded.push(u, *b);
                }
            }
        }

        unneeded
    }

    /**
     *  Computes the list of edges by (ascending) edge-frequency.
     */
    pub fn sorted_edges(&self) -> Vec<usize> {
        let mut perm: Vec<usize> = (0..self.num_edges).collect();
        perm.sort_by_key(|p| self.edges_count[*p]);
        perm
    }

    /**
     *  Computes the set of correlator units that contains each edge.
     *
     *  The returned data is the same as that used by Compressed Row/Col Sparse
     *  (CRS/CCS) matrices, for their index data.
     */
    pub fn find_edge_units(&self) -> (Vec<usize>, Vec<usize>) {
        let mut colptrs: Vec<usize> = vec![0; self.num_edges + 1];
        for (i, c) in self.edges_count.iter().enumerate() {
            if i >= self.num_edges - 1 {
                break;
            }
            let x = colptrs[i + 1];
            colptrs[i + 2] = x + c;
        }

        let length: usize = self.edges_count.iter().sum();
        let mut indices: Vec<usize> = vec![0; length];

        for unit in 0..self.num_units {
            for i in self.a_mux_array[unit].iter() {
                for j in self.b_mux_array[unit].iter() {
                    let k = self.calc_edge_index(*i, *j);
                    let p = colptrs[k + 1];
                    indices[p] = unit;
                    colptrs[k + 1] = p + 1;
                }
            }
        }

        (colptrs, indices)
    }

    /**
     *  Assigns edges to each correlator, in order of least-frequent to most-
     *  frequent edges.
     *
     *  Note: When more than one correlator unit can be chosen, choose the
     *    least-populated correlator. This heuristic is vulnerable to certain
     *    edge-cases, but so far seems to perform well enough.
     */
    pub fn assign_edges(&mut self, cont: bool) -> Option<Chunked<usize>> {
        let ranks = self.sorted_edges();
        if self.edges_count[ranks[0]] == 0 {
            error!("Not all edges have been covered!");
            let mut i = 0;
            let mut missing: Vec<String> = Vec::new();
            while self.edges_count[ranks[i]] == 0 {
                let (a, b) = self.edges_array[ranks[i]];
                missing.push(format!("{} -> {}", a, b));
                i += 1;
            }
            let edges = missing.join(", ");
            error!("Missing: {}  (num = {})", edges, i);
            return None;
        }

        let mut units: Chunked<usize> =
            Chunked::new(self.clock_multiplier, self.num_units);
        let (ptrs, idxs) = self.find_edge_units();

        for k in ranks.into_iter() {
            let c = self.edges_count[k];
            let p = ptrs[k];

            let u = if c == 1 {
                // Edge has to be assigned to the only unit containing it
                idxs[p]
            } else {
                // Figure out the best unit to assign the edge to
                let us: Vec<usize> = (idxs[p..p + c]).to_vec();
                let mut qs: Vec<usize> = (0..us.len()).collect();
                qs.sort_by_key(|&k| {
                    units.count(us[k]) + self.means_array.count(us[k])
                });

                // todo: compute some form of "score" for the edge-insertion,
                //   based on the edges already assigned, and those remaining.
                // let (a, b) = self.edges_array[k];
                us[qs[0]]
            };
            if units.count(u) + self.means_array.count(u)
                < self.clock_multiplier
                && units.can_push(u, k)
            {
                units.push(u, k);
            } else if !cont {
                error!("No solution, as there is no free correlator!\n");
                return None;
            } else {
                let (a, b) = self.edges_array[k];
                warn!("Failed to route edge: {} -> {}", a, b);
            }
        }

        Some(units)
    }

    /**
     *  Partition the set of edges amongst the correlators.
     *
     *  Algorithm:
     *   1) place the auto-correlation nodes;
     *   2) find the least-occupied correlator, 'c';
     *   3) for 'c', calculate the "best" unassigned edge to insert into it;
     *   4) until all edges have been assigned, GOTO 2); and
     *   5) return the partitioning results.
     *
     */
    pub fn partition(&mut self, verbose: bool) {
        self.verbose = verbose;
        if !self.no_means {
            self.place_means();
            // println!("{}", self);
        } else if verbose {
            info!("Skipping means ...");
        }

        // Filling both input MUXs of each correlator unit.
        for i in 0..self.num_units {
            self.fill_unit(i);
        }

        // Sort (ascending) the MUX inputs.
        self.sort_inputs();
    }
}
