module fifo_integrity_checker (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic ibuf_create0_en,
    input logic ibuf_create1_en,
    input logic ibuf_create2_en,
    input logic ibuf_retire0_en,
    input logic ibuf_retire1_en,
    input logic ibuf_retire0_en_vld,
    input logic ibuf_empty,
    input logic ibuf_full
);

endmodule

bind aq_ifu_ibuf fifo_integrity_checker u_fifo_integrity_checker (
    .forever_cpuclk      (forever_cpuclk),
    .cpurst_b            (cpurst_b),
    .ibuf_create0_en     (ibuf_create0_en),
    .ibuf_create1_en     (ibuf_create1_en),
    .ibuf_create2_en     (ibuf_create2_en),
    .ibuf_retire0_en     (ibuf_retire0_en),
    .ibuf_retire1_en     (ibuf_retire1_en),
    .ibuf_retire0_en_vld (ibuf_retire0_en_vld),
    .ibuf_empty          (ibuf_empty),
    .ibuf_full           (ibuf_full)
);
