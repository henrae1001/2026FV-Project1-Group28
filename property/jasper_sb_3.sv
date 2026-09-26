module ibuf_scoreboard_checker (
    input logic        forever_cpuclk,
    input logic        cpurst_b,
    input logic        ibuf_create0_en,
    input logic        ibuf_create1_en,
    input logic        ibuf_create2_en,
    input logic [15:0] ibuf_create0_inst,
    input logic [15:0] ibuf_create1_inst,
    input logic [15:0] ibuf_create2_inst,
    input logic        ibuf_retire0_en,
    input logic        ibuf_retire1_en,
    input logic [15:0] pop0_inst,
    input logic [15:0] pop1_inst
);

    logic [2:0]  incoming_vld;
    logic [47:0] incoming_data;
    logic [1:0]  outgoing_vld;
    logic [31:0] outgoing_data;

    // Port 0 is the least-significant chunk and is processed first.
    assign incoming_vld  = {ibuf_create2_en, ibuf_create1_en, ibuf_create0_en};
    assign incoming_data = {ibuf_create2_inst, ibuf_create1_inst, ibuf_create0_inst};
    assign outgoing_vld  = {ibuf_retire1_en, ibuf_retire0_en};
    assign outgoing_data = {pop1_inst, pop0_inst};

    jasper_scoreboard_3 #(
        .CHUNK_WIDTH (16),
        .IN_CHUNKS   (3),
        .OUT_CHUNKS  (2),
        .PORT_ORDER  (`JS3_RIGHT_TO_LEFT),
        .ORDERING    (`JS3_IN_ORDER),
        .SINGLE_CLOCK(1),
        .MAX_PENDING (6)
    ) u_scoreboard (
        .clk          (forever_cpuclk),
        .rstN         (cpurst_b),
        .incoming_vld (incoming_vld),
        .incoming_data(incoming_data),
        .outgoing_vld (outgoing_vld),
        .outgoing_data(outgoing_data)
    );

endmodule

bind aq_ifu_ibuf ibuf_scoreboard_checker u_ibuf_scoreboard_checker (
    .forever_cpuclk    (forever_cpuclk),
    .cpurst_b          (cpurst_b),
    .ibuf_create0_en   (ibuf_create0_en),
    .ibuf_create1_en   (ibuf_create1_en),
    .ibuf_create2_en   (ibuf_create2_en),
    .ibuf_create0_inst (ibuf_create0_inst),
    .ibuf_create1_inst (ibuf_create1_inst),
    .ibuf_create2_inst (ibuf_create2_inst),
    .ibuf_retire0_en   (ibuf_retire0_en),
    .ibuf_retire1_en   (ibuf_retire1_en),
    .pop0_inst         (pop0_inst),
    .pop1_inst         (pop1_inst)
);
