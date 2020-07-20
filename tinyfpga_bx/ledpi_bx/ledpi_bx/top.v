module top (
    input CLK,  // 16 MHz clock
    output PIN_1,
    output PIN_2,
    input PIN_3,  // SPI serial clock
    input PIN_4,  // SPI MOSI
    output PIN_5,
    output PIN_6,
    output PIN_7,
    output PIN_8,
    output PIN_9,
    input PIN_10,  // SPI chip select
    input PIN_11,  // SPI MISO
    output PIN_16,
    output PIN_17,
    output PIN_18,
    output PIN_19,
    output PIN_20,
    output PIN_21,
    output PIN_22
);
    assign USBPU = 0;  // Disable USB to avoid failed enumeration message

    // LED matrix inputs
    reg m_R1 = 0;
    reg m_G1 = 0;
    reg m_B1 = 0;
    reg m_R2 = 0;
    reg m_G2 = 0;
    reg m_B2 = 0;
    reg m_A = 0;
    reg m_B = 0;
    reg m_C = 0;
    reg m_D = 0;
    reg m_clk = 0;
    reg m_stb = 0;  // Strobe AKA latch (LAT) - marks end of row
    reg m_oe = 0;

    // We write two rows at a time: the `row`th and `row+16`th rows
    reg[3:0] row = 0;  // Current row on the matrix being written to (0-31)
    reg[5:0] col = 0;  // Current column on the matrix being written to (0-63)
    reg[1:0] disp_block = 0;  // Current block (group of 8 rows) on the matrix being written to (0-3)
    reg[1:0] recv_block = 0;  // Current block being written to RAM from received SPI data
    reg[5:0] display_step = 0;  // Step for the state machine that writes to the display
    reg[5:0] ram_step = 0;  // Step for the state machine that copies SPI data to RAM
    reg[7:0] pwm_counter = 0;
    
    // RGB bytes for the current two sets of LEDs being selected by `row` and `col`
    reg[7:0] red1 = 0;
    reg[7:0] grn1 = 0;
    reg[7:0] blu1 = 0;
    reg[7:0] red2 = 0;
    reg[7:0] grn2 = 0;
    reg[7:0] blu2 = 0;

    // Clock signals
    reg ram_in_clk;  // Clock for writing SPI data to RAM
    reg ram_out_clk;  // Clock for sending display signals to the LED matrix

    // matrix_data[double buffer (0-1)][row (0-31)][column (0-63)][RGB (0-2)][byte (0-255)]
    // reg[7:0] matrix_data[0:0][31:0][63:0][2:0];
    reg[7:0] received_data;  // TODO: make sure the size of this and the module's output are compatible
    reg[15:0] max_index = (64 * 32 * 3 * 8) - 1;  // Index of the last bit we care about
    // TODO: add functionality to make sure we received a complete set of data before flipping the double buffer
    reg[6:0] recv_counter = 0;  // Increases every time we receive a chunk of SPI data, wraps to 0 at 96
    reg[15:0] recv_index = 0;  // Index of the bit currently being written to RAM
    reg[15:0] disp_index = 0;  // Index of the bit currently being written to the display
    // Double buffer - one buffer is being written to with data from SPI while the other is being used
    // to write to the display. 0 = buffer "a", 1 = buffer "b". Always read from the active buffer
    // and write to the inactive buffer.
    // TODO: currently not used!
    reg buffer_a = 0;  // Is buffer "a" the active buffer? If not, it's "b" - duh

    // Embedded block RAM
    // We're using the 512x8 configuration. It's split up by color and is grouped into rows of 8, which
    // I'll refer to as blocks: 8 rows of 64 LEDs (one color only) = 512. Then there are two sets of
    // that memory for double buffering (buffers a and b).
    // TODO: do both *CLKE and *E need to be turned off?
    SB_RAM512x8 red_block0_a(
        .RDATA(red1),          .RADDR(disp_index - (512*0)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 0 &&  buffer_a), .RE(disp_block == 0 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*0)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 0 && !buffer_a), .WE(recv_block == 0 && !buffer_a));
    SB_RAM512x8 red_block0_b(
        .RDATA(red1),          .RADDR(disp_index - (512*0)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 0 && !buffer_a), .RE(disp_block == 0 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*0)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 0 &&  buffer_a), .WE(recv_block == 0 &&  buffer_a));

    SB_RAM512x8 red_block1_a(
        .RDATA(red1),          .RADDR(disp_index - (512*1)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 1 &&  buffer_a), .RE(disp_block == 1 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*1)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 1 && !buffer_a), .WE(recv_block == 1 && !buffer_a));
    SB_RAM512x8 red_block1_b(
        .RDATA(red1),          .RADDR(disp_index - (512*1)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 1 && !buffer_a), .RE(disp_block == 1 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*1)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 1 &&  buffer_a), .WE(recv_block == 1 &&  buffer_a));

    SB_RAM512x8 red_block2_a(
        .RDATA(red2),          .RADDR(disp_index - (512*2)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 2 &&  buffer_a), .RE(disp_block == 2 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*2)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 2 && !buffer_a), .WE(recv_block == 2 && !buffer_a));
    SB_RAM512x8 red_block2_b(
        .RDATA(red2),          .RADDR(disp_index - (512*2)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 2 && !buffer_a), .RE(disp_block == 2 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*2)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 2 &&  buffer_a), .WE(recv_block == 2 &&  buffer_a));

    SB_RAM512x8 red_block3_a(
        .RDATA(red2),          .RADDR(disp_index - (512*3)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 3 &&  buffer_a), .RE(disp_block == 3 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*3)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 3 && !buffer_a), .WE(recv_block == 3 && !buffer_a));
    SB_RAM512x8 red_block3_b(
        .RDATA(red2),          .RADDR(disp_index - (512*3)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 3 && !buffer_a), .RE(disp_block == 3 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*3)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 3 &&  buffer_a), .WE(recv_block == 3 &&  buffer_a));

    SB_RAM512x8 grn_block0_a(
        .RDATA(grn1),          .RADDR(disp_index - (512*4)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 0 &&  buffer_a), .RE(disp_block == 0 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*4)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 0 && !buffer_a), .WE(recv_block == 0 && !buffer_a));
    SB_RAM512x8 grn_block0_b(
        .RDATA(grn1),          .RADDR(disp_index - (512*4)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 0 && !buffer_a), .RE(disp_block == 0 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*4)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 0 &&  buffer_a), .WE(recv_block == 0 &&  buffer_a));

    SB_RAM512x8 grn_block1_a(
        .RDATA(grn1),          .RADDR(disp_index - (512*5)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 1 &&  buffer_a), .RE(disp_block == 1 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*5)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 1 && !buffer_a), .WE(recv_block == 1 && !buffer_a));
    SB_RAM512x8 grn_block1_b(
        .RDATA(grn1),          .RADDR(disp_index - (512*5)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 1 && !buffer_a), .RE(disp_block == 1 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*5)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 1 &&  buffer_a), .WE(recv_block == 1 &&  buffer_a));

    SB_RAM512x8 grn_block2_a(
        .RDATA(grn2),          .RADDR(disp_index - (512*6)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 2 &&  buffer_a), .RE(disp_block == 2 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*6)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 2 && !buffer_a), .WE(recv_block == 2 && !buffer_a));
    SB_RAM512x8 grn_block2_b(
        .RDATA(grn2),          .RADDR(disp_index - (512*6)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 2 && !buffer_a), .RE(disp_block == 2 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*6)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 2 &&  buffer_a), .WE(recv_block == 2 &&  buffer_a));

    SB_RAM512x8 grn_block3_a(
        .RDATA(grn2),          .RADDR(disp_index - (512*7)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 3 &&  buffer_a), .RE(disp_block == 3 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*7)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 3 && !buffer_a), .WE(recv_block == 3 && !buffer_a));
    SB_RAM512x8 grn_block3_b(
        .RDATA(grn2),          .RADDR(disp_index - (512*7)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 3 && !buffer_a), .RE(disp_block == 3 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*7)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 3 &&  buffer_a), .WE(recv_block == 3 &&  buffer_a));

    SB_RAM512x8 blu_block0_a(
        .RDATA(blu1),          .RADDR(disp_index - (512*8)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 0 &&  buffer_a), .RE(disp_block == 0 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*8)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 0 && !buffer_a), .WE(recv_block == 0 && !buffer_a));
    SB_RAM512x8 blu_block0_b(
        .RDATA(blu1),          .RADDR(disp_index - (512*8)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 0 && !buffer_a), .RE(disp_block == 0 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*8)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 0 &&  buffer_a), .WE(recv_block == 0 &&  buffer_a));

    SB_RAM512x8 blu_block1_a(
        .RDATA(blu1),          .RADDR(disp_index - (512*9)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 1 &&  buffer_a), .RE(disp_block == 1 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*9)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 1 && !buffer_a), .WE(recv_block == 1 && !buffer_a));
    SB_RAM512x8 blu_block1_b(
        .RDATA(blu1),          .RADDR(disp_index - (512*9)),  .RCLK(ram_out_clk), .RCLKE(disp_block == 1 && !buffer_a), .RE(disp_block == 1 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*9)),  .WCLK(ram_in_clk),  .WCLKE(recv_block == 1 &&  buffer_a), .WE(recv_block == 1 &&  buffer_a));

    SB_RAM512x8 blu_block2_a(
        .RDATA(blu2),          .RADDR(disp_index - (512*10)), .RCLK(ram_out_clk), .RCLKE(disp_block == 2 &&  buffer_a), .RE(disp_block == 2 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*10)), .WCLK(ram_in_clk),  .WCLKE(recv_block == 2 && !buffer_a), .WE(recv_block == 2 && !buffer_a));
    SB_RAM512x8 blu_block2_b(
        .RDATA(blu2),          .RADDR(disp_index - (512*10)), .RCLK(ram_out_clk), .RCLKE(disp_block == 2 && !buffer_a), .RE(disp_block == 2 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*10)), .WCLK(ram_in_clk),  .WCLKE(recv_block == 2 &&  buffer_a), .WE(recv_block == 2 &&  buffer_a));

    SB_RAM512x8 blu_block3_a(
        .RDATA(blu2),          .RADDR(disp_index - (512*11)), .RCLK(ram_out_clk), .RCLKE(disp_block == 3 &&  buffer_a), .RE(disp_block == 3 &&  buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*11)), .WCLK(ram_in_clk),  .WCLKE(recv_block == 3 && !buffer_a), .WE(recv_block == 3 && !buffer_a));
    SB_RAM512x8 blu_block3_b(
        .RDATA(blu2),          .RADDR(disp_index - (512*11)), .RCLK(ram_out_clk), .RCLKE(disp_block == 3 && !buffer_a), .RE(disp_block == 3 && !buffer_a),
        .WDATA(received_data), .WADDR(recv_index - (512*11)), .WCLK(ram_in_clk),  .WCLKE(recv_block == 3 &&  buffer_a), .WE(recv_block == 3 &&  buffer_a));

    always @(posedge CLK) begin
        pwm_counter <= pwm_counter + 1;
        
        case(display_step)
            0:  // Prepare row
            begin
                col <= 0;
                //m_clk <= 0;
                //m_stb <= 0;
                m_A <= row[0];
                m_B <= row[1];
                m_C <= row[2];
                m_D <= row[3];
                m_oe <= 1;  // Turn off output so we can clock in data
                display_step <= 10;
            end
            
            10:  // Write to row
            begin
                m_R1 <= (red1 > pwm_counter);
                m_G1 <= (grn1 > pwm_counter);
                m_B1 <= (blu1 > pwm_counter);
                m_R2 <= (red2 > pwm_counter);
                m_G2 <= (grn2 > pwm_counter);
                m_B2 <= (blu2 > pwm_counter);
                
                m_clk <= !m_clk;
                if (m_clk == 1) begin
                    if (col >= 63) begin
                        display_step <= 20;
                        m_R1 <= 0;
                        m_G1 <= 0;
                        m_B1 <= 0;
                        m_R2 <= 0;
                        m_G2 <= 0;
                        m_B2 <= 0;
                    end
                    col <= col + 1;
                end
            end
            
            20:  // Latch the data
            begin
                m_stb <= !m_stb;  // Latch data in
                display_step <= 30;
            end
            
            30:  // Enable the output, and get ready to write to the next row
            begin
                m_oe <= 0;
                row <= row + 1;
                // Check if row will wrap back to 0 next clock
                if (row >= 31) begin
                    disp_block <= 0;
                else
                    // No wrap will occur, anticipate what the row will be next clock
                    disp_block <= (row + 1) / 8;
                end
                display_step <= 0;
            end
            
            default: display_step <= 0;
        endcase

        case(ram_step)
            0:  // Idle
                if (something) begin
                    // We've received new data over the SPI bus!
                    if (recv_counter >= 95) begin
                        recv_counter <= 0;
                        recv_block <= 0;
                    else
                        recv_counter <= recv_counter + 1;
                        // Right now, these two are always the same number
                        recv_block <= recv_counter + 1;
                    end
                    ram_step <= 10;
                end

            10:  // Write the new data to RAM
                // TODO

            default: ram_step <= 0;
        endcase
        
        // TODO: use `!buffer_a` once we actually start using the double buffer
        //matrix_data[buffer_a] <= received_data;
    end

    
    SPISlave spi(
        .clk(CLK),
        .sck(PIN_3),
        .cs(PIN_10),
        .mosi(PIN_4),
        .miso(PIN_11),
        .received_data(received_data));
    
    assign PIN_1 = 1'bz;  // TODO: what is this for?
    assign PIN_2 = m_R1;
    assign PIN_5 = m_G1;
    assign PIN_6 = m_B1;
    assign PIN_7 = m_R2;
    assign PIN_8 = m_G2;
    assign PIN_9 = m_B2;
    assign PIN_19 = m_A;
    assign PIN_20 = m_B;
    assign PIN_16 = m_C;
    assign PIN_17 = m_D;
    assign PIN_18 = m_clk;
    assign PIN_21 = m_stb;
    assign PIN_22 = m_oe;
endmodule
// TODO: we're not using this
module SimplePWM(
    input clk,
    input [11:0] PWM_in,
    output PWM_out
);
    reg [11:0] cnt;
    always @(posedge clk) begin
        cnt <= cnt + 1;  // Free running counter
    end
    assign PWM_out = (PWM_in > cnt);  // Comparator
endmodule
// TODO: why is this set to 21??
module SPISlave #(parameter DATA_BITS = 21)(
    input clk,
    input sck,
    input cs,
    input mosi,
    output miso,
    output reg [(DATA_BITS - 1):0] received_data
);
    reg [2:0] sck_reg;
    reg [2:0] cs_reg;
    reg [1:0] mosi_reg;
    
    // SPI
    reg [(DATA_BITS - 1):0] miso_ii;
    reg [(DATA_BITS - 1):0] data;
    reg [(DATA_BITS - 1):0] _received_data;
    wire cs_active = (!cs_reg[1]);
    wire cs_becoming_active = (cs_reg[2:1] == 2'b10);
    wire cs_becoming_inactive = (cs_reg[2:1] == 2'b01);
    wire sck_rising_edge = (sck_reg[2:1] == 2'b01);
    wire sck_falling_edge = (sck_reg[2:1] == 2'b10);
    
    always @(posedge clk) begin
        sck_reg <= {sck_reg[1:0], sck};
        cs_reg <= {cs_reg[1:0], cs};
        mosi_reg <= {mosi_reg[0], mosi};
        if (cs_becoming_active) begin
            data <= 0;
            miso_ii <= 0;
        end
        if (cs_becoming_inactive) begin
            _received_data <= data;
            miso_ii <= 0;
        end
        if (cs_active && sck_falling_edge) begin
            // Send back the data we got last time
            miso_ii <= miso_ii + 1;
            if (miso_ii > (DATA_BITS - 1)) begin
                miso_ii <= 0;
            end
        end
        if (cs_active && sck_rising_edge) begin
            data <= {data[(DATA_BITS - 2):0], mosi_reg[1]};
        end
    end
    assign received_data = _received_data;
    assign miso = _received_data[(DATA_BITS - 1) - miso_ii];
endmodule
