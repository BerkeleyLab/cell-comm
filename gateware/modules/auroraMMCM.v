/*
 * MMCM to generate user_clk, sync_clk from tx_out_clk. Init_clk is buffered.
 */

module auroraMMCM # (
    parameter   FPGA_FAMILY     = "7series",
    parameter   MULT            =   14,
    parameter   DIVIDE          =   1,
    parameter   CLK_PERIOD      =   10.240,
    parameter   OUT0_DIVIDE     =   28,
    parameter   OUT1_DIVIDE     =   14,
    parameter   OUT2_DIVIDE     =   20,
    parameter   OUT3_DIVIDE     =   8
    ) (
    input  TX_CLK,
    input  TX_CLK_CLR,
    input  CLK_LOCKED,
    output USER_CLK,
    output SYNC_CLK,
    output TX_CLK_OUT,
    output MMCM_NOT_LOCKED);

generate
    if (FPGA_FAMILY != "7series" && FPGA_FAMILY != "ultrascaleplus") begin
    FPGA_FAMILY_unsupported error();
end
endgenerate

(* KEEP = "TRUE" *)    wire             clk_not_locked_i;
wire                                    sync_clk_i;
wire                                    user_clk_i;
wire                                    clkfbout_i;
wire                                    clkfbout;
wire                                    locked_i;
assign clk_not_locked_i = !CLK_LOCKED;
assign MMCM_NOT_LOCKED  = !locked_i;

`ifndef SIMULATE

generate

if (FPGA_FAMILY == "ultrascaleplus") begin

    localparam integer P_FREQ_RATIO_SOURCE_TO_USRCLK  = 1;
    localparam integer P_USRCLK_INT_DIV  = P_FREQ_RATIO_SOURCE_TO_USRCLK - 1;
    localparam   [2:0] P_USRCLK_DIV      = P_USRCLK_INT_DIV[2:0];
    BUFG_GT bufg_gt_usrclk_inst (
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (TX_CLK_CLR),
        .CLRMASK (1'b0),
        .DIV     (P_USRCLK_DIV),
        .I       (TX_CLK),
        .O       (TX_CLK_OUT)
    );

    MMCME4_ADV #(.BANDWIDTH            ("OPTIMIZED"),
                 .CLKOUT4_CASCADE      ("FALSE"),
                 .COMPENSATION         ("AUTO"),
                 .STARTUP_WAIT         ("FALSE"),
                 .DIVCLK_DIVIDE        (DIVIDE),
                 .CLKFBOUT_MULT_F      (MULT),
                 .CLKFBOUT_PHASE       (0.000),
                 .CLKFBOUT_USE_FINE_PS ("FALSE"),
                 .CLKOUT0_DIVIDE_F     (OUT0_DIVIDE),
                 .CLKOUT0_PHASE        (0.000),
                 .CLKOUT0_DUTY_CYCLE   (0.500),
                 .CLKOUT0_USE_FINE_PS  ("FALSE"),
                 .CLKIN1_PERIOD        (CLK_PERIOD),
                 .CLKOUT1_DIVIDE       (OUT1_DIVIDE),
                 .CLKOUT1_PHASE        (0.000),
                 .CLKOUT1_DUTY_CYCLE   (0.500),
                 .CLKOUT1_USE_FINE_PS  ("FALSE"),
                 .CLKOUT2_DIVIDE       (OUT2_DIVIDE),
                 .CLKOUT2_PHASE        (0.000),
                 .CLKOUT2_DUTY_CYCLE   (0.500),
                 .CLKOUT2_USE_FINE_PS  ("FALSE"),
                 .CLKOUT3_DIVIDE       (OUT3_DIVIDE),
                 .CLKOUT3_PHASE        (0.000),
                 .CLKOUT3_DUTY_CYCLE   (0.500),
                 .CLKOUT3_USE_FINE_PS  ("FALSE"),
                 .REF_JITTER1          (0.010))
        mmcm_adv_inst (
            .CLKFBOUT            (clkfbout),
            .CLKFBOUTB           (),
            .CLKOUT0             (user_clk_i),
            .CLKOUT0B            (),
            .CLKOUT1             (sync_clk_i),
            .CLKOUT1B            (),
            .CLKOUT2             (),
            .CLKOUT2B            (),
            .CLKOUT3             (),
            .CLKOUT3B            (),
            .CLKOUT4             (),
            .CLKOUT5             (),
            .CLKOUT6             (),
            // Input clock control
            .CLKFBIN             (clkfbout),
            .CLKIN1              (TX_CLK_OUT),
            .CLKIN2              (1'b0),
            // Tied to always select the primary input clock
            .CLKINSEL            (1'b1),
            // Ports for dynamic reconfiguration
            .DADDR               (7'h0),
            .DCLK                (1'b0),
            .DEN                 (1'b0),
            .DI                  (16'h0),
            .DO                  (),
            .DRDY                (),
            .DWE                 (1'b0),
            // Ports for dynamic phase shift
            .PSCLK               (1'b0),
            .PSEN                (1'b0),
            .PSINCDEC            (1'b0),
            .PSDONE              (),
            // Other control and status signals
            .LOCKED              (locked_i),
            .CLKINSTOPPED        (),
            .CLKFBSTOPPED        (),
            .PWRDWN              (1'b0),
            .RST                 (clk_not_locked_i));
end

if (FPGA_FAMILY == "7series") begin

    BUFG txout_clock_net_i
    (
        .I(TX_CLK),
        .O(TX_CLK_OUT)
    );

    MMCME2_ADV #(.BANDWIDTH            ("OPTIMIZED"),
                 .CLKOUT4_CASCADE      ("FALSE"),
                 .COMPENSATION         ("ZHOLD"),
                 .STARTUP_WAIT         ("FALSE"),
                 .DIVCLK_DIVIDE        (DIVIDE),
                 .CLKFBOUT_MULT_F      (MULT),
                 .CLKFBOUT_PHASE       (0.000),
                 .CLKFBOUT_USE_FINE_PS ("FALSE"),
                 .CLKOUT0_DIVIDE_F     (OUT0_DIVIDE),
                 .CLKOUT0_PHASE        (0.000),
                 .CLKOUT0_DUTY_CYCLE   (0.500),
                 .CLKOUT0_USE_FINE_PS  ("FALSE"),
                 .CLKIN1_PERIOD        (CLK_PERIOD),
                 .CLKOUT1_DIVIDE       (OUT1_DIVIDE),
                 .CLKOUT1_PHASE        (0.000),
                 .CLKOUT1_DUTY_CYCLE   (0.500),
                 .CLKOUT1_USE_FINE_PS  ("FALSE"),
                 .CLKOUT2_DIVIDE       (OUT2_DIVIDE),
                 .CLKOUT2_PHASE        (0.000),
                 .CLKOUT2_DUTY_CYCLE   (0.500),
                 .CLKOUT2_USE_FINE_PS  ("FALSE"),
                 .CLKOUT3_DIVIDE       (OUT3_DIVIDE),
                 .CLKOUT3_PHASE        (0.000),
                 .CLKOUT3_DUTY_CYCLE   (0.500),
                 .CLKOUT3_USE_FINE_PS  ("FALSE"),
                 .REF_JITTER1          (0.010))
        mmcm_adv_inst (
            .CLKFBOUT            (clkfbout),
            .CLKFBOUTB           (),
            .CLKOUT0             (user_clk_i),
            .CLKOUT0B            (),
            .CLKOUT1             (sync_clk_i),
            .CLKOUT1B            (),
            .CLKOUT2             (),
            .CLKOUT2B            (),
            .CLKOUT3             (),
            .CLKOUT3B            (),
            .CLKOUT4             (),
            .CLKOUT5             (),
            .CLKOUT6             (),
            // Input clock control
            .CLKFBIN             (clkfbout),
            .CLKIN1              (TX_CLK_OUT),
            .CLKIN2              (1'b0),
            // Tied to always select the primary input clock
            .CLKINSEL            (1'b1),
            // Ports for dynamic reconfiguration
            .DADDR               (7'h0),
            .DCLK                (1'b0),
            .DEN                 (1'b0),
            .DI                  (16'h0),
            .DO                  (),
            .DRDY                (),
            .DWE                 (1'b0),
            // Ports for dynamic phase shift
            .PSCLK               (1'b0),
            .PSEN                (1'b0),
            .PSINCDEC            (1'b0),
            .PSDONE              (),
            // Other control and status signals
            .LOCKED              (locked_i),
            .CLKINSTOPPED        (),
            .CLKFBSTOPPED        (),
            .PWRDWN              (1'b0),
            .RST                 (clk_not_locked_i));

// BUFG for the feedback clock.  The feedback signal is phase aligned to the input
// and must come from the CLK0 or CLK2X output of the PLL. In this case, we use
// the CLK0 output.

end

endgenerate

BUFG sync_clock_net_i
(
    .I(sync_clk_i),
    .O(SYNC_CLK)
);

BUFG user_clk_net_i
(
    .I(user_clk_i),
    .O(USER_CLK)
);

`endif // SIMULATE

endmodule
