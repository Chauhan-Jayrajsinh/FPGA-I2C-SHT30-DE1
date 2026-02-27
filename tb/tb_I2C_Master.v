`timescale 1ns / 1ps

module i2c_master_tb;

    // --- 1. Signal Declarations ---
    reg clk;
    reg rst_n;
    reg start;
    reg [6:0] addr;
    reg [7:0] data_in;
    
    wire scl;
    wire sda;
    wire done;
    wire ack_error;

    // --- 2. Instantiate the Unit Under Test (UUT) ---
    i2c_master uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .addr(addr),
        .data_in(data_in),
        .scl(scl),
        .sda(sda),
        .done(done),
        .ack_error(ack_error)
    );

    // --- 3. Pull-up Resistor Simulation ---
    // Mandatory for Open-Drain logic (4.7k resistors on board)
    pullup(sda);
    pullup(scl);

    // --- 4. Clock Generation (50 MHz) ---
    always #10 clk = ~clk;

    // --- 5. Slave (Sensor) Simulation Logic ---
    reg slave_ack_en = 0;
    
    // When slave_ack_en is High, pull SDA Low (ACK). 
    // Otherwise, release SDA (High-Z) to let Master control it.
    assign sda = (slave_ack_en) ? 1'b0 : 1'bz;

    // --- 6. Main Test Sequence ---
    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        start = 0;
        addr = 7'h50;      // Target Sensor Address (e.g., EEPROM)
        data_in = 8'hA5;   // Data Byte to Write (10100101)
        slave_ack_en = 0;

        // Reset the System
        #100 rst_n = 1;
        
        // --- Generate START Pulse ---
        // Hold high long enough for the Master FSM to catch it
        #100 start = 1;
        #2000 start = 0; 

        $display("------------------------------------------------");
        $display("Time: %t | Simulation Started: Writing 0xA5 to 0x50", $time);
        $display("------------------------------------------------");

        // --- Wait for Address Phase ---
        // CRITICAL FIX: We wait for 9 edges (1 Start Edge + 8 Address Bits)
        // This ensures we are perfectly aligned for the ACK slot.
        repeat(9) @(negedge scl);

        // --- Generate ACK 1 (Address) ---
        // Sensor acknowledges presence
        slave_ack_en = 1; // Pull SDA Low
        @(negedge scl);   // Hold it for the duration of the ACK clock pulse
        slave_ack_en = 0; // Release

        // --- Wait for Data Phase ---
        // Data phase has no START bit, so we just wait for 8 bits.
        repeat(8) @(negedge scl);

        // --- Generate ACK 2 (Data) ---
        // Sensor acknowledges receipt of data
        slave_ack_en = 1; // Pull SDA Low
        @(negedge scl);   // Hold it for the duration of the ACK clock pulse
        slave_ack_en = 0; // Release

        // --- Wait for Completion ---
        wait(done);
        
        // --- Check Results ---
        $display("------------------------------------------------");
        $display("Time: %t | Transaction Finished.", $time);
        
        if (ack_error == 0) 
            $display("RESULT: SUCCESS (Green LED) - Data Acknowledged.");
        else 
            $display("RESULT: FAILURE (Red LED) - NACK Received.");
        $display("------------------------------------------------");

        $stop;
    end

endmodule