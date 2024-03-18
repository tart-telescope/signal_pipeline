use clap::Parser;
use rand::{distributions::Uniform, Rng};

// Perform a forward FFT of size 1234
use rustfft::{FftPlanner, num_complex::Complex};


/* Given an antenna, generate a random list of sample values
 * Store these in radio_data: an array of n_ant, n_samples.
 * Write these to a verilog test vector file 'radio_data.txt'
 *
 * generate the complex correlation products for each pair (i,j) and write these
 * a file called 'vis_data.txt'
 */


fn do_fft(n: usize) {
    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(n);

    let mut rng = rand::thread_rng();
    let range = Uniform::new(0, 20);

    let mut buffer = vec![Complex{ re: rng.sample(&range), im: rng.sample(&range) }; n];
    fft.process(&mut buffer);
}


#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Name of the person to greet
    #[arg(short, long)]
    name: String,

    /// Number of times to greet
    #[arg(short, long, default_value_t = 1)]
    count: u8,
}

fn main() {
    let args = Args::parse();
    println!("Hello, world!");
    for _ in 0..args.count {
        println!("Hello {}!", args.name)
    }

    do_fft(1234);
}