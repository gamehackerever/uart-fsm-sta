// Parameterized baud rate generator.
// tick_8x pulses at 8x the baud rate -> used by uart_rx for majority-vote oversampling.
// tick_1x pulses once every 8 tick_8x pulses (i.e. at the baud rate) -> used by uart_tx
// to advance exactly one bit per baud period.
module baud_gen #(
    parameter CLK_FREQ   = 50_000_000,
    parameter BAUD_RATE  = 9600,
    parameter OVERSAMPLE = 8
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick_8x,
    output reg  tick_1x
);

    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * OVERSAMPLE);

    integer           clk_count;
    reg  [2:0]         os_count;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count <= 0;
            os_count  <= 3'd0;
            tick_8x   <= 1'b0;
            tick_1x   <= 1'b0;
        end else begin
            tick_8x <= 1'b0;
            tick_1x <= 1'b0;

            if (clk_count == DIVISOR - 1) begin
                clk_count <= 0;
                tick_8x   <= 1'b1;

                if (os_count == 3'd7) begin
                    os_count <= 3'd0;
                    tick_1x  <= 1'b1;
                end else begin
                    os_count <= os_count + 1'b1;
                end
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

endmodule