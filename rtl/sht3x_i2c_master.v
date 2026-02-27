module sht3x_i2c_master (
    input  wire clk,
    input  wire rst_n,
    output reg  scl_out,
    output reg  sda_out,
    input  wire sda_in,
    output reg [15:0] raw_temp,
    output reg [15:0] raw_hum,
    output reg valid,
    output reg conv_active
);

    // =============================
    // 100kHz generator (50MHz / 500)
    // =============================
    reg [8:0] clk_div;
    wire tick = (clk_div == 249);

    always @(posedge clk or negedge rst_n)
        if(!rst_n) clk_div <= 0;
        else clk_div <= tick ? 0 : clk_div + 1;

    // =============================
    // 15ms wait counter
    // =============================
    reg [19:0] wait_cnt;

    // =============================
    // FSM
    // =============================
    reg [4:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift;
    reg [2:0] byte_cnt;

    localparam
        IDLE=0,
        START1=1,
        SEND_ADDR_W=2,
        SEND_CMD_MSB=3,
        SEND_CMD_LSB=4,
        STOP1=5,
        WAIT=6,
        START2=7,
        SEND_ADDR_R=8,
        READ_BYTES=9,
        STOP2=10,
        DONE=11;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
            scl_out <= 1;
            sda_out <= 1;
            valid <= 0;
            conv_active <= 0;
            wait_cnt <= 0;
        end
        else if(tick) begin

            case(state)

            // -----------------------------
            IDLE:
            begin
                valid <= 0;
                state <= START1;
            end

            // -----------------------------
            START1:
            begin
                sda_out <= 0;
                scl_out <= 1;
                shift <= 8'h88; // 0x44 write
                bit_cnt <= 7;
                state <= SEND_ADDR_W;
            end

            // -----------------------------
            SEND_ADDR_W,
            SEND_CMD_MSB,
            SEND_CMD_LSB,
            SEND_ADDR_R:
            begin
                scl_out <= 0;
                sda_out <= shift[bit_cnt];
                scl_out <= 1;

                if(bit_cnt == 0) begin
                    bit_cnt <= 7;

                    if(state == SEND_ADDR_W) begin
                        shift <= 8'h24; // MSB
                        state <= SEND_CMD_MSB;
                    end
                    else if(state == SEND_CMD_MSB) begin
                        shift <= 8'h00; // LSB
                        state <= SEND_CMD_LSB;
                    end
                    else if(state == SEND_CMD_LSB) begin
                        state <= STOP1;
                    end
                    else if(state == SEND_ADDR_R) begin
                        byte_cnt <= 0;
                        state <= READ_BYTES;
                    end
                end
                else
                    bit_cnt <= bit_cnt - 1;
            end

            // -----------------------------
            STOP1:
            begin
                sda_out <= 1;
                scl_out <= 1;
                wait_cnt <= 0;
                conv_active <= 1;
                state <= WAIT;
            end

            // -----------------------------
            WAIT:
            begin
                wait_cnt <= wait_cnt + 1;
                if(wait_cnt >= 750000) begin
                    conv_active <= 0;
                    state <= START2;
                end
            end

            // -----------------------------
            START2:
            begin
                sda_out <= 0;
                shift <= 8'h89; // read
                bit_cnt <= 7;
                state <= SEND_ADDR_R;
            end

            // -----------------------------
            READ_BYTES:
            begin
                scl_out <= 0;
                sda_out <= 1;
                scl_out <= 1;

                if(byte_cnt == 0)
                    raw_temp[15-bit_cnt] <= sda_in;
                else if(byte_cnt == 1)
                    raw_temp[7-bit_cnt] <= sda_in;
                else if(byte_cnt == 3)
                    raw_hum[15-bit_cnt] <= sda_in;
                else if(byte_cnt == 4)
                    raw_hum[7-bit_cnt] <= sda_in;

                if(bit_cnt == 0) begin
                    bit_cnt <= 7;
                    byte_cnt <= byte_cnt + 1;

                    if(byte_cnt == 5)
                        state <= STOP2;
                end
                else
                    bit_cnt <= bit_cnt - 1;
            end

            // -----------------------------
            STOP2:
            begin
                sda_out <= 1;
                scl_out <= 1;
                state <= DONE;
            end

            // -----------------------------
            DONE:
            begin
                valid <= 1;
                state <= WAIT;
            end

            endcase
        end
    end

endmodule        

                                                                                                                                   /*module sht3x_i2c_master (
    input  wire clk,
    input  wire rst_n,
    output reg  scl_out,
    output reg  sda_out,
    input  wire sda_in,
    output reg [15:0] raw_temp,
    output reg [15:0] raw_hum,
    output reg valid,
    output reg conv_active
);

    // =============================
    // 100kHz Tick Generator
    // =============================
    reg [8:0] clk_cnt;
    wire tick = (clk_cnt == 249);

    always @(posedge clk or negedge rst_n)
        if (!rst_n) clk_cnt <= 0;
        else clk_cnt <= tick ? 0 : clk_cnt + 1;

    // =============================
    // Delay for 15ms wait
    // =============================
    reg [19:0] wait_cnt;

    // =============================
    // FSM
    // =============================
    reg [3:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;

    localparam IDLE=0,
               START=1,
               SEND=2,
               ACK=3,
               WAIT=4,
               REP_START=5,
               READ=6,
               STOP=7,
               DONE=8;

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n) begin
            state <= IDLE;
            scl_out <= 1;
            sda_out <= 1;
            raw_temp <= 0;
            raw_hum <= 0;
            valid <= 0;
            conv_active <= 0;
        end
        else if(tick) begin

            case(state)

            // =============================
            IDLE: begin
                valid <= 0;
                shift_reg <= 8'h88;   // Address + Write
                bit_cnt <= 7;
                state <= START;
            end

            // =============================
            START: begin
                sda_out <= 0;         // SDA LOW
                scl_out <= 1;
                state <= SEND;
            end

            // =============================
            SEND: begin
                scl_out <= 0;
                sda_out <= ~shift_reg[bit_cnt]; // Correct inversion
                scl_out <= 1;

                if(bit_cnt == 0)
                    state <= ACK;
                else
                    bit_cnt <= bit_cnt - 1;
            end

            // =============================
            ACK: begin
                scl_out <= 0;
                sda_out <= 1; // Release SDA
                scl_out <= 1;

                if(sda_in) begin
                    state <= STOP; // No ACK
                end
                else begin
                    shift_reg <= 8'h24; // Command MSB
                    bit_cnt <= 7;
                    state <= SEND;
                end
            end

            // =============================
            WAIT: begin
                wait_cnt <= wait_cnt + 1;
                if(wait_cnt == 750000) begin
                    wait_cnt <= 0;
                    shift_reg <= 8'h89; // Read
                    bit_cnt <= 7;
                    state <= REP_START;
                end
            end

            // =============================
            REP_START: begin
                sda_out <= 0;
                state <= SEND;
            end

            // =============================
            READ: begin
                scl_out <= 0;
                sda_out <= 1;   // Release
                scl_out <= 1;

                raw_temp[bit_cnt] <= sda_in;

                if(bit_cnt == 0)
                    state <= STOP;
                else
                    bit_cnt <= bit_cnt - 1;
            end

            // =============================
            STOP: begin
                scl_out <= 1;
                sda_out <= 1;
                state <= DONE;
            end

            // =============================
            DONE: begin
                valid <= 1;
                state <= WAIT;
            end

            endcase
        end
    end

endmodule   */