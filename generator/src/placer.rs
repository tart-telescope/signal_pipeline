use crate::context::Context;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GoatBoi {
    GoatBoi(Context),
}

pub struct Placer {
    context: Context,
    width: usize,

    /* Edge assignments for each correlator */
    count: Vec<usize>,
    edges: Vec<usize>,
}

impl Placer {
    pub fn new(context: Context) -> Self {
        let num_units = context.get_num_units();
        let width = context.get_mux_width();
        let clock_multiplier = context.get_clock_multiplier();

        Self {
            context,
            width,
            count: vec![0; num_units],
            edges: vec![0; num_units * clock_multiplier],
        }
    }

    /**
     *  Assign each edge to a correlator unit, and resolve duplicates.
     *
     *  Algorithm:
     *   1)
     */
    pub fn assign(&mut self, verbose: bool) {}
}
