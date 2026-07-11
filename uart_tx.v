// UART transmitter with a busy flag: start must be pulsed for exactly one
// cycle while busy is low; the module ignores start while a transmission
// is already in progress, so the caller can't accidentally retrigger it.
module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1x,   // pulses once per baud period
    input  wire [7:0] data,
    input  wire       start,     // 1-cycle pulse to begin transmitting
    output reg        tx,
    output reg        busy,
    output reg  [1:0] state
);

    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    reg [2:0] bit_cnt;
    reg [7:0] data_reg;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            tx       <= 1'b1;    // idle line is high
            busy     <= 1'b0;
            bit_cnt  <= 3'b0;
            data_reg <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    bit_cnt <= 3'b0;
                    if (start && !busy) begin
                        data_reg <= data;  // latch data at the moment of start
                        busy     <= 1'b1;
                        state    <= START;
                    end
                end

                START: if (tick_1x) begin
                    tx    <= 1'b0;
                    state <= DATA;
                end

                DATA: if (tick_1x) begin
                    tx <= data_reg[bit_cnt];
                    if (bit_cnt == 3'b111)
                        state <= STOP;
                    else
                        bit_cnt <= bit_cnt + 1;
                end

                STOP: if (tick_1x) begin
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule