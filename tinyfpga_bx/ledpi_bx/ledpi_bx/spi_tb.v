module spi_testbench ();
    initial begin
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_testbench);
    end

    reg clk, sck, cs, mosi;
    wire miso;
    wire [20:0] received_data;
    SPISlave spi (.clk(clk), .sck(sck), .cs(cs), .mosi(mosi), .miso(miso), .received_data(received_data));

    always begin
        #1;
        clk = !clk;
    end

    initial begin
        clk = 1;
        sck = 0;
        cs = 1;
        mosi = 0;


        // CS not active
        // No data should be recorded
        cs = 1;
        sck = 0;
        #4;
        mosi = 1;
        sck = 1;
        #4;
        sck = 0;
        #4;
        mosi = 0;
        sck = 1;
        #4;
        sck = 0;
        #4;


        // CS active
        // Data should be recorded
        cs = 0;
        sck = 0;
        #4;
        mosi = 1;
        sck = 1;
        #4;
        sck = 0;
        #4;
        mosi = 0;
        sck = 1;
        #4;
        sck = 0;
        #4;
        mosi = 1;
        sck = 1;
        #4;
        cs = 1;
        #4;  // Now `received_data` = 5


        // Second SPI packet arrives
        cs = 0;
        sck = 0;
        #4;
        mosi = 1;
        sck = 1;
        #4;
        sck = 0;
        #4;
        mosi = 1;
        sck = 1;
        #4;
        sck = 0;
        #4;
        mosi = 0;
        sck = 1;
        #4;
        sck = 0;
        #4;
        cs = 1;
        #4;  // Now `received_data` = 6


        $finish;
    end
endmodule
