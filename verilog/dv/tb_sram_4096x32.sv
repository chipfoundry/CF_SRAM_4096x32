`timescale 1ns/1ps

module tb_sram_4096x32;
    localparam integer WORDS = 4096;
    localparam integer CLK_HALF_PERIOD_NS = 5;

    reg         wb_clk_i = 1'b0;
    reg         wb_rst_i = 1'b0;
    reg         wbs_cyc_i = 1'b0;
    reg         wbs_stb_i = 1'b0;
    reg         wbs_we_i = 1'b0;
    reg  [3:0]  wbs_sel_i = 4'b0;
    reg  [31:0] wbs_adr_i = 32'b0;
    reg  [31:0] wbs_dat_i = 32'b0;
    wire        wbs_ack_o;
    wire [31:0] wbs_dat_o;
    supply1 VPWR;
    supply0 VGND;

    reg [31:0] reference_memory [0:WORDS-1];
    reg        reference_valid [0:WORDS-1];

    integer checks = 0;
    integer errors = 0;
    integer transactions = 0;
    integer seed = 32'h4096_0032;
    integer random_iterations = 2000;
    integer sweep_words = WORDS;
    integer i;
    integer j;
    integer random_state;
    reg [31:0] observed;
    reg [31:0] expected;
    reg [31:0] signature;
    reg [31:0] random_word;
    reg [31:0] random_data;
    reg [3:0]  random_select;

`ifdef GATE_LEVEL
    CF_SRAM_4096x32 dut (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        .VPWR(VPWR),
        .VGND(VGND)
    );
`else
    CF_SRAM_4096x32_wb_wrapper dut (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o)
`ifdef USE_POWER_PINS
        ,
        .VPWR(VPWR),
        .VGND(VGND)
`endif
    );
`endif

    always #CLK_HALF_PERIOD_NS wb_clk_i = ~wb_clk_i;

    function automatic [31:0] merge_bytes;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0] select;
        integer byte_index;
        begin
            merge_bytes = old_value;
            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                if (select[byte_index])
                    merge_bytes[byte_index*8 +: 8] =
                        new_value[byte_index*8 +: 8];
        end
    endfunction

    function automatic [31:0] word_address;
        input integer index;
        begin
            word_address = index << 2;
        end
    endfunction

    task automatic fail;
        input [8*160-1:0] message;
        begin
            errors = errors + 1;
            $display("ERROR: %0s at time %0t", message, $time);
        end
    endtask

    task automatic check;
        input condition;
        input [8*160-1:0] message;
        begin
            checks = checks + 1;
            if (condition !== 1'b1)
                fail(message);
        end
    endtask

    task automatic drive_idle;
        begin
            wbs_cyc_i = 1'b0;
            wbs_stb_i = 1'b0;
            wbs_we_i = 1'b0;
            wbs_sel_i = 4'b0;
            wbs_adr_i = 32'b0;
            wbs_dat_i = 32'b0;
        end
    endtask

    task automatic wb_write;
        input [31:0] address;
        input [31:0] data;
        input [3:0] select;
        integer word_index;
        begin
            @(negedge wb_clk_i);
            wbs_adr_i = address;
            wbs_dat_i = data;
            wbs_sel_i = select;
            wbs_we_i = 1'b1;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b1, "write did not receive ACK");
            transactions = transactions + 1;
            word_index = address[13:2];
            if (reference_valid[word_index])
                reference_memory[word_index] =
                    merge_bytes(reference_memory[word_index], data, select);
            else if (select == 4'hf) begin
                reference_memory[word_index] = data;
                reference_valid[word_index] = 1'b1;
            end
            @(negedge wb_clk_i);
            drive_idle();
            #0.2;
            check(wbs_ack_o === 1'b1,
                  "ACK changed before the clock edge ending a transaction");
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "write ACK did not clear");
            check(wbs_dat_o === 32'b0, "write/idle data output is not zero");
        end
    endtask

    task automatic wb_read_raw;
        input [31:0] address;
        output [31:0] data;
        begin
            @(negedge wb_clk_i);
            wbs_adr_i = address;
            wbs_dat_i = 32'b0;
            wbs_sel_i = 4'hf;
            wbs_we_i = 1'b0;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;
            @(posedge wb_clk_i);
            #3.5;
            check(wbs_ack_o === 1'b1, "read did not receive ACK");
            check(!$isunknown(wbs_dat_o), "read returned X/Z");
            data = wbs_dat_o;
            transactions = transactions + 1;
            @(negedge wb_clk_i);
            drive_idle();
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "read ACK did not clear");
            check(wbs_dat_o === 32'b0, "idle data output is not zero");
        end
    endtask

    task automatic wb_read_check;
        input [31:0] address;
        integer word_index;
        reg [31:0] data;
        begin
            word_index = address[13:2];
            wb_read_raw(address, data);
            if (!reference_valid[word_index])
                fail("testbench attempted to check an uninitialized word");
            else if (data !== reference_memory[word_index]) begin
                $display("READ MISMATCH address=%08x expected=%08x actual=%08x",
                         address, reference_memory[word_index], data);
                fail("read data mismatch");
            end
            checks = checks + 1;
        end
    endtask

    task automatic test_invalid_cycles;
        begin
            $display("TEST invalid Wishbone cycles");
            @(negedge wb_clk_i);
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b0;
            wbs_we_i = 1'b0;
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "CYC without STB generated ACK");
            check(wbs_dat_o === 32'b0, "CYC without STB drove read data");

            @(negedge wb_clk_i);
            wbs_cyc_i = 1'b0;
            wbs_stb_i = 1'b1;
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "STB without CYC generated ACK");
            check(wbs_dat_o === 32'b0, "STB without CYC drove read data");
            @(negedge wb_clk_i);
            drive_idle();
        end
    endtask

    task automatic test_reset;
        begin
            $display("TEST reset");
            drive_idle();
            wb_rst_i = 1'b1;
            #0.2;
            check(wbs_ack_o === 1'b0, "asynchronous reset did not clear ACK");
            repeat (2) @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "ACK asserted during reset");
            @(negedge wb_clk_i);
            wb_rst_i = 1'b0;

            wbs_adr_i = word_address(0);
            wbs_dat_i = 32'hfeed_0000;
            wbs_sel_i = 4'hf;
            wbs_we_i = 1'b1;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b1,
                  "active transaction did not assert ACK before reset");
            reference_memory[0] = 32'hfeed_0000;
            reference_valid[0] = 1'b1;
            transactions = transactions + 1;
            #1;
            wb_rst_i = 1'b1;
            #0.2;
            check(wbs_ack_o === 1'b0,
                  "asynchronous reset did not clear an active ACK");
            @(negedge wb_clk_i);
            drive_idle();
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "ACK asserted while reset remained high");
            @(negedge wb_clk_i);
            wb_rst_i = 1'b0;
        end
    endtask

    task automatic test_boundaries;
        integer boundaries [0:7];
        begin
            $display("TEST bank boundaries and isolation");
            boundaries[0] = 0;
            boundaries[1] = 1023;
            boundaries[2] = 1024;
            boundaries[3] = 2047;
            boundaries[4] = 2048;
            boundaries[5] = 3071;
            boundaries[6] = 3072;
            boundaries[7] = 4095;
            for (i = 0; i < 8; i = i + 1)
                wb_write(word_address(boundaries[i]),
                         32'hb000_0000 ^ boundaries[i], 4'hf);
            for (i = 7; i >= 0; i = i - 1)
                wb_read_check(word_address(boundaries[i]));
        end
    endtask

    task automatic test_byte_enables;
        integer address_index;
        reg [31:0] before_zero_select;
        begin
            $display("TEST all byte-enable combinations");
            for (j = 0; j < 16; j = j + 1) begin
                address_index = 16 + j;
                wb_write(word_address(address_index), 32'h1020_3040 ^ j, 4'hf);
                before_zero_select = reference_memory[address_index];
                wb_write(word_address(address_index),
                         32'ha5b6_c7d8 ^ (j * 32'h0101_0101), j[3:0]);
                wb_read_check(word_address(address_index));
                if (j == 0)
                    check(reference_memory[address_index] === before_zero_select,
                          "zero-select write changed scoreboard state");
            end
        end
    endtask

    task automatic test_address_aliases;
        reg [31:0] alias_data;
        begin
            $display("TEST byte alignment and upper-address aliasing");
            wb_write(32'h0000_0100, 32'h1357_9bdf, 4'hf);
            for (j = 0; j < 4; j = j + 1)
                wb_read_check(32'h0000_0100 + j);
            wb_read_raw(32'h1234_4100, alias_data);
            check(alias_data === 32'h1357_9bdf,
                  "upper address bits did not alias as implemented");
        end
    endtask

    task automatic test_back_to_back;
        integer base;
        begin
            $display("TEST back-to-back Wishbone writes");
            base = 64;
            @(negedge wb_clk_i);
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;
            wbs_we_i = 1'b1;
            wbs_sel_i = 4'hf;
            for (j = 0; j < 8; j = j + 1) begin
                wbs_adr_i = word_address(base + j);
                wbs_dat_i = 32'hba00_0000 + j;
                @(posedge wb_clk_i);
                #0.2;
                check(wbs_ack_o === 1'b1,
                      "back-to-back transaction lost ACK");
                reference_memory[base + j] = 32'hba00_0000 + j;
                reference_valid[base + j] = 1'b1;
                transactions = transactions + 1;
                if (j != 7)
                    @(negedge wb_clk_i);
            end
            @(negedge wb_clk_i);
            drive_idle();
            @(posedge wb_clk_i);
            #0.2;
            check(wbs_ack_o === 1'b0, "back-to-back ACK did not clear");
            for (j = 0; j < 8; j = j + 1)
                wb_read_check(word_address(base + j));
        end
    endtask

    task automatic test_march;
        begin
            $display("TEST March-style full memory sweep (%0d words)",
                     sweep_words);
            for (i = 0; i < sweep_words; i = i + 1)
                wb_write(word_address(i), 32'h0000_0000, 4'hf);
            for (i = 0; i < sweep_words; i = i + 1) begin
                wb_read_check(word_address(i));
                wb_write(word_address(i), 32'hffff_ffff, 4'hf);
            end
            for (i = sweep_words - 1; i >= 0; i = i - 1) begin
                wb_read_check(word_address(i));
                wb_write(word_address(i), 32'ha5a5_5a5a ^ i, 4'hf);
            end
            for (i = sweep_words - 1; i >= 0; i = i - 1)
                wb_read_check(word_address(i));
        end
    endtask

    task automatic test_random;
        integer random_index;
        begin
            $display("TEST seeded random traffic (%0d operations, seed=%0d)",
                     random_iterations, seed);
            random_state = seed;
            for (i = 0; i < random_iterations; i = i + 1) begin
                random_word = $random(random_state);
                random_index = random_word[11:0];
                random_data = $random(random_state);
                random_select = $random(random_state);
                if (!reference_valid[random_index] || random_word[12]) begin
                    if (!reference_valid[random_index])
                        random_select = 4'hf;
                    wb_write(word_address(random_index), random_data,
                             random_select);
                end else begin
                    wb_read_check(word_address(random_index));
                end
            end
        end
    endtask

    task automatic calculate_signature;
        begin
            signature = 32'h811c_9dc5;
            for (i = 0; i < WORDS; i = i + 1)
                if (reference_valid[i])
                    signature =
                        (signature ^ reference_memory[i] ^ i) * 32'h0100_0193;
        end
    endtask

    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            reference_memory[i] = 32'b0;
            reference_valid[i] = 1'b0;
        end

        if ($value$plusargs("SEED=%d", seed))
            $display("Using requested seed %0d", seed);
        if ($test$plusargs("QUICK")) begin
            sweep_words = 128;
            random_iterations = 100;
        end
        if ($test$plusargs("VCD")) begin
            $dumpfile("build/sram_4096x32.vcd");
            $dumpvars(0, tb_sram_4096x32);
        end

`ifdef GATE_LEVEL
        $display("BEGIN CF_SRAM_4096x32 GATE-LEVEL REGRESSION");
`else
        $display("BEGIN CF_SRAM_4096x32 RTL REGRESSION");
`endif

        test_reset();
        test_invalid_cycles();
        test_boundaries();
        test_byte_enables();
        test_address_aliases();
        test_back_to_back();
        test_march();
        test_random();
        calculate_signature();

        $display("SUMMARY checks=%0d transactions=%0d errors=%0d signature=%08x seed=%0d",
                 checks, transactions, errors, signature, seed);
        if (errors == 0) begin
            $display("TEST_PASS");
            $finish;
        end else begin
            $display("TEST_FAIL");
            $fatal(1, "CF_SRAM_4096x32 regression failed");
        end
    end

    initial begin
        #2_000_000_000;
        $fatal(1, "global simulation timeout");
    end
endmodule
