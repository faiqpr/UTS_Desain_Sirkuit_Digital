module top(
    input clk,

    output reg tm_cs,
    output tm_clk,
    inout  tm_dio
    );

    localparam HIGH = 1'b1, LOW = 1'b0;

    // Font Mapping Seven Segment (Active HIGH)
    localparam [6:0]
        S_0   = 7'b0111111,
        S_1   = 7'b0000110,
        S_2   = 7'b1011011,
        S_3   = 7'b1001111,
        S_4   = 7'b1100110,
        S_5   = 7'b1101101,
        S_6   = 7'b1111101,
        S_7   = 7'b0000111,
        S_8   = 7'b1111111,
        S_9   = 7'b1101111,
        S_DASH= 7'b1000000,
        S_T   = 7'b1111000, 
        S_E   = 7'b1111011, 
        S_BLK = 7'b0000000; 

    localparam [7:0]
        C_READ  = 8'b01000010,
        C_WRITE = 8'b01000000,
        C_DISP  = 8'b10001111,
        C_ADDR  = 8'b11000000;

    reg rst = HIGH;
    reg [5:0] instruction_step;
    reg [15:0] counter;

    // Counter Presisi 1 Detik (12 Juta siklus pada clock 12MHz iCESugar)
    reg [23:0] cnt_1s;
    wire tick_1s = (cnt_1s == 24'd11_999_999);

    // Variabel Mode dan Status Tombol
    reg [7:0] keys;
    reg [1:0] mode; // 0 = Kiri, 1 = Kanan, 2 = Ping-Pong (Bolak-Balik)

    // Logika Animasi LED (Larson Scanner)
    reg [7:0] larson;
    reg larson_dir;

    // Logika Pergeseran NIM
    reg [5:0] text_offset;
    reg shift_dir; 

    reg tm_rw;
    wire dio_in, dio_out;
    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) tm_dio_io (
        .PACKAGE_PIN(tm_dio),
        .OUTPUT_ENABLE(tm_rw),
        .D_IN_0(dio_in),
        .D_OUT_0(dio_out)
    );

    wire tm_latch, busy;
    wire [7:0] tm_data, tm_in;
    reg [7:0] tm_out;

    assign tm_in = tm_data;
    assign tm_data = tm_rw ? tm_out : 8'hZZ;

    tm1638 u_tm1638 (
        .clk(clk),
        .rst(rst),
        .data_latch(tm_latch),
        .data(tm_data),
        .rw(tm_rw),
        .busy(busy),
        .sclk(tm_clk),
        .dio_in(dio_in),
        .dio_out(dio_out)
    );

    // Fungsi Karakter NIM + Padding Kosong
    function [6:0] get_char;
        input [5:0] idx;
        begin
            case (idx)
                8:  get_char = S_2;
                9:  get_char = S_3;
                10: get_char = S_DASH;
                11: get_char = S_5;
                12: get_char = S_1;
                13: get_char = S_3;
                14: get_char = S_5;
                15: get_char = S_7;
                16: get_char = S_4;
                17: get_char = S_DASH;
                18: get_char = S_T;
                19: get_char = S_E;
                20: get_char = S_DASH;
                21: get_char = S_5;
                22: get_char = S_6;
                23: get_char = S_4;
                24: get_char = S_3;
                25: get_char = S_2;
                default: get_char = S_BLK; 
            endcase
        end
    endfunction

    function [6:0] get_digit;
        input [2:0] pos;
        reg [5:0] idx;
        begin
            idx = text_offset + pos;
            get_digit = get_char(idx);
        end
    endfunction

    task send_digit;
        input [6:0] segs;
        begin
            tm_latch <= HIGH;
            tm_out   <= {1'b0, segs};
        end
    endtask

    task send_led;
        input [2:0] dot;
        begin
            tm_latch <= HIGH;
            tm_out   <= {7'b0, larson[dot]};
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            instruction_step <= 6'b0;
            tm_cs <= HIGH;
            tm_rw <= HIGH;
            rst <= LOW;

            counter <= 0;
            cnt_1s <= 0;
            text_offset <= 0;
            shift_dir <= 0;

            keys <= 8'b0;
            mode <= 2; // Default Mode: Ping-Pong

            // Inisialisasi LED Larson
            larson_dir <= 0;
            larson <= 8'b00000001;

        end else begin
            
            // --- DETEKSI TOMBOL (S1, S2, S3) ---
            if (keys[7]) mode <= 0; // Tombol S1 (Kiri)
            if (keys[6]) mode <= 1; // Tombol S2 (Kanan)
            if (keys[5]) mode <= 2; // Tombol S3 (Ping-Pong)

            // --- ANIMASI 1 DETIK (LED & 7-SEGMENT) ---
            if (tick_1s) begin
                cnt_1s <= 0;
                
                // 1. Shift LED
                larson_dir <= larson[6] ? 0 : larson[1] ? 1 : larson_dir;
                if (larson_dir) larson <= {larson[6:0], larson[7]};
                else larson <= {larson[0], larson[7:1]};

                // 2. Shift NIM Teks Berdasarkan Mode
                if (mode == 0) begin
                     // Geser Bolak-Balik (Ping-Pong)
                    if (shift_dir == 0) begin
                        if (text_offset >= 26) shift_dir <= 1;
                        else text_offset <= text_offset + 1;
                    end else begin
                        if (text_offset == 0) shift_dir <= 0;
                        else text_offset <= text_offset - 1;
                    end

                end 
                else if (mode == 1) begin
                    // Geser Kiri Terus
                    if (text_offset >= 26) text_offset <= 0;
                    else text_offset <= text_offset + 1;
                end 
                else if (mode == 2) begin
                    // Geser Kanan Terus
                    if (text_offset == 0) text_offset <= 26;
                    else text_offset <= text_offset - 1;
                end
            end else begin
                cnt_1s <= cnt_1s + 1;
            end

            // --- STATE MACHINE PENGIRIMAN TM1638 ---
            if (counter[0] && ~busy) begin
                case (instruction_step)
                    0:  instruction_step <= 1;

                    // *** BACA TOMBOL (KEYS SCAN) ***
                    1:  begin {tm_cs, tm_rw} <= {LOW, HIGH}; instruction_step <= 2; end
                    2:  begin {tm_latch, tm_out} <= {HIGH, C_READ}; instruction_step <= 3; end
                    3:  begin tm_rw <= LOW; instruction_step <= 4; end // Jeda Aman: Ubah arah pin dulu tanpa Latch
                    4:  begin tm_latch <= HIGH; instruction_step <= 5; end // Trigger Baca Byte 1
                    5:  begin {keys[7], keys[3]} <= {tm_in[0], tm_in[4]}; instruction_step <= 6; end
                    6:  begin tm_latch <= HIGH; instruction_step <= 7; end
                    7:  begin {keys[6], keys[2]} <= {tm_in[0], tm_in[4]}; instruction_step <= 8; end
                    8:  begin tm_latch <= HIGH; instruction_step <= 9; end
                    9:  begin {keys[5], keys[1]} <= {tm_in[0], tm_in[4]}; instruction_step <= 10; end
                    10: begin tm_latch <= HIGH; instruction_step <= 11; end
                    11: begin {keys[4], keys[0]} <= {tm_in[0], tm_in[4]}; instruction_step <= 12; end
                    12: begin {tm_cs, tm_rw} <= {HIGH, HIGH}; instruction_step <= 13; end

                    // *** TAMPILAN DISPLAY (7-SEG & LED) ***
                    13: begin {tm_cs, tm_rw} <= {LOW, HIGH}; instruction_step <= 14; end
                    14: begin {tm_latch, tm_out} <= {HIGH, C_WRITE}; instruction_step <= 15; end
                    15: begin {tm_cs} <= {HIGH}; instruction_step <= 16; end

                    16: begin {tm_cs, tm_rw} <= {LOW, HIGH}; instruction_step <= 17; end
                    17: begin {tm_latch, tm_out} <= {HIGH, C_ADDR}; instruction_step <= 18; end

                    18: begin send_digit(get_digit(0)); instruction_step <= 19; end  // Digit 1
                    19: begin send_led(3'd0);           instruction_step <= 20; end  // LED 1
                    20: begin send_digit(get_digit(1)); instruction_step <= 21; end  // Digit 2
                    21: begin send_led(3'd1);           instruction_step <= 22; end // LED 2
                    22: begin send_digit(get_digit(2)); instruction_step <= 23; end // Digit 3
                    23: begin send_led(3'd2);           instruction_step <= 24; end // LED 3
                    24: begin send_digit(get_digit(3)); instruction_step <= 25; end // Digit 4
                    25: begin send_led(3'd3);           instruction_step <= 26; end // LED 4
                    26: begin send_digit(get_digit(4)); instruction_step <= 27; end // Digit 5
                    27: begin send_led(3'd4);           instruction_step <= 28; end // LED 5
                    28: begin send_digit(get_digit(5)); instruction_step <= 29; end // Digit 6
                    29: begin send_led(3'd5);           instruction_step <= 30; end // LED 6
                    30: begin send_digit(get_digit(6)); instruction_step <= 31; end // Digit 7
                    31: begin send_led(3'd6);           instruction_step <= 32; end // LED 7
                    32: begin send_digit(get_digit(7)); instruction_step <= 33; end // Digit 8
                    33: begin send_led(3'd7);           instruction_step <= 34; end // LED 8

                    34: begin {tm_cs} <= {HIGH}; instruction_step <= 35; end

                    35: begin {tm_cs, tm_rw} <= {LOW, HIGH}; instruction_step <= 36; end
                    36: begin {tm_latch, tm_out} <= {HIGH, C_DISP}; instruction_step <= 37; end
                    37: begin {tm_cs, instruction_step} <= {HIGH, 6'b0}; end

                    default: instruction_step <= 6'b0;
                endcase

            end else if (busy) begin
                tm_latch <= LOW;
            end

            counter <= counter + 1;
        end
    end
endmodule