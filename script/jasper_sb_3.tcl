# Run Jasper from the project root.
clear -all
check_cov -init -type all

# For `JS3_*
jasper_scoreboard_3 -init

set RTL ./src/gen_rtl

analyze -sv \
  $RTL/cpu/rtl/cpu_cfig.h \
  $RTL/idu/rtl/aq_idu_cfig.h \
  $RTL/dtu/rtl/aq_dtu_cfig.h \
  $RTL/lsu/rtl/aq_lsu_cfig.h \
  $RTL/mmu/rtl/sysmap.h \
  $RTL/tdt/rtl/top/tdt_define.h \
  $RTL/clk/rtl/gated_clk_cell.v \
  $RTL/fpga/rtl/fpga_ram.v \
  $RTL/fpga/rtl/aq_f_spsram_1024x16.v \
  $RTL/fpga/rtl/aq_f_spsram_2048x32.v \
  $RTL/fpga/rtl/aq_f_spsram_256x59.v \
  {*}[glob $RTL/ifu/rtl/*.v]
analyze -sv ./property/jasper_sb_3.sv
elaborate -top aq_ifu_top

clock forever_cpuclk
reset -expression {!cpurst_b}

# Environment assumptions
assume -name assume_skip_init {
  @(posedge forever_cpuclk) disable iff (!cpurst_b)
  vec_ctrl_reset_mask |->
    (!(x_aq_ifu_ibuf.ibuf_create0_en ||
       x_aq_ifu_ibuf.ibuf_create1_en ||
       x_aq_ifu_ibuf.ibuf_create2_en) &&
     !(x_aq_ifu_ibuf.ibuf_retire0_en ||
       x_aq_ifu_ibuf.ibuf_retire1_en))
}
assume -name assume_no_flush {
  @(posedge forever_cpuclk)
  disable iff (!(cpurst_b && !vec_ctrl_reset_mask))
  !x_aq_ifu_ibuf.ibuf_flush_en
}
assume -name assume_no_debug_mode {
  @(posedge forever_cpuclk)
  disable iff (!(cpurst_b && !vec_ctrl_reset_mask))
  !rtu_yy_xx_dbgon
}

prove -all
