`timescale 1ps/1ps
module uart_tb();

wire tx;
wire [1:0] state_tx, state_rx;
reg baud, start_bit;
reg [7:0] data_in;
wire [7:0] data_out;

uart_tx uart_tx_inst(tx, baud, state_tx, data_in, start_bit);
uart_rx uart_rx_inst(tx, baud, state_rx, data_out);

initial baud = 0;

always #10 baud = !baud;

initial begin
    $dumpfile("uart_wf.vcd");
    $dumpvars(0, uart_tb);

    data_in = 0; start_bit = 0; #60; 

    data_in = 8'b10001000;
    start_bit = 1; #20;
    start_bit = 0; #220;

    data_in = 8'b11001001;
    start_bit = 1; #20;
    start_bit = 0; #220;

    data_in = 8'b11111011;
    start_bit = 1; #20;
    start_bit = 0; #220;

    data_in = 8'b11011111;
    start_bit = 1; #20;
    start_bit = 0; #220;

    data_in = 8'b11101101;
    start_bit = 1; #20;
    start_bit = 0; #220;

    data_in = 8'b11001010;
    start_bit = 1; #20;
    start_bit = 0; #220;
    #300;

    $finish;

end

endmodule