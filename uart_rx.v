module uart_rx (rx, baud, state, data);
    input rx;
    output reg [7:0] data;
    input baud;
    output reg [1:0] state;
    reg [2:0]bit_cnt;

    initial begin
        state = 2'b00;
        data = 8'b0;
        bit_cnt = 3'b001;
    end

    always @ (posedge baud)
    case (state)
    2'b00: //Idle
    begin
        data <= 8'b0;
        if (rx==0)
        state <= 2'b01;
        else
        state <= 2'b00;
    end
    2'b01: begin //Start
        bit_cnt <= 3'b001;
        data[0] = rx;
        state <= 2'b10;
    end
    2'b10: //Data
    begin
        data[bit_cnt] <= rx;
        bit_cnt <= bit_cnt + 1;
        if (bit_cnt == 3'b111)
            state <= 2'b11;
    end
    2'b11: begin
        bit_cnt <= 3'b001;
        if (rx == 1)
        state <= 2'b00;
    end
    endcase

endmodule