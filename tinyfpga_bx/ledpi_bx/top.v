module top (
    input CLK,    // 16MHz clock
);
    // drive USB pull-up resistor to '0' to disable USB
    assign USBPU = 0;
endmodule
