`timescale 1ps/1ps
module uart_rx_tb();

reg rx;
wire [1:0] state;
reg baud;
wire [7:0] data;


uart_rx uart_rx_inst(rx, baud, state, data);

initial baud = 1'b0;

always #10 baud = !baud;

initial begin
    $dumpfile("uart_rx_wf.vcd");
    $dumpvars(0, uart_rx_tb);
    
    rx = 1; #60;

    rx = 0; #20; //start
    rx = 1; #20; rx = 0; #20; rx = 1; #20; rx = 1; #20; rx = 1; #20; rx = 1; #20; rx = 0; #20; rx = 0; #20; //00111101 10111100
    rx = 1; #200; //Stop

    rx = 0; #20; //start
    rx = 0; #20; rx = 1; #20; rx = 0; #20; rx = 0; #20; rx = 0; #20; rx = 1; #20; rx = 0; #20; rx = 1; #20; //10100010
    rx = 1; #200; //Stop

    rx = 0; #20; //start
    rx = 0; #20; rx = 1; #20; rx = 1; #20; rx = 1; #20; rx = 0; #20; rx = 1; #20; rx = 0; #20; rx = 1; #20; //10101110
    rx = 1; #200; //Stop

    #200;

    $finish;

end



endmodule