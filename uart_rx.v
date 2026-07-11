// UART receiver with:
//  - 2-flop synchronizer on the async rx input (fixes metastability risk)
//  - 8x-oversampled majority-vote bit sampling (robust to jitter/noise)
//  - one-cycle data_valid strobe when a byte has been fully received
module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,          // async serial input
    input  wire       baud_tick,   // pulses at 8x baud rate
    output reg  [7:0] data,
    output reg        data_valid,
    output reg  [1:0] state
);

    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    // ---- Clock-domain-crossing synchronizer -------------------------------
    // rx is asynchronous to clk. Sampling it directly risks metastability:
    // if rx changes right at the flop's setup/hold window, the output can
    // hover unpredictably before resolving. Two flops in series give the
    // signal a full clock period to settle before the FSM ever sees it.
    reg rx_meta, rx_sync;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    reg [2:0] bit_cnt;
    reg [2:0] smp_cnt;
    // 4 bits, not 3: vote+rx_sync can reach 8 when all 8 samples are '1'.
    // At 3 bits that sum truncates (8 -> 0), silently misreading a clean
    // '1' bit as '0'. This is exactly the kind of bug that only shows up
    // for specific data patterns and is easy to miss in a quick review.
    reg [3:0] vote;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            data       <= 8'b0;
            data_valid <= 1'b0;
            bit_cnt    <= 3'b0;
            smp_cnt    <= 3'b0;
            vote       <= 3'b0;
        end else begin
            data_valid <= 1'b0; // default low; only pulses high for 1 cycle below

            if (baud_tick) begin
                case (state)
                    IDLE: begin
                        smp_cnt <= 3'b0;
                        vote    <= 3'b0;
                        bit_cnt <= 3'b0;
                        if (rx_sync == 1'b0)
                            state <= START;
                    end

                    // Verify the start bit is really low across all 8 samples
                    // (rejects glitches that only pulled the line low briefly).
                    START: begin
                        if (smp_cnt == 3'b111) begin
                            smp_cnt <= 3'b0;
                            vote    <= 3'b0;
                            // include this final sample in the decision
                            if ((vote + rx_sync) >= 4'd4)
                                state <= IDLE;   // wasn't really a start bit
                            else
                                state <= DATA;
                        end else begin
                            vote    <= vote + rx_sync;
                            smp_cnt <= smp_cnt + 1;
                        end
                    end

                    // Sample each data bit 8 times, take a majority vote.
                    DATA: begin
                        if (smp_cnt == 3'b111) begin
                            smp_cnt       <= 3'b0;
                            vote          <= 3'b0;
                            data[bit_cnt] <= ((vote + rx_sync) >= 4'd4) ? 1'b1 : 1'b0;
                            if (bit_cnt == 3'b111)
                                state   <= STOP;
                            else
                                bit_cnt <= bit_cnt + 1;
                        end else begin
                            vote    <= vote + rx_sync;
                            smp_cnt <= smp_cnt + 1;
                        end
                    end

                    STOP: begin
                        if (smp_cnt == 3'b111) begin
                            smp_cnt    <= 3'b0;
                            vote       <= 3'b0;
                            bit_cnt    <= 3'b0;
                            state      <= IDLE;
                            data_valid <= 1'b1;   // byte is ready this cycle
                        end else begin
                            smp_cnt <= smp_cnt + 1;
                        end
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule