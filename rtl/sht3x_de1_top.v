// ============================================================================
// Top Module for DE1 Cyclone II + SHT30

//  - Dual Mode Operation (SIM_MODE parameter)
//  - 2 second display toggle (Temperature <-> Humidity)
//  SIM_MODE = 1  --> Dummy values (25°C, 50%)
//  SIM_MODE = 0  --> SHT30 sensor via I2C
// ============================================================================

module sht3x_de1_top #(
    parameter SIM_MODE = 0   // ===== CHANGE THIS =====
                                // 1 = Simulation / Dummy mode
                                // 0 = Real SHT30 Sensor mode
)(
    input  wire       CLOCK_50,     // 50 MHz clock from DE1
    input  wire [3:0] KEY,          // KEY[0] = Reset (active low)

    output wire [6:0] HEX0,         // Rightmost 7-seg
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,

    output wire [9:0] LEDR,         // Red LEDs
    output wire [7:0] LEDG,         // Green LEDs

    inout  wire [1:0] GPIO_0        // GPIO_0[0] = SCL, GPIO_0[1] = SDA
);

    // =========================================================================
    // Reset Signal
    // =========================================================================
    wire reset_n =  KEY[0];

    // =========================================================================
    // I2C SECTION (Active only when SIM_MODE = 0)
    // =========================================================================

    wire scl_out, sda_out, sda_in;
    wire [15:0] raw_temp, raw_hum;
    wire data_valid;
    wire conv_active;

    generate
    if (SIM_MODE == 0) begin : REAL_SENSOR_MODE

        // --- Open Drain Configuration ---
        // Drive 0 to pull line LOW
        // Drive Z to release line (pull-up makes it HIGH)

        assign GPIO_0[0] = (scl_out) ? 1'bz : 1'b0;
        assign GPIO_0[1] = (sda_out) ? 1'bz : 1'b0;
        assign sda_in    = GPIO_0[1];

        // --- Instantiate I2C Master ---
        sht3x_i2c_master u_sht30 (
            .clk(CLOCK_50),
            .rst_n(reset_n),
            .scl_out(scl_out),
            .sda_out(sda_out),
            .sda_in(sda_in),
            .raw_temp(raw_temp),
            .raw_hum(raw_hum),
            .valid(data_valid),
            .conv_active(conv_active)
        );

    end
    else begin : SIMULATION_MODE

        // In simulation mode:
        // Release I2C lines completely (no bus activity)

        assign GPIO_0[0] = 1'bz;
        assign GPIO_0[1] = 1'bz;

    end
    endgenerate

    // =========================================================================
    // DATA SELECTION (Real Sensor or Dummy Values)
    // =========================================================================

    // When SIM_MODE = 1 --> Use fixed demo values
    // When SIM_MODE = 0 --> Use sensor raw values

    wire [7:0] temperature_value =
            (SIM_MODE) ? 8'd25 : raw_temp[15:8];

    wire [7:0] humidity_value =
            (SIM_MODE) ? 8'd50 : raw_hum[15:8];

    wire valid_signal  =
            (SIM_MODE) ? 1'b1 : data_valid;

    wire conversion_active =
            (SIM_MODE) ? 1'b0 : conv_active;

    // =========================================================================
    // BINARY TO BCD CONVERSION
    // =========================================================================

    wire [3:0] temp_tens, temp_ones;
    wire [3:0] hum_tens,  hum_ones;

    bin2bcd_8bit bcd_temp (
        .bin(temperature_value),
        .tens(temp_tens),
        .ones(temp_ones)
    );

    bin2bcd_8bit bcd_hum (
        .bin(humidity_value),
        .tens(hum_tens),
        .ones(hum_ones)
    );

    // =========================================================================
    // 7-SEGMENT DECODERS (Active LOW for DE1)
    // =========================================================================

    wire [6:0] seg_temp_tens, seg_temp_ones;
    wire [6:0] seg_hum_tens,  seg_hum_ones;

    seg7_decoder d1 (.bcd(temp_tens), .seg(seg_temp_tens));
    seg7_decoder d2 (.bcd(temp_ones), .seg(seg_temp_ones));
    seg7_decoder d3 (.bcd(hum_tens),  .seg(seg_hum_tens));
    seg7_decoder d4 (.bcd(hum_ones),  .seg(seg_hum_ones));

    // =========================================================================
    // DISPLAY TOGGLE LOGIC (2 seconds interval)
    // =========================================================================

    reg [26:0] display_counter;
    reg display_mode;   // 0 = Temperature, 1 = Humidity

    localparam TWO_SECONDS = 100_000_000; // 50MHz × 2

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            display_counter <= 0;
            display_mode <= 0;
        end
        else begin
            if (display_counter >= TWO_SECONDS-1) begin
                display_counter <= 0;
                display_mode <= ~display_mode;
            end
            else begin
                display_counter <= display_counter + 1;
            end
        end
    end

    // Turn OFF unused digits
    wire [6:0] OFF = 7'b1111111;

    assign HEX3 = (display_mode == 0) ? seg_temp_tens : OFF;
    assign HEX2 = (display_mode == 0) ? seg_temp_ones : OFF;
    assign HEX1 = (display_mode == 1) ? seg_hum_tens  : OFF;
    assign HEX0 = (display_mode == 1) ? seg_hum_ones  : OFF;

    // =========================================================================
    // ERROR WATCHDOG (Only active in Real Sensor Mode)
    // Turns LEDR[0] ON if no valid data for 3 seconds
    // =========================================================================

    reg [27:0] error_counter;
    reg error_flag;

    localparam THREE_SECONDS = 150_000_000; // 50MHz × 3

    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            error_counter <= 0;
            error_flag <= 0;
        end
        else if (valid_signal) begin
            error_counter <= 0;
            error_flag <= 0;
        end
        else if (!SIM_MODE) begin
            if (error_counter >= THREE_SECONDS)
                error_flag <= 1;
            else
                error_counter <= error_counter + 1;
        end
    end

    // =========================================================================
    // LED INDICATORS 
    // =========================================================================

    assign LEDG[0] = conversion_active;        // Conversion active indicator
    assign LEDG[1] = (display_mode == 0);      // ON = Temperature mode
    assign LEDR[0] = (SIM_MODE) ? 1'b0 : error_flag; // Error indicator

endmodule