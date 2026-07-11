`timescale 1ns/1ps

// Self-checking loopback test: tx is tied directly to rx, so every byte
// sent should come back out identical. Uses small CLK_FREQ/BAUD_RATE
// values purely to keep simulation time short -- doesn't affect the
// logic being tested.
module tb_uart_loopback;

    // NOTE: DIVISOR = CLK_FREQ / (BAUD_RATE * 8) must be comfortably larger
    // than the 2-cycle synchronizer delay, or the RX will sample stale
    // (pre-synchronizer) values near bit transitions. 1MHz/115200 gave a
    // DIVISOR of ~1 -- far too tight. 8MHz/115200 gives DIVISOR=8, plenty
    // of margin, while still keeping simulation time short.
    localparam CLK_FREQ  = 8_000_000;
    localparam BAUD_RATE = 115200;

    reg        clk   = 0;
    reg        rst_n = 0;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_data_valid;
    wire       serial_line;

    uart_top #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx            (serial_line),
        .tx            (serial_line),   // loopback
        .tx_data       (tx_data),
        .tx_start      (tx_start),
        .tx_busy       (tx_busy),
        .rx_data       (rx_data),
        .rx_data_valid (rx_data_valid)
    );

    always #62.5 clk = ~clk;  // 8 MHz -> 125ns period

    integer errors = 0;
    integer i;
    reg [7:0] test_vec [0:4];

    task send_byte(input [7:0] b);
        begin
            @ (posedge clk);
            tx_data  = b;
            tx_start = 1;
            @ (posedge clk);
            tx_start = 0;
            wait (tx_busy == 1'b0);
        end
    endtask

    initial begin
        $dumpfile("uart_loopback.vcd");
        $dumpvars(0, tb_uart_loopback);

        rst_n    = 0;
        tx_start = 0;
        tx_data  = 8'b0;
        #1000;
        rst_n = 1;
        #1000;

        test_vec[0] = 8'h00;
        test_vec[1] = 8'hFF;
        test_vec[2] = 8'hA5; // 10100101
        test_vec[3] = 8'h5A; // 01011010
        test_vec[4] = 8'h4B; // 'K' - arbitrary ascii byte

        for (i = 0; i < 5; i = i + 1) begin
            send_byte(test_vec[i]);
            wait (rx_data_valid == 1'b1);
            @ (posedge clk);
            if (rx_data !== test_vec[i]) begin
                $display("[%0t] MISMATCH: sent 0x%0h, received 0x%0h", $time, test_vec[i], rx_data);
                errors = errors + 1;
            end else begin
                $display("[%0t] OK: sent 0x%0h, received 0x%0h", $time, test_vec[i], rx_data);
            end
            #1000;
        end

        // --- Extra check: start pulsed while busy should be ignored, not
        // corrupt the byte already in flight. ---
        @ (posedge clk);
        tx_data  = 8'h3C;
        tx_start = 1;
        @ (posedge clk);
        tx_start = 0;
        // Immediately try to retrigger with a different byte while busy.
        repeat (3) @ (posedge clk);
        tx_data  = 8'hE7;   // should be ignored: busy is still high
        tx_start = 1;
        @ (posedge clk);
        tx_start = 0;
        wait (tx_busy == 1'b0);
        wait (rx_data_valid == 1'b1);
        @ (posedge clk);
        if (rx_data !== 8'h3C) begin
            $display("[%0t] BUSY-CONTENTION MISMATCH: expected 0x3c, got 0x%0h", $time, rx_data);
            errors = errors + 1;
        end else begin
            $display("[%0t] OK: busy contention correctly ignored, received 0x%0h", $time, rx_data);
        end

        if (errors == 0)
            $display("=== ALL TESTS PASSED ===");
        else
            $display("=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule