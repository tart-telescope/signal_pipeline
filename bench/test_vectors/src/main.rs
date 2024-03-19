use clap::Parser;
use rand::distributions::{Distribution, Uniform};
use rand::Rng;
use std::fs::File;
use std::io::{BufWriter, Write};
use num::complex::Complex;

/* Given an antenna, generate a random list of sample values
 * Store these in radio_data: an array of n_ant, n_samples.
 * Write these to a verilog test vector file 'radio_data.txt'
 *
 * generate the complex correlation products for each pair (i,j) and write these
 * a file called 'vis_data.txt' TODO At the moment these are just displayed.
 */

type DataType = Complex<i32>;

/**
    * Create an ADC sample (random) that matches the range of samples 
    * that we can expect from the MA2769. NOTE. This means that for 2-bit
    * data the range will be greater (between -5 and 5) and I'm a little unsure
    * about what scaling means in this case. I suspect that as we have Automatic
    * gain control, the scaling is not significant, and we can rescale down
    * to something suitable, so perhaps can use a range of -2,-1,1,2 just as well
    * although we have to be careful. 1-bit is just 1 if negative and 0 if positive.
    * */
fn adc_sample(rng: &mut impl Rng, bits: u8) -> i32 {
    let mut s = 0;
    let mut min = -1;
    let mut max = 1;
        
    match bits {
        1 => { min = -1; max = 1; }
        2 => { min = -5; max = 5; }
        _ => println!("Only work with 1 or two bit sign magnitude data")
    }
    
    let sign_mag = Uniform::from(min..=max);
    
    while s % 2 == 0 {
        s = sign_mag.sample(rng); // the radio itself never produces zeros, or even numbers.
    }
    return s;
}

fn to_sign_magnitude(a : i32, nbits: u8) -> i32 {
    // See Table 16 in the Max2769 data sheet.
    let mut ret = 0;
    
    match nbits{
        1 => {
            if a < 0 { ret = 1; }
            else { ret = 0; }
        },
        2 => {
            if a < -3 { ret = 0b11; }
            else if a < 0 { ret = 0b10; }
            else if a < 4 { ret = 0b00; }
            else { ret = 0b01; }
        }
        _ => println!("Only work with 1 or two bit sign magnitude data")
    }
    return ret;
}


fn create_data(n: usize, bits: u8) -> Vec<DataType> {
    let mut rng = rand::thread_rng();

    let mut buffer: Vec<DataType> = Vec::with_capacity(n);
    
    for _ in 0..buffer.capacity() {
        buffer.push(Complex::new(adc_sample(&mut rng, bits), adc_sample(&mut rng, bits)));
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



#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    /// Name of file to output
    #[arg(short, long, default_value_t = String::from("radio_data.txt"))]
    fname: String,

    /// Number of antennas
    #[arg(short, long, default_value_t = 8)]
    ant: u8,

    /// Number of ADC bits
    #[arg(short, long, default_value_t = 1)]
    bits: u8,

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
        let buffer = create_data(args.samples, args.bits);
        data.push(buffer); // println!("{:?}", &buffer);
    }
    
    // Now write data to a file one set of samples at a time...
    let file = File::create(args.fname).expect("Unable to create file");
    let mut writer = BufWriter::new(file);

    let mut s: Vec<DataType> = vec![Complex::new(0,0); args.ant.into()];
    
    for i in 0..args.samples {
        
        for j in 0..s.capacity() {
            s[j] = data[j][i];
            write!(writer, "{}{}",to_sign_magnitude(s[j].re,args.bits), to_sign_magnitude(s[j].im,args.bits))?;
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
