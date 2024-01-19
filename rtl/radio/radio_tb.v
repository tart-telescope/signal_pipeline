
`timescale 1ns / 100ps

// Basic input module from a Max2769
module radio_tb();

    reg clk16 = 0;
    wire data_i, data_q;
    reg r_i, r_q;
    
    radio_dummy dut(clk16, r_i, r_q, data_i, data_q);

    always #1 clk16 = !clk16;
    
    initial begin
        $monitor("%b, %d", clk16, data_i);
        #300 $finish();
    end
endmodule
