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
module SPISlave #(parameter DATA_BITS = 21)(
	input clk,
	input sck,
	input cs,
	input mosi,
	output miso,
	output wire [(DATA_BITS - 1):0] received_data
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
module ledpi_fpga (
	inout pin1,
	inout pin2,
	inout pin3_sn,
	inout pin4_mosi,
	inout pin5,
	inout pin6,
	inout pin7_done,
	inout pin8_pgmn,
	inout pin9_jtgnb,
	inout pin10_sda,
	inout pin11_scl,
	//inout pin12_tdo,
	//inout pin13_tdi,
	//inout pin14_tck,
	//inout pin15_tms,
	inout pin16,
	inout pin17,
	inout pin18_cs,
	inout pin19_sclk,
	inout pin20_miso,
	inout pin21,
	inout pin22
);
	wire clk;
	OSCH #(
		.NOM_FREQ("44.33")
	) internal_oscillator_inst (
		.STDBY(1'b0),
		.OSC(clk)
	);
	
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
	reg m_stb = 0;  // AKA latch (LAT) - marks end of row
	reg m_oe = 0;
	reg[3:0] row = 0;
	reg[5:0] col = 0;
	reg[4:0] iStep = 0;
	
	// matrix_data[double buffer (0-1)][row (0-31)][column (0-63)][RGB (0-2)][byte (0-255)]
	reg[7:0] matrix_data[0:0][31:0][63:0][2:0];
	wire[31:0][63:0][2:0][7:0] received_matrix_data;  // TODO: make sure the size of this and the module's output are compatible
	reg current_buffer = 0;  // Double buffer index for rgb data TODO: currently not used!
	reg[7:0] pwm_counter = 0;
	reg[7:0] brightness_counter = 0;
	reg[17:0] brightness_timer = 0;
	
	always @(posedge clk) begin
		pwm_counter <= pwm_counter + 1;
		brightness_timer <= brightness_timer + 1;
		if (brightness_timer == 0) begin
			brightness_counter <= brightness_counter + 1;
		end
		
		case(iStep)
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
				iStep <= 10;
			end
			
			10:  // Write to row
			begin
				m_R1 <= (matrix_data[current_buffer][row][col][0] > pwm_counter);
				m_G1 <= (matrix_data[current_buffer][row][col][1] > pwm_counter);
				m_B1 <= (matrix_data[current_buffer][row][col][2] > pwm_counter);
				m_R2 <= (matrix_data[current_buffer][row+16][col][0] > pwm_counter);
				m_G2 <= (matrix_data[current_buffer][row+16][col][1] > pwm_counter);
				m_B2 <= (matrix_data[current_buffer][row+16][col][2] > pwm_counter);
				
				m_clk <= !m_clk;
				if (m_clk == 1) begin
					if (col >= 63) begin
						iStep <= 20;
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
				iStep <= 30;
			end
			
			30:  // Enable the output, and get ready to write to the next row
			begin
				m_oe <= 0;
				row <= row + 1;
				iStep <= 0;
			end
			
			default: iStep <= 0;
		endcase
		
		// TODO: use `!current_buffer` once we actually start using the double buffer
		//matrix_data[current_buffer] <= received_matrix_data;
		
		// TEST DATA BEGIN
		matrix_data[0][0][0][0] <= 1;
		matrix_data[0][0][1][0] <= 5;
		matrix_data[0][0][2][0] <= 10;
		matrix_data[0][0][3][0] <= 15;
		matrix_data[0][0][4][0] <= 20;
		matrix_data[0][0][5][0] <= 25;
		matrix_data[0][0][6][0] <= 30;
		matrix_data[0][0][7][0] <= 35;
		matrix_data[0][0][8][0] <= 40;
		matrix_data[0][0][9][0] <= 45;
		matrix_data[0][0][10][0] <= 50;
		matrix_data[0][0][11][0] <= 60;
		matrix_data[0][0][12][0] <= 70;
		matrix_data[0][0][13][0] <= 80;
		matrix_data[0][0][14][0] <= 90;
		matrix_data[0][0][15][0] <= 100;
		matrix_data[0][0][16][0] <= 110;
		matrix_data[0][0][17][0] <= 120;
		matrix_data[0][0][18][0] <= 130;
		matrix_data[0][0][19][0] <= 140;
		matrix_data[0][0][20][0] <= 150;
		matrix_data[0][0][21][0] <= 160;
		matrix_data[0][0][22][0] <= 170;
		matrix_data[0][0][23][0] <= 180;
		matrix_data[0][0][24][0] <= 190;
		matrix_data[0][0][25][0] <= 200;
		matrix_data[0][0][26][0] <= 210;
		matrix_data[0][0][27][0] <= 220;
		matrix_data[0][0][28][0] <= 230;
		matrix_data[0][0][29][0] <= 240;
		matrix_data[0][0][30][0] <= 250;
		matrix_data[0][0][31][0] <= 255;
		matrix_data[0][0][32][0] <= 1;
		matrix_data[0][0][33][0] <= 2;
		matrix_data[0][0][34][0] <= 3;
		matrix_data[0][0][35][0] <= 4;
		matrix_data[0][0][36][0] <= 5;
		matrix_data[0][0][37][0] <= 6;
		matrix_data[0][0][38][0] <= 7;
		matrix_data[0][0][39][0] <= 8;
		matrix_data[0][0][40][0] <= 9;
		matrix_data[0][0][41][0] <= 10;
		matrix_data[0][0][42][0] <= 11;
		matrix_data[0][16][0][1] <= 10;
		matrix_data[0][16][1][1] <= 20;
		matrix_data[0][16][2][1] <= 30;
		matrix_data[0][16][3][1] <= 40;
		matrix_data[0][16][4][1] <= 50;
		matrix_data[0][16][5][1] <= 60;
		matrix_data[0][0][63][0] <= brightness_counter;
		matrix_data[0][1][63][1] <= brightness_counter;
		matrix_data[0][2][63][2] <= brightness_counter;
		// TEST DATA END
	end
	
	SPISlave spi(
		.clk(clk),
		.sck(pin3_sn),
		.cs(pin10_sda),
		.mosi(pin4_mosi),
		.miso(pin11_scl),
		.received_data(received_matrix_data));
	
	assign pin1 = 1'bz;
	assign pin2 = m_R1;
	assign pin5 = m_G1;
	assign pin6 = m_B1;
	assign pin7_done = m_R2;
	assign pin8_pgmn = m_G2;
	assign pin9_jtgnb = m_B2;
	assign pin19_sclk = m_A;
	assign pin20_miso = m_B;
	assign pin16 = m_C;
	assign pin17 = m_D;
	assign pin18_cs = m_clk;
	assign pin21 = m_stb;
	assign pin22 = m_oe;
endmodule