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

    // Assertion 1: Cover a write on create port 0.
    c_create0: cover property (
        @(posedge forever_cpuclk) disable iff (!cpurst_b)
        ibuf_create0_en
    );

    logic [2:0] write_count;
    logic [1:0] read_count;
    logic [3:0] ref_count;
    logic [4:0] count_after_writes;
    logic [4:0] capacity_after_reads;
    logic [4:0] next_count;

    // Assertion 2: Count enabled transactions without DUT status.
    assign write_count = {2'b00, ibuf_create0_en} +
                         {2'b00, ibuf_create1_en} +
                         {2'b00, ibuf_create2_en};
    assign read_count = {1'b0, ibuf_retire0_en} +
                        {1'b0, ibuf_retire1_en};
    assign count_after_writes = {1'b0, ref_count} + {2'b00, write_count};
    assign capacity_after_reads = 5'd6 + {3'b000, read_count};
    assign next_count = count_after_writes - {3'b000, read_count};

    // Assertion 3: Cover at least one FIFO read.
    c_read: cover property (
        @(posedge forever_cpuclk) disable iff (!cpurst_b)
        read_count != 2'd0
    );

    // Assertion 4: Guard model updates; assertions still detect illegal transactions.
    always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
        if (!cpurst_b)
            ref_count <= 4'd0;
        else if (ref_count <= 4'd6 &&
                 read_count <= ref_count &&
                 count_after_writes <= capacity_after_reads)
            ref_count <= next_count[3:0];
    end

    // Assertion 5: Assert reads use entries present before this cycle.
    a_no_underflow: assert property (
        @(posedge forever_cpuclk) disable iff (!cpurst_b)
        read_count <= ref_count
    );

    // Assertion 6: Assert writes fit after same-cycle reads free slots.
    a_no_overflow: assert property (
        @(posedge forever_cpuclk) disable iff (!cpurst_b)
        count_after_writes <= capacity_after_reads
    );

    // Assertion 7: Assert the reference count stays within capacity.
    a_ref_count_in_range: assert property (
        @(posedge forever_cpuclk) disable iff (!cpurst_b)
        ref_count <= 4'd6
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
