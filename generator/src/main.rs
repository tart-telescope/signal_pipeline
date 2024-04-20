use clap::Parser;
use log::{debug, error, warn};
use tart_dsp::{logger, Chunked, Context};

/// Command line options for configuring the TART DSP, based on the number of
/// antennas, and the relative frequencies of the antenna source signals, vs
/// that of the correlators. For example, the first TART DSP used 16.384 MHz as
/// the sampling-rate/-clock, and the correlators operated at 12x the sampling
/// clock frequency, so '196.608 MHz'; i.e., 12 x 16.384 MHz .  This setup
/// could be generated using the following the command line:
///  ./tart-dsp --antennas=24 --multiplier=12 --extra-bits=1
///
/// Note: the default settings is to generate a correlator configuration that
///   also computes the (real) signals-means for each antenna/source. Therefore
///   the total number of correlator computations (per incoming set of sample)
///   is $n^2 / 2$.
///
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Number of antennas/sources
    #[arg(short, long, value_name = "NUM", default_value = "8")]
    antennas: usize,

    /// Clock ratio/multiplier for the correlators, relative to the input source.
    #[arg(short, long, value_name = "FACTOR", default_value = "12")]
    multiplier: usize,

    /// Do not compute the signal-means, when this is enabled.
    #[arg(short, long, value_name = "BOOL", default_value = "false")]
    no_means: bool,

    // #[arg(short, long, value_name = "FILE", default_value = "params.txt")]
    #[arg(short, long)]
    output: bool,

    /// Number of extra MUX-width inputs, for more difficult configurations
    #[arg(short, long, value_name = "BITS", default_value = "0")]
    extra_bits: usize,

    /// Verbosity
    #[arg(short, long, value_name = "LEVEL")]
    log_level: Option<String>,

    /// Verbosity of generated output?
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

#[derive(Debug, Clone)]
pub struct EdgesArray {
    pub edges: Chunked<usize>,
}

fn mux_selects(
    context: Context,
    edges: Chunked<usize>,
    means: Chunked<(usize, usize)>,
) -> Chunked<(usize, usize)> {
    let edge_num = context.edges_array.len();

    // Create a LUT: Edge -> Core.
    let mut edge_to_core: Vec<usize> = vec![usize::MAX; edge_num];

    for (u, core) in edges.into_iter().enumerate() {
        debug!("core[{}]: {:?}", u, core);
        for &e in core.iter() {
            edge_to_core[e] = u;
        }
    }

    // warn!("Edge -> Core:\n{:?}", edge_to_core);

    let mut selects = Chunked::new(context.clock_multiplier, context.num_units);

    for (u, (a_mux, b_mux)) in context
        .a_mux_array
        .into_iter()
        .zip(context.b_mux_array.into_iter())
        .enumerate()
    {
        let mut i: usize = 0;
        let mut j: usize = 0;

        while i < a_mux.len() && j < b_mux.len() {
            let a = a_mux[i];
            let b = b_mux[j];

            if a < b {
                for (k, &b) in b_mux.iter().enumerate().skip(j) {
                    let e = context.calc_edge_index(a, b);
                    if edge_to_core[e] == u {
                        selects.push(u, (i, k));
                    }
                }
                if i < a_mux.len() {
                    i += 1;
                }
            } else {
                for (k, &a) in a_mux.iter().enumerate().skip(i) {
                    let e = context.calc_edge_index(a, b);
                    if edge_to_core[e] == u {
                        selects.push(u, (k, j));
                    }
                }
                if j < b_mux.len() {
                    j += 1;
                }
            }
        }
    }

    // fixme: does not work because 'Chunked<T>' does not allow duplicates!
    for (u, pairs) in means.into_iter().enumerate() {
        warn!("pairs[{}]: {:?}", u, pairs);
        let a_mux = &context.a_mux_array[u];
        let b_mux = &context.b_mux_array[u];

        for (a, b) in pairs {
            if let Ok(i) = a_mux.binary_search(a) {
                if let Ok(j) = b_mux.binary_search(b) {
                    selects.push(u, (i, j));
                }
            }
        }
    }

    selects
}

/// Assign the correlator-pairs, and the self-means, to each correlator unit.
fn assign_calculations(context: &mut Context) -> String {
    let mut result = Vec::new();
    if let Some(edges) = context.assign_edges(true) {
        result.push("Visibility-calculation assignments:".to_string());
        result.push(format!("{}", edges));

        result.push("Signal-mean calculation assignments:".to_string());
        let means = if let Some(means) = context.assign_means(edges.clone()) {
            result.push(format!("{}", means));
            means
        } else if let Some(means) = context.means_another(edges.clone()) {
            result.push(format!("{}", means));
            means
        } else if let Some(means) = context.means_assign(edges.clone()) {
            result.push(format!("{}", means));
            means
        } else {
            result.push("FAILED !!".to_string());
            Chunked::new(1, 0)
        };
        let selects = mux_selects(context.clone(), edges, means);
        result.push(format!("{}", selects));
    }
    result.join("\n")
}

/**
 * Main entry-point into the TART DSP correlator-pairs assignment procedure.
 */
fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("TART DSP Generator Extreme\n");
    let args: Args = Args::parse();
    let level: String = args.log_level.unwrap_or("info".to_string());
    logger::configure(level.as_str(), args.verbose > 0)?;

    let mut context: Context = tart_dsp::Context::new(
        args.antennas,
        args.multiplier,
        args.no_means,
        args.extra_bits,
    );
    context.partition(args.verbose > 0);
    println!("{}", context);

    if args.verbose > 0 {
        if args.verbose > 2 {
            let (colptrs, indices) = context.find_edge_units();
            println!("colptrs: {:?}", colptrs);
            println!("indices: {:?}", indices);

            println!("{}", context.a_mux_array);
            println!("{}", context.b_mux_array);
        }

        if args.verbose > 1 {
            let unneeded = context.find_unneeded();
            println!(
                "Uneeded nodes (total = {}):\n{}",
                unneeded.total_count(),
                unneeded,
            );

            context.unit_scores();
        }
    }

    Ok(println!("{}", assign_calculations(&mut context)))
}
