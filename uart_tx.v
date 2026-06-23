module uart_tx (tx, baud, state, data, start_bit);
    output reg tx;
    input [7:0] data;
    input baud;
    output reg [1:0] state;
    input start_bit;
    reg [2:0]bit_cnt; 

    initial begin
        state = 2'b00;
        tx = 1'b1;
        bit_cnt = 3'b000;
    end

    always @ (posedge baud)
    case (state)
    2'b00: //Idle
    begin
        bit_cnt <= 3'b000;
        tx <= 1'b1;
        if (start_bit)
        state <= 2'b01;
        else
        state <= 2'b00;
    end
    2'b01: begin        //Start
        state <= 2'b10;
        tx <= 1'b0;
    end
    2'b10: //Data
    begin
        tx <= data[bit_cnt];
        bit_cnt <= bit_cnt + 1;
        if (bit_cnt == 3'b111)
            state <= 2'b11;
    end
    2'b11: begin
        tx <= 1'b1;
        state <= 2'b00;
    end
    endcase

endmodule