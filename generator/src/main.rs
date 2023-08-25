use clap::Parser;
use tart_dsp::Context;

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

fn main() {
    println!("TART DSP Generator Extreme\n");
    let args: Args = Args::parse();

    let mut context: Context = tart_dsp::Context::new(
        args.antennas,
        args.multiplier,
        args.no_means,
        args.extra_bits,
    );
    context.partition(args.verbose > 0);

    /* Example that shows that failing attempts can be fixed
    if args.antennas == 32 && args.multiplier == 30 && args.extra_bits == 1 {
        context.replace(16, 27, 16);
        context.replace(17, 10, 12);
        context.replace(17, 25, 14);
        context.replace(17, 2, 9);
        context.sort_inputs();
    }
    */

    println!("{}", context);
    if args.verbose > 0 {
        let unneeded = context.find_unneeded();
        println!("Uneeded {{\n{:?}\n}} (len: {})", unneeded, unneeded.len());
    }
}
