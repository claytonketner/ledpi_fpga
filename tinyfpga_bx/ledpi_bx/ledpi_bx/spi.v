// TODO: may want to increase the DATA_BITS per SPI packet in order to
// increase data transfer rate
module SPISlave #(parameter DATA_BITS = 8)(
    input clk,
    input sck,  // Data is transferred on rising edge
    input cs,  // Active low
    input mosi,
    output miso,
    output reg [(DATA_BITS - 1):0] received_data
);
    reg [1:0] sck_reg = 0;
    reg [1:0] cs_reg = 2'b11;
    
    // SPI
    reg [(DATA_BITS - 1):0] miso_ii = 0;
    reg [(DATA_BITS - 1):0] data = 0;
    reg [(DATA_BITS - 1):0] _received_data = 0;
    wire cs_active = (!cs_reg[0]);
    wire cs_becoming_active = (cs_reg[1:0] == 2'b10);
    wire cs_becoming_inactive = (cs_reg[1:0] == 2'b01);
    wire sck_rising_edge = (sck_reg[1:0] == 2'b01);
    
    always @(posedge clk) begin
        sck_reg <= {sck_reg[0], sck};
        cs_reg <= {cs_reg[0], cs};
        // The if statements below will all be delayed one clock cycle
        if (cs_becoming_active) begin
            data <= 0;
            miso_ii <= 0;
        end
        if (cs_becoming_inactive) begin
            received_data <= data;
            miso_ii <= 0;
        end
        if (cs_active && sck_rising_edge) begin
            data <= {data[(DATA_BITS - 2):0], mosi};
        end
    end
endmodule
