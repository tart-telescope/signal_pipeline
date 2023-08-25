#![allow(dead_code)]

#[derive(Debug)]
struct Bipartite {
    label: Option<String>,
    // directed: bool,
    a_nodes: Vec<usize>,
    b_nodes: Vec<usize>,
    edges: Vec<(usize, usize)>,
}

impl Bipartite {
    pub fn new() -> Self {
        Self {
            label: None,
            a_nodes: Vec::new(),
            b_nodes: Vec::new(),
            edges: Vec::new(),
        }
    }

    pub fn contains_a_node(&self, node: usize) -> bool {
        self.a_nodes.iter().any(|x| *x == node)
    }

    pub fn add_a_node(&mut self, node: usize) -> &mut Self {
        assert!(!self.contains_b_node(node));
        if !self.contains_a_node(node) {
            self.a_nodes.push(node);
        }
        self
    }

    pub fn contains_b_node(&self, node: usize) -> bool {
        self.b_nodes.iter().any(|x| *x == node)
    }

    pub fn add_b_node(&mut self, node: usize) -> &mut Self {
        assert!(!self.contains_a_node(node));
        if !self.contains_b_node(node) {
            self.b_nodes.push(node);
        }
        self
    }

    pub fn contains_edge(&self, node_a: usize, node_b: usize) -> bool {
        self.edges.iter().any(|(x, y)| *x == node_a && *y == node_b)
    }

    pub fn add_edge(&mut self, node_a: usize, node_b: usize) -> &mut Self {
        if !self.contains_edge(node_a, node_b) {
            self.add_a_node(node_a);
            self.add_b_node(node_b);
        }
        self
    }
}
