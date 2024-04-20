use log::{debug, error, trace, warn};

use super::chunked::*;
use super::context::*;

impl Context {
    /**
     *  Allocates to each correlator the per-antenna autocorrelation nodes, as
     *  these are used to compute the average signal-level over the integration
     *  period.
     *
     *  Note: means are placed first, so resets the given context before
     *    placing any MUX inputs, for the means calculations.
     */

    // todo: this method is a bit too greedy, and does not consider whether
    //   there exists solutions for remaining means, when choosing pairs for
    //   each step.
    // todo: the 'means_assign(..)' function is better?
    pub fn assign_means(
        &mut self,
        units: Chunked<usize>,
    ) -> Option<Chunked<(usize, usize)>> {
        // Compute the nodes from least- to most- frequent
        let mut nodes: Vec<usize> = (0..self.num_antennas).collect();
        nodes.sort_by_key(|p| self.nodes_count[*p]);

        /*
        let mut freqs = self.means_set(units.clone());
        freqs.sort_unstable_by_key(|(_, c)| *c);
        if freqs.len() < self.num_antennas {
            error!("Cannot place all signal-means calculations!\n  {:?} (len = {})", freqs.clone(), freqs.len());
            return None;
        }
        let mut nodes = freqs
            .clone()
            .into_iter()
            .map(|(i, _)| i)
            .collect::<Vec<usize>>();
        */

        let mut min_count = units.get_stride();
        for i in 0..units.len() {
            if min_count > units.count(i) {
                min_count = units.count(i);
            }
        }

        let stride = units.get_stride() - min_count;
        let mut means: Chunked<(usize, usize)> =
            Chunked::new(stride, units.len());
        let mut prev = nodes.len();

        while !nodes.is_empty() {
            // Find the emptiest correlator unit that contains the two least-
            // frequent nodes ...
            let mut ranks: Vec<usize> = (0..self.num_units).collect();
            ranks.sort_by_key(|p| units.count(*p) + means.count(*p));
            // ranks.reverse();

            for unit in ranks {
                // Can we add to this unit?
                if units.count(unit) + means.count(unit)
                    >= self.clock_multiplier
                {
                    continue;
                }

                // Find the least two frequent nodes, and assign them
                let mut a_node = usize::MAX;
                let mut i = 0;
                while i < nodes.len() {
                    if self.a_mux_array[unit].contains(&nodes[i]) {
                        a_node = nodes[i];
                        break;
                    }
                    i += 1;
                }

                let mut b_node = usize::MAX;
                let mut i = 0;
                while i < nodes.len() {
                    if self.b_mux_array[unit].contains(&nodes[i]) {
                        b_node = nodes[i];
                        break;
                    }
                    i += 1;
                }

                if a_node < usize::MAX && b_node < usize::MAX {
                    means.push(unit, (a_node, b_node));
                    nodes.retain(|&x| x != a_node && x != b_node);
                    break;
                }
            }

            if nodes.len() == prev {
                // No nodes placed on this pass, so no solution
                error!("Cannot place all signal-means calculations!");
                error!("Remaining signal-means calculations to place:");
                error!("  {:?} (len = {})", nodes.clone(), nodes.len());
                return None;
            }
            prev = nodes.len();
        }

        Some(means)
    }

    pub fn means_set(&self, units: Chunked<usize>) -> Vec<(usize, usize)> {
        let length = self.num_antennas;
        let mut count: Vec<usize> = vec![0; length];

        for i in 0..units.len() {
            if units.count(i) < self.clock_multiplier {
                for j in self.a_mux_array[i].iter() {
                    count[*j] += 1;
                }
                for j in self.b_mux_array[i].iter() {
                    count[*j] += 1;
                }
            }
        }

        count
            .iter()
            .enumerate()
            .filter_map(|(i, &x)| if x > 0 { Some((i, x)) } else { None })
            .collect::<Vec<(usize, usize)>>()
    }

    pub fn means_assign(
        &mut self,
        units: Chunked<usize>,
    ) -> Option<Chunked<(usize, usize)>> {
        let mut freqs = self.means_set(units.clone());
        freqs.sort_unstable_by_key(|(_, c)| *c);
        if freqs.len() < self.num_antennas {
            error!("Cannot place all signal-means calculations!");
            error!("  {:?} (len = {})", freqs.clone(), freqs.len());
            return None;
        }
        debug!("freqs: {:?}", freqs);
        let mut nodes = freqs
            .clone()
            .into_iter()
            .map(|(i, _)| i)
            .collect::<Vec<usize>>();
        nodes.reverse();

        let mut min_count = units.get_stride();
        for i in 0..units.len() {
            if min_count > units.count(i) {
                min_count = units.count(i);
            }
        }

        let stride = units.get_stride() - min_count;
        let mut means: Chunked<(usize, usize)> =
            Chunked::new(stride, units.len());

        while !nodes.is_empty() {
            let node = nodes.pop().unwrap();
            let mut pairs = vec![usize::MAX; units.len()];
            let mut scores = vec![0; units.len()];

            for i in 0..units.len() {
                if units.count(i) + means.count(i) >= self.clock_multiplier {
                    continue;
                }

                // If we choose 'node', we need to also select a suitable pair
                let a_mux = self.a_mux_array[i].contains(&node);
                let mut others = if a_mux {
                    self.b_mux_array[i].to_vec()
                } else if self.b_mux_array[i].contains(&node) {
                    self.a_mux_array[i].to_vec()
                } else {
                    continue;
                };
                others.retain(|x| nodes.contains(x));

                if others.is_empty() {
                    continue;
                }

                // See which of the remaining nodes can still be placed, if we
                // assign the current 'node' to 'units[i]'.
                let mut rest = vec![0; nodes.len()];
                // let mut this = vec![0; nodes.len()];
                let mut lut = vec![usize::MAX; self.num_antennas];
                for (j, r) in nodes.iter().enumerate() {
                    lut[*r] = j;
                }

                // Each 'rest' node must still be assignable, if we place 'node
                // into 'units[i]'.
                let mut anum = vec![0; nodes.len()];
                let mut bnum = vec![0; nodes.len()];
                for k in 0..units.len() {
                    let diff =
                        self.clock_multiplier - units.count(k) - means.count(k);
                    if i == k {
                        for &l in &others {
                            // todo: want to find the unit that is "scarcest",
                            //   while leaving the greatest remainging options
                            // this[lut[l]] += free;
                            rest[lut[l]] += 1;
                            /*
                            if a_mux {
                                bnum[lut[l]] += 1;
                            } else {
                                anum[lut[l]] += 1;
                            }
                            */
                        }
                    } else if diff > 0 {
                        for &l in &self.a_mux_array[k] {
                            if lut[l] < usize::MAX {
                                rest[lut[l]] += 1;
                                anum[lut[l]] += 1;
                            }
                        }
                        for &l in &self.b_mux_array[k] {
                            if lut[l] < usize::MAX {
                                rest[lut[l]] += 1;
                                bnum[lut[l]] += 1;
                            }
                        }
                    }
                }

                // No route for at least one of the remaining means calculations
                if rest.contains(&0) {
                    continue;
                }

                // Try to fill up the A-MUX and B-MUX at the same rates ...
                let asu: usize = anum.iter().sum();
                let bsu: usize = bnum.iter().sum();
                let rem: usize = nodes.len() >> 1;
                if asu < rem || bsu < rem {
                    debug!("asum: {}, bsum: {} (remaining: {})", asu, bsu, rem);
                    continue;
                } else {
                    trace!(
                        "nodes: ({}, {:?}) => asum: {}, bsum: {} (remaining: {})",
                        node, nodes.clone(), asu, bsu, rem
                    );
                }

                // todo: detect the case that selecting 'units[i]' for 'node'
                //   results in too few solutions remaining for the 'others'?
                /*
                let mut sols = others.len();
                for &j in &others {
                    if rest[lut[j]] < 2 {
                        sols -= 1;
                    }
                }

                if others.len() > 1 && sols < 2 {
                    error!(
                        "No means solution for 'unit: {}' and 'node: {}'",
                        i, node
                    );
                    continue;
                }
                else {
                    println!("Remaining (pair) solutions for 'unit: {}' and 'node: {}': {} (others.len() = {}, rest: {:?})",
                        i, node, sols, others.len(), rest.clone(),
                    );
                }
                */

                // Find the least-common node in the other MUX
                let mut pmin = usize::MAX;
                let mut pidx = usize::MAX;
                for (j, &p) in rest.iter().enumerate() {
                    if others.contains(&nodes[j]) && p < pmin {
                        pmin = p;
                        pidx = nodes[j];
                    }
                }

                if pmin < usize::MAX {
                    // todo: can this underflow?
                    let s = rest.into_iter().sum::<usize>()
                        - if asu > bsu { asu - bsu } else { bsu - asu };
                    scores[i] = s;
                    // scores[i] = rest.into_iter().sum();
                    pairs[i] = pidx;
                }
            }

            // Find the best-scoring unit
            let mut smax = usize::MIN;
            let mut sidx = usize::MAX;
            for (i, &s) in scores.iter().enumerate() {
                if s > smax {
                    smax = s;
                    sidx = i;
                }
            }

            if sidx < usize::MAX {
                let pair = pairs[sidx];
                means.push(sidx, (node, pair));
                nodes.retain(|&x| x != pair);
            } else {
                nodes.push(node);
                warn!("{}", means);
                warn!("No solution, and remaining nodes: {:?}", nodes);
                return None;
            }
        }

        Some(means)
    }

    pub fn means_another(
        &mut self,
        units: Chunked<usize>,
    ) -> Option<Chunked<(usize, usize)>> {
        let mut freqs = self.means_set(units.clone());
        freqs.sort_unstable_by_key(|(_, c)| *c);
        if freqs.len() < self.num_antennas {
            error!("Cannot place all signal-means calculations!");
            error!("  {:?} (len = {})", freqs.clone(), freqs.len());
            return None;
        }
        debug!("freqs: {:?}", freqs);
        let mut nodes = freqs
            .clone()
            .into_iter()
            .map(|(i, _)| i)
            .collect::<Vec<usize>>();
        nodes.reverse();

        let mut min_count = units.get_stride();
        for i in 0..units.len() {
            if min_count > units.count(i) {
                min_count = units.count(i);
            }
        }

        let stride = units.get_stride() - min_count;
        let mut means: Chunked<(usize, usize)> =
            Chunked::new(stride, units.len());

        while !nodes.is_empty() {
            let node = nodes.pop().unwrap();
            let mut pairs = vec![usize::MAX; units.len()];
            let mut scores = vec![0; units.len()];

            for i in 0..units.len() {
                let free =
                    self.clock_multiplier - units.count(i) - means.count(i);
                if free == 0 {
                    continue;
                }

                // If we choose 'node', we need to also select a suitable pair
                let a_mux = self.a_mux_array[i].contains(&node);
                let mut others = if a_mux {
                    self.b_mux_array[i].to_vec()
                } else if self.b_mux_array[i].contains(&node) {
                    self.a_mux_array[i].to_vec()
                } else {
                    continue;
                };
                others.retain(|x| nodes.contains(x));

                if others.is_empty() {
                    continue;
                }

                let mut lut = vec![usize::MAX; self.num_antennas];
                for (j, r) in nodes.iter().enumerate() {
                    lut[*r] = j;
                }

                // See which of the remaining nodes can still be placed, if we
                // assign the current 'node' to 'units[i]'.
                let mut rest = vec![0; nodes.len()];

                // Each 'rest' node must still be assignable, if we place 'node
                // into 'units[i]'.
                let mut anum = vec![0; nodes.len()];
                let mut bnum = vec![0; nodes.len()];
                for k in 0..units.len() {
                    let mut diff =
                        self.clock_multiplier - units.count(k) - means.count(k);
                    if i == k {
                        for &l in &others {
                            // todo: want to find the unit that is "scarcest",
                            //   while leaving the greatest remainging options
                            rest[lut[l]] += 1;
                            if a_mux {
                                bnum[lut[l]] += 1;
                            } else {
                                anum[lut[l]] += 1;
                            }
                        }
                        diff -= 1;
                    }
                    if diff > 0 {
                        for &l in &self.a_mux_array[k] {
                            if lut[l] < usize::MAX {
                                rest[lut[l]] += diff;
                                anum[lut[l]] += diff;
                            }
                        }
                        for &l in &self.b_mux_array[k] {
                            if lut[l] < usize::MAX {
                                rest[lut[l]] += diff;
                                bnum[lut[l]] += diff;
                            }
                        }
                    }
                }

                // No route for at least one of the remaining means calculations
                if rest.contains(&0) {
                    continue;
                }

                // Try to fill up the A-MUX and B-MUX at the same rates ...
                let mut asu: usize = anum.iter().sum();
                let mut bsu: usize = bnum.iter().sum();
                if a_mux {
                    asu += 1;
                } else {
                    bsu += 1
                };
                let rem: usize = nodes.len() >> 1;
                if asu < rem || bsu < rem {
                    debug!("asum: {}, bsum: {} (remaining: {})", asu, bsu, rem);
                    continue;
                } else {
                    trace!(
                        "nodes: ({}, {:?}) => asum: {}, bsum: {} (remaining: {})",
                        node, nodes.clone(), asu, bsu, rem
                    );
                }

                // Find the least-common node in the other MUX
                let mut pmin = usize::MAX;
                let mut pidx = usize::MAX;
                for (j, &p) in rest.iter().enumerate() {
                    if others.contains(&nodes[j]) && p < pmin {
                        pmin = p;
                        pidx = nodes[j];
                    }
                }

                if pmin < usize::MAX {
                    // todo: can this underflow?
                    let s = rest.into_iter().sum::<usize>()
                        - if asu > bsu { asu - bsu } else { bsu - asu };
                    scores[i] = s;
                    pairs[i] = pidx;
                }
            }

            // Find the best-scoring unit
            let mut smax = usize::MIN;
            let mut sidx = usize::MAX;
            for (i, &s) in scores.iter().enumerate() {
                if s > smax {
                    smax = s;
                    sidx = i;
                }
            }

            if sidx < usize::MAX {
                let pair = pairs[sidx];
                means.push(sidx, (node, pair));
                nodes.retain(|&x| x != pair);
            } else {
                nodes.push(node);
                warn!("{}", means);
                warn!("No solution, and remaining nodes: {:?}", nodes);
                return None;
            }
        }

        Some(means)
    }
}
