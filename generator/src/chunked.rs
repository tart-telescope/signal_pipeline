/**
 *  2D arrays with each subarray having up to 'stride' size.
 */
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Chunked<T> {
    stride: usize,
    counts: Vec<usize>,
    values: Vec<T>,
}

impl<T: std::fmt::Debug> std::fmt::Display for Chunked<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        writeln!(f, "Chunked {{")?;
        writeln!(f, "    stride: {}", self.stride)?;
        writeln!(f, "    chunks: {}", self.counts.len())?;
        writeln!(f, "    counts: {:?}", self.counts)?;
        writeln!(f, "    values: [")?;
        let mut b = 0;
        for i in 0..self.counts.len() {
            let c = self.counts[i];
            write!(f, "        [ ")?;
            for j in b..b + c {
                write!(f, "{:?} ", &self.values[j])?;
            }
            writeln!(f, "]")?;
            b += self.stride;
        }
        writeln!(f, "    ]")?;
        writeln!(f, "}}")
    }
}

impl<T> Default for Chunked<T> {
    fn default() -> Self {
        Self {
            stride: 1,
            counts: Vec::new(),
            values: Vec::new(),
        }
    }
}

impl<T: Default + Clone> Chunked<T> {
    pub fn new(stride: usize, length: usize) -> Self {
        if stride < 1 {
            panic!("idiot!");
        }
        Self {
            stride,
            counts: vec![0; length],
            values: vec![T::default(); stride * length],
        }
    }
}

impl<T> Chunked<T> {
    fn check_chunk_limit(&self, chunk: usize) -> bool {
        if chunk >= self.counts.len() {
            eprintln!(
                "out of bounds, ignoring, retard (chunk: {}, length: {})",
                chunk,
                self.counts.len()
            );
            return false;
        }
        true
    }

    pub fn count(&self, chunk: usize) -> usize {
        if !self.check_chunk_limit(chunk) {
            return self.stride;
        }
        self.counts[chunk]
    }

    pub fn get_stride(&self) -> usize {
        self.stride
    }

    /**
     *  Empty if there is no data.
     */
    pub fn is_empty(&self) -> bool {
        self.counts.iter().sum::<usize>() == 0
    }

    pub fn total_count(&self) -> usize {
        self.counts.iter().sum::<usize>()
    }

    pub fn len(&self) -> usize {
        self.counts.len()
    }

    pub fn capacity(&self) -> usize {
        self.stride * self.counts.len()
    }

    pub fn reset(&mut self) -> &mut Self {
        self.counts.fill(0);
        self
    }
}

impl<T: PartialEq> Chunked<T> {
    #[inline]
    fn contains_unsafe(&self, chunk: usize, value: T) -> bool {
        let base = self.stride * chunk;
        let limit = base + self.counts[chunk];
        for i in base..limit {
            if self.values[i] == value {
                return true;
            }
        }
        false
    }

    pub fn contains(&self, chunk: usize, value: T) -> bool {
        if !self.check_chunk_limit(chunk) {
            return false;
        }
        self.contains_unsafe(chunk, value)
    }

    pub fn can_push(&self, chunk: usize, value: T) -> bool {
        self.count(chunk) < self.stride || self.contains_unsafe(chunk, value)
    }

    pub fn push(&mut self, chunk: usize, value: T) {
        if !self.check_chunk_limit(chunk) {
            return;
        }
        let base = self.stride * chunk;
        let offset = self.counts[chunk];

        // Already exists?
        for i in base..base + offset {
            if self.values[i] == value {
                return;
            }
        }

        // Does there exist free space?
        if offset < self.stride {
            self.values[self.stride * chunk + offset] = value;
            self.counts[chunk] += 1;
        }
    }
}

impl<T: Clone> Chunked<T> {
    pub fn pop(&mut self, chunk: usize) -> Option<T> {
        if !self.check_chunk_limit(chunk) {
            return None;
        }

        // Any items that can be popped?
        let offset = self.counts[chunk];
        if offset == 0 {
            return None;
        }

        // Pop the last item
        let base = self.stride * chunk;
        self.counts[chunk] -= 1;
        Some(self.values[base + offset - 1].clone())
    }

    pub fn delete(&mut self, chunk: usize, index: usize) {
        if !self.check_chunk_limit(chunk) {
            return;
        }
        let base = self.stride * chunk + index;
        let limit = base + self.counts[chunk];
        if base >= limit {
            return;
        }
        for i in base..limit {
            self.values[i - 1] = self.values[i].clone();
        }
        self.counts[chunk] -= 1;
    }
}

impl<T: Clone + PartialEq> Chunked<T> {
    pub fn remove(&mut self, chunk: usize, value: T) {
        if !self.check_chunk_limit(chunk) {
            return;
        }
        let base = self.stride * chunk;
        let limit = base + self.counts[chunk];
        let mut moving = false;

        for i in base..limit {
            if moving {
                self.values[i - 1] = self.values[i].clone();
            } else if self.values[i] == value {
                moving = true;
                self.counts[chunk] -= 1;
            }
        }
    }

    pub fn swap_remove(&mut self, chunk: usize, value: T) {
        if !self.check_chunk_limit(chunk) {
            return;
        }
        let base = self.stride * chunk;
        let limit = base + self.counts[chunk];

        for i in base..limit {
            if self.values[i] == value {
                if i + 1 < limit {
                    self.values[i] = self.values[limit - 1].clone();
                }
                self.counts[chunk] -= 1;
                break;
            }
        }
    }
}

impl<T: Ord> Chunked<T> {
    pub fn sort_chunks(&mut self) {
        for (i, xs) in self.values.chunks_mut(self.stride).enumerate() {
            assert_eq!(self.stride, self.counts[i]);
            xs.sort_unstable();
        }
    }

    // todo: ordered insertion ...
    /*
    pub fn insert(&mut self, chunk: usize, value: T) -> &mut Self {
        if !self.check_chunk_limit(chunk) {
            return self;
        }
        self
    }
    */
}

impl<T> core::ops::Index<usize> for Chunked<T> {
    type Output = [T];

    fn index(&self, index: usize) -> &Self::Output {
        if index >= self.counts.len() {
            panic!(
                "Out of bounds! (index: {} > length: {})",
                index,
                self.counts.len()
            );
        }
        let p = index * self.stride;
        self.values.get(p..p + self.counts[index]).unwrap() as &[T]
    }
}

impl<T> core::ops::IndexMut<usize> for Chunked<T> {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        if index >= self.counts.len() {
            panic!(
                "Out of bounds! (index: {} > length: {})",
                index,
                self.counts.len()
            );
        }
        let p = index * self.stride;
        self.values.get_mut(p..p + self.counts[index]).unwrap() as &mut [T]
    }
}

pub struct ChunkedIter<'a, T: Sized> {
    current: usize,
    chunked: &'a Chunked<T>,
}

impl<'a, T> Iterator for ChunkedIter<'a, T> {
    type Item = &'a [T];

    fn next(&mut self) -> Option<Self::Item> {
        let curr = self.current;
        if self.chunked.counts.len() > curr + 1 {
            self.current += 1;
            let num = self.chunked.counts[curr];
            Some(&self.chunked.values[curr..curr + num])
        } else {
            None
        }
    }
}

/*
impl<'a, T> IntoIterator for &'a Chunked<T> {
    type Item = &'a [T];
    type IntoIter = std::slice::Iter<'a, [T]>;

    fn into_iter(self) -> <&'a Chunked<T> as IntoIterator>::IntoIter {
        self.iter()
    }
}
 */

/*
impl<T> Iterator for Chunked<T> {
    type Item = Vec<T>;

    fn next(&mut self) -> Option<Self::Item> {

    }
}
*/
