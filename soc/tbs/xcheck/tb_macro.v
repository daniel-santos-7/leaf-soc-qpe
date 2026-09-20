// Reference run: drives the *vendor* model (ram.v) with the shared stimulus and
// dumps QA/QB once per cycle.  Compiled with +define+UNIT_DELAY so the specify
// block (path delays plus the $setuphold/$recrem checks) is bypassed and the
// model runs in its functional, near-zero-delay flavour -- which is the flavour
// the VHDL twin reproduces.
`timescale 1ns/1ps

module tb_macro;

   reg [10:0] AA, AB;
   reg [15:0] DA, DB, BWEBA, BWEBB;
   reg        WEBA, CEBA, WEBB, CEBB;
   reg        CLK;

   wire [15:0] QA, QB;

   integer stim, out, r, cycle;
   integer aa, da, bweba, weba, ceba, ab, db, bwebb, webb, cebb;

   TSDN65LPA2048X16M8M dut (
      .AA(AA), .DA(DA), .BWEBA(BWEBA), .WEBA(WEBA), .CEBA(CEBA), .CLKA(CLK),
      .AB(AB), .DB(DB), .BWEBB(BWEBB), .WEBB(WEBB), .CEBB(CEBB), .CLKB(CLK),
      .AMA(11'b0), .DMA(16'b0), .BWEBMA(16'hFFFF), .WEBMA(1'b1), .CEBMA(1'b1),
      .AMB(11'b0), .DMB(16'b0), .BWEBMB(16'hFFFF), .WEBMB(1'b1), .CEBMB(1'b1),
      .AWT(1'b0), .BIST(1'b0), .CLKM(1'b0),
      .QA(QA), .QB(QB));

   initial begin
      CLK = 1'b0;
      AA = 0; DA = 0; BWEBA = 16'hFFFF; WEBA = 1'b1; CEBA = 1'b1;
      AB = 0; DB = 0; BWEBB = 16'hFFFF; WEBB = 1'b1; CEBB = 1'b1;

      stim = $fopen("stimulus.txt", "r");
      out  = $fopen("out_verilog.txt", "w");
      if (stim == 0) begin
         $display("ERROR: cannot open stimulus.txt");
         $finish;
      end

      cycle = 0;
      // Inputs change at the start of the 10 ns cycle, the clock rises 5 ns
      // later and the outputs are sampled 4 ns after that -- far away from any
      // edge, so the comparison never depends on delta-cycle ordering.
      forever begin
         r = $fscanf(stim, "%d %d %d %d %d %d %d %d %d %d\n",
                     aa, da, bweba, weba, ceba, ab, db, bwebb, webb, cebb);
         if (r != 10) begin
            $fclose(out);
            $fclose(stim);
            $display("tb_macro: %0d cycles written to out_verilog.txt", cycle);
            $finish;
         end

         AA = aa[10:0]; DA = da[15:0]; BWEBA = bweba[15:0];
         WEBA = weba[0]; CEBA = ceba[0];
         AB = ab[10:0]; DB = db[15:0]; BWEBB = bwebb[15:0];
         WEBB = webb[0]; CEBB = cebb[0];

         #5 CLK = 1'b1;
         #4 $fwrite(out, "%b %b\n", QA, QB);
         #1 CLK = 1'b0;
         cycle = cycle + 1;
      end
   end

endmodule
