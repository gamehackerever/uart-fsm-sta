// Top-level UART: wires the baud generator into the RX and TX modules.
module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       rx,
    output wire        tx,

    input  wire [7:0] tx_data,
    input  wire        tx_start,
    output wire         tx_busy,

    output wire [7:0]  rx_data,
    output wire         rx_data_valid
);

    wire tick_8x, tick_1x;

    baud_gen #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) baud_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .tick_8x (tick_8x),
        .tick_1x (tick_1x)
    );

    uart_rx rx_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .baud_tick  (tick_8x),
        .data       (rx_data),
        .data_valid (rx_data_valid),
        .state      ()
    );

    uart_tx tx_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .tick_1x (tick_1x),
        .data    (tx_data),
        .start   (tx_start),
        .tx      (tx),
        .busy    (tx_busy),
        .state   ()
    );

endmodule