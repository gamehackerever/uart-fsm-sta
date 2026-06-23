`timescale 1ps/1ps
module uart_tx_tb();

wire tx;
wire [1:0] state;
reg baud, start_bit;
reg [7:0] data;


uart_tx uart_tx_inst(tx, baud, state, data, start_bit);

initial baud = 0;

always #10 baud = !baud;

initial begin
    data = 0; start_bit = 0; #5;
    $dumpfile("uart_tx_wf.vcd");
    $dumpvars(0, uart_tx_tb);
    start_bit = 1; #20;
    data = 8'b00001000; #200;
    start_bit = 0; #200;

    start_bit = 1; #20;
    data = 8'b00101000; #200;
    start_bit = 0; #20;

    start_bit = 1; #20;
    data = 8'b11001010; #200;
    start_bit = 0; #20;

    start_bit = 1; #20;
    data = 8'b11001011; #200;
    start_bit = 0; #350;

    start_bit = 1; #20;
    data = 8'b101110; #200;
    start_bit = 0; #20;

    start_bit = 1; #20;
    data = 8'b00001100; #200;
    start_bit = 0; #20;

    #500;

    $finish;

end



endmodule