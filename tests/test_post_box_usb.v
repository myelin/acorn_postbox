`timescale 1ns/10ps

module test;

    // Clock period, ns
    parameter CLOCK_PERIOD = 21;  // 48 MHz

    // Pulse width, gap and break delay
    parameter PWID  = 500;
    parameter PGAP  = 500;
    parameter BREAK = 25000;    // 25us

    parameter SPIGAP = CLOCK_PERIOD * 4;  // 8MHz SPI = 48MHz / 4

    // time constants
    localparam USEC = 1000;
    localparam MSEC = 1000000;

    // Output waveform file for this test
    initial begin
        $dumpfile("tests/test_post_box_usb.lxt2");
        $dumpvars(0, test);
    end

    // 48MHz reference clock
    reg refclk;
    initial
        refclk = 1'b0;
    always
        #(CLOCK_PERIOD/2) refclk = !refclk;

    // POST port interface
    reg testreq;
    wire testack;
    wire testack_noe;
    initial testreq = 1'b0;

    // SPI
    reg spi_cs = 1'b1;
    reg spi_sck = 1'b0;
    reg spi_mosi = 1'b1;
    wire spi_miso;

    // Misc inputs and outputs
    reg reset_in = 1'b0;
    wire target_reset_noe;

    reg target_power_3v = 1'b1;
    wire target_power_out;

    wire hotswap_noe;


    // Transmit interface is omitted, display adapters always tx 0x00

    // Instantiate the module we're testing
    post_box_usb t(
        .fpga_clock_48mhz(refclk),
        .reset_in(reset_in),
        .target_power_out(target_power_out),

        .fpga_spi_cs(spi_cs),
        .fpga_spi_sck(spi_sck),
        .fpga_spi_mosi(spi_mosi),
        .fpga_spi_miso(spi_miso),

        .testreq_3v(testreq),
        .testack_noe(testack_noe),
        .target_reset_noe(target_reset_noe),
        .target_power_3v(target_power_3v),
        .hotswap_noe(hotswap_noe)
    );

    assign testack = !testack_noe;


`include "tasks.v"

    reg spi_sent_byte;
    reg spi_received_byte;
    reg [7:0] spi_data;

    // Input shift register, receives data sent in response to an INPUT req
    reg [7:0] input_sr;
    initial input_sr = 0;
    always @(posedge testreq) #100 input_sr <= {input_sr[6:0], testack};

    // Testbench
    initial begin
        // Startup delay
        #25

        $display("\n### Testing post_box_usb");

        // Four pulses to initialise the FSM to a known state
        $display("\n### Init FSM with 4 pulses");
        pulsebreak(4);

        $display("\n### Verify nothing buffered");
        // Nothing should be sent or received here
        // spi_txn(have_byte, have_space, input_byte -> sent_byte, received_byte, output_byte)
        spi_txn(0, 1, 0, spi_sent_byte, spi_received_byte, spi_data);
        `assert(!spi_sent_byte, "Initial SPI transaction sent a byte");
        `assert(!spi_received_byte, "Initial SPI transaction received a byte");

        $display("\n### Test output transaction: target wants to send to the interface");
        // Three pulses for OUTPUT
        pulsebreak(3);
        `assert(lastAck == 1'b1, "Output-ready was not received when expected.");
        // Now send the byte as series of one and two pulses
        outbyte(8'ha8);

        // Try sending another byte; expect no output-ready
        pulsebreak(3);
        `assert(lastAck == 1'b0, "Output-ready received right after receiving a byte, when the buffer should be full.");

        // Now we should be able to get the first byte with an SPI transaction
        spi_txn(0, 1, 0, spi_sent_byte, spi_received_byte, spi_data);
        `assert(!spi_sent_byte, "SPI transaction unexpectedly sent a byte");
        `assert(spi_received_byte, "SPI transaction should have received a byte");
        `assert(spi_data == 8'ha8, "SPI data incorrect; expected a8");

        // Now try an input, although we expect the buffer to be empty
        $display("\n### Try an input; expect no input-ready");
        pulsebreak(4);
        `assert(lastAck == 1'b0, "Input-ready received when not expected");

        $display("\n### Testing that the input accepts a byte over SPI");
        // Make sure the DUT has a byte in its tx buffer (for the next INPUT from the target)
        spi_txn(1, 1, 0, spi_sent_byte, spi_received_byte, spi_data);
        `assert(spi_sent_byte, "Should have sent a byte to DUT");

        $display("\n### Verify that a second byte is not accepted as the tx buffer should not be full");
        spi_txn(1, 1, 0, spi_sent_byte, spi_received_byte, spi_data);
        `assert(!spi_sent_byte, "DUT tx buffer should be full but sent a byte");
        pulsebreak(12);  // Clear buffer again

        $display("\n### Testing that 12 pulses from the target will clear the tx buffer");
        // Clear interface with 12 pulses
        pulsebreak(12);

        $display("\n### Verify that the interface can now accept a new byte (the 12 pulses did clear it)");
        spi_txn(1, 1, 0, spi_sent_byte, spi_received_byte, spi_data);
        `assert(spi_sent_byte, "Should have sent a byte to DUT");

        $display("\n### Send 0x42 over SPI, then expect it to show up over input");
        spi_txn(1, 1, 8'h42, spi_sent_byte, spi_received_byte, spi_data);
        pulsebreak(12);
        $display("input shifter: %b (%x)", input_sr, input_sr);
        `assert(input_sr == 8'h42, "Input shifter value incorrect");

        $display("\n### Send 0xc3 over SPI, then expect it to show up over input");
        spi_txn(1, 1, 8'hc3, spi_sent_byte, spi_received_byte, spi_data);
        pulsebreak(12);
        $display("input shifter: %b (%x)", input_sr, input_sr);
        `assert(input_sr == 8'hc3, "Input shifter value incorrect");

        $display("\n### Test chained input (writes to target): 12, ff, 34");
        spi_txn(1, 1, 8'h12, spi_sent_byte, spi_received_byte, spi_data);
        pulse(12);
        `assert(input_sr == 8'h12, "Input shifter value incorrect");
        spi_txn(1, 1, 8'hff, spi_sent_byte, spi_received_byte, spi_data);
        pulse(9);
        `assert(input_sr == 8'hff, "Input shifter value incorrect");
        spi_txn(1, 1, 8'h34, spi_sent_byte, spi_received_byte, spi_data);
        pulse(9);
        `assert(input_sr == 8'h34, "Input shifter value incorrect");
        pulse(1);
        `assert(lastAck == 1'b0, "Input-ready received when not expected");

        $display("\n### TODO look at the RISC OS code and see if there's anything interesting to test from there");

        $display("OK!  post_box_usb test completed. reqcount=%0d, time=%0d", reqcount, $time);

        #(5*USEC);
        $finish;
    end

endmodule
