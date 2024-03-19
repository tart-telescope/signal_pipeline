# Build Test Vectors for Correlator

This generates suitable random numbers from the ADC (in sign/magnitude format), then computes correlations for each pair of antennas. 

```
Usage: test_vectors [OPTIONS]

Options:
  -f, --fname <FNAME>      Name of file to output [default: radio_data.txt]
  -a, --ant <ANT>          Number of antennas [default: 8]
  -b, --bits <BITS>        Number of ADC bits [default: 1]
  -s, --samples <SAMPLES>  Number of samples [default: 1024]
  -h, --help               Print help
  -V, --version            Print version
```

The data are saved in a file called radio_data.txt (by default) in IQIQIQIQ format. The correlations are currently printed to the screen, for example

```
0,0 = Complex { re: 42353, im: 0 }
0,1 = Complex { re: 398, im: -771 }
0,2 = Complex { re: 35, im: -162 }
0,3 = Complex { re: 254, im: -289 }
0,4 = Complex { re: -1873, im: -2402 }
0,5 = Complex { re: -1029, im: -629 }
0,6 = Complex { re: 913, im: -233 }
0,7 = Complex { re: -509, im: -628 }
1,1 = Complex { re: 39953, im: 0 }
1,2 = Complex { re: 1154, im: -607 }
1,3 = Complex { re: 538, im: 423 }
1,4 = Complex { re: -1048, im: -1866 }
1,5 = Complex { re: 16, im: 328 }
1,6 = Complex { re: 1215, im: 410 }
1,7 = Complex { re: -449, im: -424 }
2,2 = Complex { re: 40182, im: 0 }
2,3 = Complex { re: 887, im: -347 }
2,4 = Complex { re: 984, im: -2153 }
2,5 = Complex { re: 988, im: -1648 }
2,6 = Complex { re: -831, im: 101 }
2,7 = Complex { re: -113, im: -709 }
3,3 = Complex { re: 40414, im: 0 }
3,4 = Complex { re: 101, im: -1217 }
3,5 = Complex { re: -1674, im: 483 }
3,6 = Complex { re: 1533, im: -687 }
3,7 = Complex { re: -160, im: -725 }
4,4 = Complex { re: 41678, im: 0 }
4,5 = Complex { re: -1485, im: 1073 }
4,6 = Complex { re: -735, im: -1278 }
4,7 = Complex { re: -2524, im: -1066 }
5,5 = Complex { re: 42349, im: 0 }
5,6 = Complex { re: -470, im: -760 }
5,7 = Complex { re: 155, im: 866 }
6,6 = Complex { re: 40864, im: 0 }
6,7 = Complex { re: 1549, im: -1017 }
7,7 = Complex { re: 41223, im: 0 }
```

