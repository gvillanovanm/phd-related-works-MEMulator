`timescale 1ns / 1ps

`define DDR4
// `define DDR3

// `define RowClone

module testbnch_DIMM(
       );
       
       parameter RANKS = 1;
       parameter CHIPS = 16;
       parameter BGWIDTH = 2;
       parameter BAWIDTH = 2;
       parameter ADDRWIDTH = 17;
       parameter COLWIDTH = 10;
       parameter DEVICE_WIDTH = 4; // x4, x8, x16 -> DQ width = Device_Width x BankGroups (Chips)
       parameter BL = 8; // Burst Length
       parameter CHWIDTH = 6; // Emulation Memory Cache Width
       
       localparam DQWIDTH = DEVICE_WIDTH*CHIPS; // 64 bits + 8 bits for ECC
       localparam BANKGROUPS = 2**BGWIDTH;
       localparam BANKSPERGROUP = 2**BAWIDTH;
       localparam ROWS = 2**ADDRWIDTH;
       localparam COLS = 2**COLWIDTH;
       
       localparam CHIPSIZE = (DEVICE_WIDTH*COLS*(ROWS/1024)*BANKSPERGROUP*BANKGROUPS)/(1024); // Mbit
       localparam DIMMSIZE = (CHIPSIZE*CHIPS)/(1024*8); // GB
       
       localparam tCK = 0.75;
       
       reg reset_n;
       reg ck2x;
       `ifdef DDR4
       reg ck_c;
       reg ck_t;
       `elsif DDR3
       reg ck_n;
       reg ck_p;
       `endif
       reg cke;
       reg [RANKS-1:0]cs_n;
       `ifdef DDR4
       reg act_n;
       `endif
       `ifdef DDR3
       reg ras_n;
       reg cas_n;
       reg we_n;
       `endif
       reg [ADDRWIDTH-1:0]A;
       reg [BAWIDTH-1:0]ba;
       `ifdef DDR4
       reg [BGWIDTH-1:0]bg;
       `endif
       wire [DQWIDTH-1:0]dq;
       reg [DQWIDTH-1:0]dq_reg;
       `ifdef DDR4
       wire [CHIPS-1:0]dqs_c;
       reg [CHIPS-1:0]dqs_c_reg;
       wire [CHIPS-1:0]dqs_t;
       reg [CHIPS-1:0]dqs_t_reg;
       `elsif DDR3
       wire [CHIPS-1:0]dqs_n;
       reg [CHIPS-1:0]dqs_n_reg;
       wire [CHIPS-1:0]dqs_p;
       reg [CHIPS-1:0]dqs_p_reg;
       `endif
       reg odt;
       `ifdef DDR4
       reg parity;
       `endif
       
       reg sync [BANKGROUPS-1:0][BANKSPERGROUP-1:0];
       
       reg writing;
       
       assign dq = (writing) ? dq_reg:{DQWIDTH{1'bZ}};
       assign dqs_c = (writing) ? dqs_c_reg:{CHIPS{1'bZ}};
       assign dqs_t = (writing) ? dqs_t_reg:{CHIPS{1'bZ}};
       
       DIMM #(.RANKS(RANKS),
       .CHIPS(CHIPS),
       .BGWIDTH(BGWIDTH),
       .BAWIDTH(BAWIDTH),
       .ADDRWIDTH(ADDRWIDTH),
       .COLWIDTH(COLWIDTH),
       .DEVICE_WIDTH(DEVICE_WIDTH),
       .BL(BL),
       .CHWIDTH(CHWIDTH)
       ) dut (
       .reset_n(reset_n),
       .ck2x(ck2x),
       `ifdef DDR4
       .ck_c(ck_c),
       .ck_t(ck_t),
       `elsif DDR3
       .ck_n(ck_n),
       .ck_p(ck_p),
       `endif
       .cke(cke),
       .cs_n(cs_n),
       `ifdef DDR4
       .act_n(act_n),
       `endif
       `ifdef DDR3
       .ras_n(ras_n),
       .cas_n(cas_n),
       .we_n(we_n),
       `endif
       .A(A),
       .ba(ba),
       `ifdef DDR4
       .bg(bg),
       `endif
       .dq(dq),
       `ifdef DDR4
       .dqs_c(dqs_c),
       .dqs_t(dqs_t),
       `elsif DDR3
       .dqs_n(dqs_n),
       .dqs_p(dqs_p),
       `endif
       .odt(odt),
       `ifdef DDR4
       .parity(parity),
       `endif
       .sync(sync)
       );
       
       always #(tCK) ck_t = ~ck_t;
       always #(tCK) ck_c = ~ck_c;
       always #(tCK*0.5) ck2x = ~ck2x;
       
       integer i, j; // loop variable
       
       initial
       begin
              // initialize all inputs
              reset_n = 0;
              ck_t = 1;
              ck_c = 0;
              ck2x = 1;
              cke = 1;
              cs_n = {RANKS{1'b1}};
              act_n = 1;
              A = {ADDRWIDTH{1'b0}};
              bg = 0;
              ba = 0;
              dq_reg = {DQWIDTH{1'b0}};
              dqs_t_reg = {CHIPS{1'b0}};
              dqs_c_reg = {CHIPS{1'b1}};
              odt = 0;
              parity = 0;
              writing = 0;
              for (i = 0; i < BANKGROUPS; i = i + 1)
              begin
                     for (j = 0; j < BANKSPERGROUP; j = j + 1)
                     begin
                            sync[i][j] = 0;
                     end
              end
              #tCK;
              
              // reset high
              reset_n = 1;
              cs_n = 1'b0;
              #(tCK*5);
              
              // activating
              act_n = 0;
              bg = 1;
              ba = 1;
              A = 17'b00000000000000001;
              #tCK;
              act_n = 1;
              A = 17'b00000000000000000;
              #(tCK*15); // tRCD
              #(tCK*15); // tCL
              
              // write
              #tCK;
              for (i = 0; i < BL; i = i + 1)
              begin
                     A = (i==0)? 17'b10000000000000010 : 17'b00000000000000000;
                     writing = 1;
                     dq_reg = {$urandom, $urandom, $urandom, $urandom, $urandom, $urandom, $urandom, $urandom, $urandom };
                     dqs_t_reg = {CHIPS{1'b1}};
                     dqs_c_reg = {CHIPS{1'b0}};
                     #tCK;
              end
              writing = 0;
              
              `ifdef RowClone
              #(tCK*5); // activating again for RowClone
              act_n = 0;
              bg = 1;
              ba = 1;
              A = 17'b00000000000000100;
              #tCK;
              act_n = 1;
              A = 17'b00000000000000000;
              #(tCK*15); // tRCD
              `endif
              
              // read
              #tCK;
              for (i = 0; i < BL; i = i + 1)
              begin
                     A = (i==0)? 17'b10100000000000010 : 17'b00000000000000000;
                     dq_reg = {DQWIDTH{1'b0}};
                     dqs_t_reg = {CHIPS{1'b0}};
                     dqs_c_reg = {CHIPS{1'b1}};
                     writing = 0;
                     #tCK;
              end
              
              // precharge and back to idle
              #tCK;
              #tCK;
              A = 17'b01000000000000000;
              #tCK;
              bg = 0;
              ba = 0;
              A = 17'b00000000000000000;
              #(16*tCK);
              $stop;
       end;
       
endmodule
