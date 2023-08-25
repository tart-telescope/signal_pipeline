use crate::chunked::Chunked;
use std::fmt;

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
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Context {
    /* Basic graph settings and properties */
    num_antennas: usize,
    clock_multiplier: usize,
    no_means: bool,
    verbose: bool,
    num_edges: usize,
    num_units: usize,
    mux_width: usize,

    /* Lists of edges, nodes, and their number of occurrences */
    edges_array: Vec<(usize, usize)>,
    edges_count: Vec<usize>,
    pairs_count: Vec<usize>,
    nodes_count: Vec<usize>,

    /* (Current, A- & B-) MUX assignments */
    a_mux_array: Chunked<usize>,
    b_mux_array: Chunked<usize>,

    a_mux_count: Vec<usize>,
    a_mux_nodes: Vec<usize>,
    b_mux_count: Vec<usize>,
    b_mux_nodes: Vec<usize>,
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
            for (i, (s, d)) in self.edges_array.clone().into_iter().enumerate() {
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
        for i in 0..self.num_units {
            let b = i * self.mux_width;
            let x = Vec::from(&self.a_mux_nodes[b..(b + self.a_mux_count[i])]);
            let s = format!("{:?}", x);
            let y = Vec::from(&self.b_mux_nodes[b..(b + self.b_mux_count[i])]);
            let pads = " ".repeat(2 + (self.mux_width * 4 - s.len()) % 8);
            let tabs = "\t".repeat(1 + (self.mux_width * 4 - s.len()) / 8);
            write!(f, "        COR{}\tA:{}", i, s)?;
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
        let num_units: usize = (num_calcs as f64 / clock_multiplier as f64).ceil() as usize;

        // If using means, then '+1', and if fewer correlators than antennas,
        // then another '+1'?
        let mut extras: usize = if !no_means { 1 } else { 0 };
        if num_units < num_antennas {
            extras += 1;
        }
        let width0: usize = ((clock_multiplier + extras) as f64).sqrt().ceil() as usize;
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

            a_mux_count: vec![0; num_units],
            a_mux_nodes: vec![0; num_units * mux_width],
            b_mux_count: vec![0; num_units],
            b_mux_nodes: vec![0; num_units * mux_width],
        }
    }

    // -- PRIVATE NODES FUNCTIONS -- //

    fn a_mux_contains(&self, unit: usize, node: usize) -> bool {
        let mut index = unit * self.mux_width;
        let limit = index + self.a_mux_count[unit];

        while index < limit {
            if self.a_mux_nodes[index] == node {
                return true;
            }
            index += 1;
        }

        false
    }

    fn b_mux_contains(&self, unit: usize, node: usize) -> bool {
        let mut index = unit * self.mux_width;
        let limit = index + self.b_mux_count[unit];

        while index < limit {
            if self.b_mux_nodes[index] == node {
                return true;
            }
            index += 1;
        }

        false
    }

    pub fn can_insert_a_node(&self, unit: usize, node: usize) -> bool {
        self.a_mux_contains(unit, node) || self.a_mux_count[unit] < self.mux_width
    }

    pub fn can_insert_b_node(&self, unit: usize, node: usize) -> bool {
        self.b_mux_contains(unit, node) || self.b_mux_count[unit] < self.mux_width
    }

    /**
     *  Attempts to insert the indicated A-MUX node, and then updates the edge-
     *  set if any new edges result. Then, returns the number of new edges.
     */
    fn insert_a_node(&mut self, unit: usize, node: usize) -> usize {
        let mut edges = 0;
        if self.a_mux_contains(unit, node) {
            return edges;
        } else if self.b_mux_contains(unit, node) {
            println!(
                "ERROR: attempt to insert '{}' into A-MUX, when present in B-MUX!\n",
                node
            );
            return edges;
        }

        let width = self.mux_width;
        let count = self.a_mux_count[unit];
        let base = unit * width;

        assert!(count <= width);
        if count == width {
            return edges;
        }

        // Update all node pairs-counts due to the other MUX inputs
        for dest in &self.a_mux_nodes[base..(base + count)] {
            // For each A-MUX node, increase the corresponding A-A pairs count
            let index = self.calc_edge_index(node, *dest);
            self.pairs_count[index] += 1;
        }

        self.a_mux_nodes[base + count] = node;
        self.a_mux_count[unit] = count + 1;
        self.nodes_count[node] += 1;

        // Compute any new edges due to the new A-MUX node
        let count = self.b_mux_count[unit];
        for dest in &self.b_mux_nodes[base..(base + count)] {
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
        if self.b_mux_contains(unit, node) {
            return edges;
        } else if self.b_mux_contains(unit, node) {
            println!(
                "ERROR: attempt to insert '{}' into B-MUX, when present in A-MUX!\n",
                node
            );
            return edges;
        }

        let width = self.mux_width;
        let count = self.b_mux_count[unit];
        let base = unit * width;

        assert!(count <= width);
        if count == width {
            return edges;
        }

        // Update all node pairs-counts due to the other MUX inputs
        for dest in &self.b_mux_nodes[base..(base + count)] {
            // For each B-MUX node, increase the corresponding B-B pairs count
            let index = self.calc_edge_index(node, *dest);
            self.pairs_count[index] += 1;
        }

        self.b_mux_nodes[base + count] = node;
        self.b_mux_count[unit] = count + 1;
        self.nodes_count[node] += 1;

        // Compute any new edges due to the new B-MUX node
        let count = self.a_mux_count[unit];
        for dest in &self.a_mux_nodes[base..(base + count)] {
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

    pub fn insert_node_pair(&mut self, unit: usize, node_a: usize, node_b: usize) -> usize {
        if node_a == node_b {
            panic!("RETARTED!!");
        }

        // Insert the A-MUX node, if not present, and update edge-counts
        let edges = self.insert_a_node(unit, node_a);

        // Insert the B-MUX node, if not present, and update edge-counts
        edges + self.insert_b_node(unit, node_b)
    }

    // -- PRIVATE EDGES FUNCTIONS -- //

    fn calc_edge_index(&self, node_a: usize, node_b: usize) -> usize {
        let src = if node_a > node_b { node_b } else { node_a };
        let dst = if node_a > node_b { node_a } else { node_b };

        assert!(src < dst);

        ((src * ((self.num_antennas << 1) - 3 - src)) >> 1) + dst - 1
    }

    fn make_edges(num_antennas: usize) -> Vec<(usize, usize)> {
        let num_edges: usize = (num_antennas * (num_antennas - 1)) >> 1;
        let mut edges: Vec<(usize, usize)> = Vec::<(usize, usize)>::with_capacity(num_edges);

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
        if self.a_mux_contains(unit, node_b) {
            if self.b_mux_contains(unit, node_a) {
                // Already present, so zero new edges
                return 0;
            } else {
                // SWAP
                (node_a, node_b) = (node_b, node_a);
                // let mut temp = node_a; node_a = node_b; node_b = temp;
            }
        } else if self.b_mux_contains(unit, node_a) {
            // SWAP
            (node_a, node_b) = (node_b, node_a);
            // let mut temp = node_a; node_a = node_b; node_b = temp;
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
            } else {
                edges += self.insert_node_pair(unit, node, temp);
            }

            unit += 1;
            node += 2;
        }

        edges
    }

    // -- PUBLIC PARTS -- //

    pub fn num_nodes_at(&self, unit: usize) -> usize {
        self.a_mux_count[unit] + self.b_mux_count[unit]
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
        if self.b_mux_contains(unit, node) || self.a_mux_contains(unit, node) {
            return (usize::MAX, usize::MAX, usize::MAX);
        }

        // To start with, compute the global score
        let (mut edge_score, mut pair_score, node_score) = self.node_score(node);

        // Update the edge-score due to insertion of 'node'
        let base = self.mux_width * unit;
        for i in base..(base + self.b_mux_count[unit]) {
            let edge = self.calc_edge_index(node, self.b_mux_nodes[i]);
            edge_score += self.edges_count[edge] + 1;
        }

        // Update the pair-score due to insertion of 'node'
        for i in base..(base + self.a_mux_count[unit]) {
            let pair = self.calc_edge_index(node, self.a_mux_nodes[i]);
            pair_score += self.pairs_count[pair] + 1;
        }

        (edge_score, pair_score, node_score + 1)
    }

    fn b_mux_score(&self, unit: usize, node: usize) -> (usize, usize, usize) {
        // Can not insert into both A- & B- MUXs, or already in B-MUX
        if self.a_mux_contains(unit, node) || self.b_mux_contains(unit, node) {
            return (usize::MAX, usize::MAX, usize::MAX);
        }

        // To start with, compute the global score
        let (mut edge_score, mut pair_score, node_score) = self.node_score(node);

        // Update the edge-score due to insertion of 'node'
        let base = self.mux_width * unit;
        for i in base..(base + self.a_mux_count[unit]) {
            let edge = self.calc_edge_index(node, self.a_mux_nodes[i]);
            edge_score += self.edges_count[edge] + 1;
        }

        // Update the pair-score due to insertion of 'node'
        for i in base..(base + self.b_mux_count[unit]) {
            let pair = self.calc_edge_index(node, self.b_mux_nodes[i]);
            pair_score += self.pairs_count[pair] + 1;
        }

        (edge_score, pair_score, node_score + 1)
    }

    fn place_a_mux(&mut self, unit: usize) -> &mut Self {
        let mut scores: Vec<((usize, usize, usize), usize)> = Vec::with_capacity(self.num_antennas);

        for i in 0..self.num_antennas {
            scores.push((self.a_mux_score(unit, i), i));
        }

        scores.sort_unstable();
        self.insert_a_node(unit, scores[0].1);
        self
    }

    fn place_b_mux(&mut self, unit: usize) -> &mut Self {
        let mut scores: Vec<((usize, usize, usize), usize)> = Vec::with_capacity(self.num_antennas);

        for i in 0..self.num_antennas {
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
            let mux_b: bool = self.a_mux_count[unit] > self.b_mux_count[unit];

            if mux_b {
                self.place_b_mux(unit);
            } else {
                self.place_a_mux(unit);
            }
        }
    }

    /**
     *  Clear all current node, edge, and MUX assignments.
     */
    pub fn reset(&mut self) {
        self.edges_count.fill(0);
        self.nodes_count.fill(0);
        self.pairs_count.fill(0);
        self.a_mux_count.fill(0);
        self.b_mux_count.fill(0);
    }

    pub fn sort_inputs(&mut self) {
        let w = self.mux_width;
        for (i, xs) in self.a_mux_nodes.chunks_mut(w).enumerate() {
            assert_eq!(w, self.a_mux_count[i]);
            xs.sort_unstable();
        }
        for (i, xs) in self.b_mux_nodes.chunks_mut(w).enumerate() {
            assert_eq!(w, self.b_mux_count[i]);
            xs.sort_unstable();
        }
    }

    pub fn replace(&mut self, unit: usize, curr: usize, next: usize) {
        if self.a_mux_contains(unit, curr) {
            let c = self.a_mux_count[unit];
            let p = unit * self.mux_width;

            for i in p..p + c {
                if self.a_mux_nodes[i] == curr {
                    for j in p..p + self.b_mux_count[unit] {
                        let b = self.b_mux_nodes[j];
                        let e = self.calc_edge_index(curr, b);
                        self.edges_count[e] -= 1;
                        let e = self.calc_edge_index(next, b);
                        self.edges_count[e] += 1;
                    }
                    self.nodes_count[curr] -= 1;

                    self.a_mux_nodes[i] = next;
                    self.nodes_count[next] += 1;
                } else {
                    let e = self.calc_edge_index(curr, self.a_mux_nodes[i]);
                    self.pairs_count[e] -= 1;
                    let e = self.calc_edge_index(next, self.a_mux_nodes[i]);
                    self.pairs_count[e] += 1;
                }
            }
        } else if self.b_mux_contains(unit, curr) {
            let c = self.b_mux_count[unit];
            let p = unit * self.mux_width;
            for i in p..p + c {
                if self.b_mux_nodes[i] == curr {
                    for j in p..p + self.a_mux_count[unit] {
                        let a = self.a_mux_nodes[j];
                        let e = self.calc_edge_index(curr, a);
                        self.edges_count[e] -= 1;
                        let e = self.calc_edge_index(next, a);
                        self.edges_count[e] += 1;
                    }
                    self.nodes_count[curr] -= 1;

                    self.b_mux_nodes[i] = next;
                    self.nodes_count[next] += 1;
                } else {
                    let e = self.calc_edge_index(curr, self.b_mux_nodes[i]);
                    self.pairs_count[e] -= 1;
                    let e = self.calc_edge_index(next, self.b_mux_nodes[i]);
                    self.pairs_count[e] += 1;
                }
            }
        }
    }

    /// TODO:
    pub fn replace_score(&self, unit: usize, node: usize, next: usize) -> usize {
        // Compute score for removing an unnecessary node
        let score = if self.a_mux_contains(unit, node) {
            let c = self.b_mux_count[unit];
            let p = unit * self.mux_width;
            // todo: score of zero if any edges_count is less than two
            Vec::from(&self.b_mux_nodes[p..p + c])
                .iter()
                .map(|b| {
                    let e = self.calc_edge_index(node, *b);
                    self.edges_count[e] + self.pairs_count[e]
                })
                .sum::<usize>()
                + self.nodes_count[node]
        } else if self.b_mux_contains(unit, node) {
            let c = self.a_mux_count[unit];
            let p = unit * self.mux_width;
            Vec::from(&self.a_mux_nodes[p..p + c])
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

    pub fn find_unneeded(&self) -> Vec<(usize, usize)> {
        let w = self.mux_width;
        let mut unneeded = Vec::new();

        for u in 0..self.num_units {
            let c = self.a_mux_count[u];
            let d = self.b_mux_count[u];
            let p = u * w;

            for a in &self.a_mux_nodes[p..p + c] {
                if Vec::from(&self.b_mux_nodes[p..p + d])
                    .iter()
                    .all(|b| self.edges_count[self.calc_edge_index(*a, *b)] > 1)
                {
                    unneeded.push((u, *a));
                }
            }

            for b in &self.b_mux_nodes[p..p + d] {
                if Vec::from(&self.a_mux_nodes[p..p + c])
                    .iter()
                    .all(|a| self.edges_count[self.calc_edge_index(*a, *b)] > 1)
                {
                    unneeded.push((u, *b));
                }
            }
        }

        unneeded
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
        } else if verbose {
            println!("Skipping means ...");
        }

        // Filling both input MUXs of each correlator unit.
        for i in 0..self.num_units {
            self.fill_unit(i);
        }

        // Sort (ascending) the MUX inputs.
        self.sort_inputs();
    }
}
