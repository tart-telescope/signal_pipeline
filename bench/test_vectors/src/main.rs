use clap::Parser;
use rand::distributions::{Distribution, Uniform};
use std::fs::File;
use std::io::{BufWriter, Write};
use num::complex::Complex;

/* Given an antenna, generate a random list of sample values
 * Store these in radio_data: an array of n_ant, n_samples.
 * Write these to a verilog test vector file 'radio_data.txt'
 *
 * generate the complex correlation products for each pair (i,j) and write these
 * a file called 'vis_data.txt'
 */

type DataType = Complex<i32>;

fn create_data(n: usize) -> Vec<DataType> {

    let mut rng = rand::thread_rng();
    let sign_mag = Uniform::from(-7..8);
    let mut buffer: Vec<DataType> = Vec::with_capacity(n);
    
    for _ in 0..buffer.capacity() {        
        buffer.push(Complex::new(sign_mag.sample(&mut rng), sign_mag.sample(&mut rng)));
    };

    return buffer;
}

fn correlate(a: &Vec<DataType>, b: &Vec<DataType>) -> Complex<i32> {
    // Complex Correlation of antennas a and b signals
    // (a + ib)*(c - id) = a*c + b*d +ib*c -ia*d
    // = (a*c + b*d) + i(b*c) - (a*d)
    
    let mut re: i32 = 0;
    let mut im: i32 = 0;
    
    for i in 0..a.capacity() {
        re += a[i].re*b[i].re + a[i].im*b[i].im;
        im += a[i].im*b[i].re - a[i].re*b[i].im;
    }
    
    return Complex::new(re,im);
}


fn to_sign_magnitude(a : i32, nbits: i32) -> i32 {
    // See Table 16 in the Max2769 data sheet.
    let mut ret = 0;
    
    match nbits{
        1 => {
            if a < 0 { ret = 1; }
            else { ret = 0; }
        },
        2 => {
            if a < 0 { ret = 1; }
            else { ret = 0; }
        }
        _ => println!("Only work with 1 or two bit sign magnitude data")
    }
    return ret;
}

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Name of file to output
    #[arg(short, long, default_value_t = String::from("test_vectors.txt"))]
    fname: String,

    /// Number of antennas
    #[arg(short, long, default_value_t = 8)]
    ant: u8,

    /// Number of samples
    #[arg(short, long, default_value_t = 1024)]
    samples: usize,
}



fn main() -> std::io::Result<()> {
    let args = Args::parse();
    println!("Output file {}", args.fname);
    
    let mut data: Vec<Vec<DataType>> = Vec::with_capacity(args.ant.into());
    
    for i in 0..args.ant {
        println!("Antenna {}!", i);
        let buffer = create_data(args.samples);
        data.push(buffer); // println!("{:?}", &buffer);
    }
    
    // Now write data to a file one set of samples at a time...
    let file = File::create(args.fname).expect("Unable to create file");
    let mut writer = BufWriter::new(file);

    let mut s: Vec<DataType> = vec![Complex::new(0,0); args.ant.into()];
    
    for i in 0..args.samples {
        
        for j in 0..s.capacity() {
            s[j] = data[j][i];
            write!(writer, "{}{}",to_sign_magnitude(s[j].re,1), to_sign_magnitude(s[j].im,1))?;
        }
        write!(writer, "\n")?;
    }
    writer.flush()?;
    
    
    // Now generate correlations and write them out
    for i in 0..args.ant {
        for j in i..args.ant {
            let z = correlate(&(data[i as usize]), &(data[j as usize]));
            println!("{},{} = {:?}", i,j,z);
        }
    }
    Ok(())
}
