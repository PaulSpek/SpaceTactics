`timescale 1ns/1ps
module tb_cpu_bus;
    logic clk = 0;
    always #10 clk = ~clk;
    logic reset = 1;
    logic [15:0] rom_addr = 0;
    logic [7:0] rom_data = 0;
    logic rom_wr = 0;
    logic diag_sound = 0;
    wire [15:0] cpu_addr;
    wire [7:0] cpu_din, cpu_dout;
    wire m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
    wire irq_n, ce_pixel, hs, vs, de;
    wire [7:0] red, green, blue;
    wire signed [15:0] audio_sample;
    logic [2:0] divider = 0;
    always @(posedge clk) divider <= divider + 1'b1;
    wire cpu_ce = divider == 3'd7;

    tv80s #(.Mode(2)) cpu (
        .reset_n(!reset), .clk(clk), .cen(cpu_ce), .wait_n(1'b1),
        .int_n(irq_n), .nmi_n(1'b1), .busrq_n(1'b1),
        .busak_n(busak_n), .m1_n(m1_n), .mreq_n(mreq_n),
        .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .rfsh_n(rfsh_n),
        .halt_n(halt_n), .A(cpu_addr), .di(cpu_din), .dout(cpu_dout)
    );
    stactics_board board (
        .clk(clk), .reset(reset), .cpu_addr(cpu_addr), .cpu_dout(cpu_dout),
        .cpu_wr(cpu_ce && !mreq_n && !wr_n),
        .cpu_int_ack(!m1_n && !iorq_n), .cpu_din(cpu_din), .irq_n(irq_n),
        .in0(8'h7f), .in1(8'h3f), .in2(8'hf0), .in3(8'h7d),
        .joy_ud_n(2'b11), .diag_sound(diag_sound),
        .rom_wr(rom_wr), .rom_addr(rom_addr),
        .rom_data(rom_data), .ce_pixel(ce_pixel), .red(red),
        .green(green), .blue(blue), .hs(hs), .vs(vs), .de(de),
        .audio_sample(audio_sample)
    );

    task automatic load_byte(input [15:0] address, input [7:0] value);
        @(negedge clk);
        rom_addr = address;
        rom_data = value;
        rom_wr = 1;
        @(negedge clk);
        rom_wr = 0;
    endtask
    initial begin
        // MVI A,42; STA 400A; LDA 470A; STA 400B; HLT.
        load_byte(0, 8'h3e); load_byte(1, 8'h42);
        load_byte(2, 8'h32); load_byte(3, 8'h0a); load_byte(4, 8'h40);
        load_byte(5, 8'h3a); load_byte(6, 8'h0a); load_byte(7, 8'h47);
        load_byte(8, 8'h32); load_byte(9, 8'h0b); load_byte(10, 8'h40);
        load_byte(11, 8'h76);
        @(negedge clk);
        reset = 0;
        repeat (10000) begin
            @(negedge clk);
            if (!halt_n) begin
                if (board.work_ram[8'h0a] !== 8'h42 ||
                    board.work_ram[8'h0b] !== 8'h42)
                    $fatal(1, "CPU did not read/write mirrored work RAM");
                $display("PASS: 8080 program read ROM and wrote mirrored RAM");
                $finish;
            end
        end
        $fatal(1, "CPU did not reach HLT");
    end
endmodule
