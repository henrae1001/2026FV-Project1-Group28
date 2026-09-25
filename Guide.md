# SVA Guide — Group 28

讀者：**N26140896（A：自製 SVA、bug detection 與技術內容）**。
共同規格、分工與交付要求見 [Spec.md](Spec.md)；本文件提供實際閱讀與操作順序。

## 1. 目前從哪裡開始

- `property/fifo_integrity.sv` 目前只保留 checker module 的 ports 與 bind；尚無 assertion、cover 或 reference model。
- 舊 Jasper log 對應移除前的 checker，不能當成目前版本的 proof 或 cover 結果。
- 舊版 properties 已移除；請逐條自行重寫並驗證。

七項 FIFO verification 目標不必照列表順序實作：先用簡單 cover 確認 reachability，
再建立 quantity/conservation 與 boundary safety 的 reference count，接著檢查 state consistency，
最後用同一個 reference FIFO 檢查 data correctness 與 ordering。Simultaneous operation 應在
count 和 data 階段都測試；每新增 assertion 就檢查 antecedent reachability 與 vacuity。
你現在先做 **Step 0–2：記錄版本 → 核對 bind → 自行寫第一條 cover 並執行**，
再依 Step 3 查看 witness waveform。看到疑似 bug 時可進入 Step 8，無須等其他 properties 全部 proven。

## 2. 檔案地圖：要讀什麼、何時才讀

「暫時不用讀」代表不必逐行理解，**不代表能刪檔或從 Tcl 的 analyze 清單移除**。
Formal top 是 `aq_ifu_top`，上游控制與記憶體仍可能影響 FIFO 的 reachable states。
下表涵蓋目前專案原始檔；後續沿 counterexample 的 signal 來源擴大閱讀即可。

### 2.1 每次工作會用到的文件與程式

| 檔案 | 要讀或修改的內容 |
| --- | --- |
| 作業 PDF：`../FV_2026_Project1.pdf`（本機） | 第 3–5 頁：FIFO boundary、signal 與固定 verification environment；第 6、10 頁：驗證目標；第 11–13 頁：交付、評分與截止；第 19–27 頁：報告需要的證據 |
| [Spec.md](Spec.md) | 兩人共同遵守的 transaction interface、分工與驗收；不可各自改用不同的 enqueue/dequeue events |
| [property/fifo_integrity.sv](property/fifo_integrity.sv) | 你的主要編輯檔：checker ports、bind、covers、reference model、assertions |
| [script/fifo_integrity.tcl](script/fifo_integrity.tcl) | 確認 analyze、top、clock、reset、assumptions、proof；保留作業固定設定，必要時調整執行/報告選項 |

### 2.2 優先 trace 的 RTL

以下 RTL 都在 `src/gen_rtl/`。先讀表中的部分，無須一次讀懂整顆 IFU。

| 檔案 | 優先度與搜尋入口 | 要回答的問題 |
| --- | --- | --- |
| [ifu/rtl/aq_ifu_top.v](src/gen_rtl/ifu/rtl/aq_ifu_top.v) | 先看 `x_aq_ifu_ibuf`、`x_aq_ifu_ipack`、`x_aq_ifu_ctrl` 接線 | checker 綁到哪個 instance？IBUF input 從哪裡來？ |
| [ifu/rtl/aq_ifu_ibuf.v](src/gen_rtl/ifu/rtl/aq_ifu_ibuf.v) | 精讀 `ibuf_create*`、`ibuf_retire*`、`push0`、`pop0`、`ibuf_vld_num`、`pop_entry*` | 每次 transaction 何時發生？data 寫到哪個 entry、從哪個 entry 讀出？ |
| [ifu/rtl/aq_ifu_ibuf_entry.v](src/gen_rtl/ifu/rtl/aq_ifu_ibuf_entry.v) | 精讀 `entry_create`、`entry_retire`、`entry_vld`、`entry_inst_upd` | 六個 FIFO entries 的 valid 與 data 如何更新？create/retire 同時發生時誰優先？ |
| [ifu/rtl/aq_ifu_ibuf_pop_entry.v](src/gen_rtl/ifu/rtl/aq_ifu_ibuf_pop_entry.v) | 釐清邊界時看 `entry_create`、`entry_retire` 與 data register | FIFO read data 如何進入下游？不可把這兩個 pop entries 算進 depth=6 |
| [ifu/rtl/aq_ifu_ctrl.v](src/gen_rtl/ifu/rtl/aq_ifu_ctrl.v) | 先看 `ctrl_ibuf_pop_en` | 目前它等於 `!idu_ifu_id_stall`；下游何時允許前進？ |
| [clk/rtl/gated_clk_cell.v](src/gen_rtl/clk/rtl/gated_clk_cell.v) | 看 `clk_out` 的 assign 即可 | 提供的 clock model 目前是 `clk_out = clk_in`；不要只看名稱就假設真的有 clock gating |

### 2.3 Counterexample 指向上游時才深入

| 檔案 | 何時需要 trace |
| --- | --- |
| [aq_ifu_ipack.v](src/gen_rtl/ifu/rtl/aq_ifu_ipack.v)、[aq_ifu_ipack_entry.v](src/gen_rtl/ifu/rtl/aq_ifu_ipack_entry.v) | create cover 尚未 `covered`，或要解釋 `ipack_ibuf_inst*` 的 data、有效數量與 stall |
| [aq_ifu_vec.v](src/gen_rtl/ifu/rtl/aq_ifu_vec.v) | initialization、`vec_ctrl_reset_mask`、warm-up 如何影響 transaction 或 data |
| [aq_ifu_pcgen.v](src/gen_rtl/ifu/rtl/aq_ifu_pcgen.v) | PC 改變流程、`pcgen_ibuf_chgflw_vld` 或 flush 路徑影響 counterexample |
| [aq_ifu_pred.v](src/gen_rtl/ifu/rtl/aq_ifu_pred.v) | `pred_ibuf_chgflw_vld0`、預測控制或上游 stall 改變 create 條件 |
| [aq_ifu_pre_decd.v](src/gen_rtl/ifu/rtl/aq_ifu_pre_decd.v) | counterexample 需要追查上游 predecode 如何影響指令處理 |
| [aq_ifu_icache.v](src/gen_rtl/ifu/rtl/aq_ifu_icache.v)、[aq_ifu_icache_data_array.v](src/gen_rtl/ifu/rtl/aq_ifu_icache_data_array.v)、[aq_ifu_icache_tag_array.v](src/gen_rtl/ifu/rtl/aq_ifu_icache_tag_array.v) | data 進入 IPACK 前已出現異常，或必須解釋 fetch reachability |
| [aq_ifu_bht.v](src/gen_rtl/ifu/rtl/aq_ifu_bht.v)、[aq_ifu_bht_array.v](src/gen_rtl/ifu/rtl/aq_ifu_bht_array.v) | branch history prediction state 確實位於待查 signal 的來源路徑 |
| [aq_ifu_btb.v](src/gen_rtl/ifu/rtl/aq_ifu_btb.v)、[aq_ifu_btb_entry.v](src/gen_rtl/ifu/rtl/aq_ifu_btb_entry.v) | branch target prediction 或其控制確實影響目前 counterexample |
| [aq_ifu_ras.v](src/gen_rtl/ifu/rtl/aq_ifu_ras.v)、[aq_ifu_ras_entry.v](src/gen_rtl/ifu/rtl/aq_ifu_ras_entry.v) | return address prediction 確實影響目前 counterexample |

### 2.4 初期保留於 analyze 清單即可

| 檔案 | 用途 |
| --- | --- |
| [cpu/cpu_cfig.h](src/gen_rtl/cpu/rtl/cpu_cfig.h)、[idu/aq_idu_cfig.h](src/gen_rtl/idu/rtl/aq_idu_cfig.h)、[dtu/aq_dtu_cfig.h](src/gen_rtl/dtu/rtl/aq_dtu_cfig.h)、[lsu/aq_lsu_cfig.h](src/gen_rtl/lsu/rtl/aq_lsu_cfig.h) | macro 與配置；遇到 bit width、conditional compilation 或 analyze error 時再查 |
| [mmu/sysmap.h](src/gen_rtl/mmu/rtl/sysmap.h)、[tdt/tdt_define.h](src/gen_rtl/tdt/rtl/top/tdt_define.h) | address mapping、debug 等定義；保留既有 analyze 次序 |
| [ifu/aq_spsram_1024x16.v](src/gen_rtl/ifu/rtl/aq_spsram_1024x16.v)、[aq_spsram_2048x32.v](src/gen_rtl/ifu/rtl/aq_spsram_2048x32.v)、[aq_spsram_256x59.v](src/gen_rtl/ifu/rtl/aq_spsram_256x59.v) | SRAM modules，通常不需要為 IBUF entry FIFO 撰寫其內部 assertions |
| [fpga/fpga_ram.v](src/gen_rtl/fpga/rtl/fpga_ram.v)、[aq_f_spsram_1024x16.v](src/gen_rtl/fpga/rtl/aq_f_spsram_1024x16.v)、[aq_f_spsram_2048x32.v](src/gen_rtl/fpga/rtl/aq_f_spsram_2048x32.v)、[aq_f_spsram_256x59.v](src/gen_rtl/fpga/rtl/aq_f_spsram_256x59.v) | RAM implementation/model；目前只需確保工具能完整 elaborate |

### 2.5 協作與報告時才使用

| 檔案 | 你的責任 |
| --- | --- |
| [property/jasper_sb_3.sv](property/jasper_sb_3.sv)、[script/jasper_sb_3.tcl](script/jasper_sb_3.tcl) | B 主責；你 review transaction boundary、packing、reset 與 reference model 是否一致 |
| [document/Project1_GroupX.pptx](document/Project1_GroupX.pptx) | 簡報範本；你提供 FIFO/SVA 說明、waveform 與技術分析，B 統一編輯 |
| [document/Project1_GroupX.docx](document/Project1_GroupX.docx) | 報告範本；最終交付須有 `Project1_Group28.pdf`，不是只交 DOCX |
| [document/Student_ID.txt](document/Student_ID.txt) | 交付前確認兩人學號；與 checker 行為無關 |

## 3. 寫 property 前，先畫出 signal flow

### 3.1 Checker interface 與觀察 signals

| Signal | 用法與注意事項 |
| --- | --- |
| `forever_cpuclk`、`cpurst_b` | rising edge sampling、active-low reset；正常 transaction 的 properties 使用 `disable iff (!cpurst_b)` |
| `ibuf_create0/1/2_en`、各自的 `*_inst[15:0]` | 作業指定的 write event 與 data；依 enabled port 0→2 enqueue |
| `ibuf_retire0/1_en`、`pop0/1_inst[15:0]` | 作業指定的 read event 與 data；依 enabled port 0→1 比對並 dequeue |
| `ibuf_empty`、`ibuf_full` | DUT 宣告的 empty/full；後續要與獨立 `ref_count` 比較 |
| `entry0..5_vld`、`ibuf_vld_num` | DUT occupancy 的觀察點，不可拿來直接設定 reference count |
| `ibuf_retire0_en_vld`、`entryN_retire0/1_en` | 診斷 entry retirement 與作業指定的 read event 是否一致 |
| `ibuf_createN_data_en`、`entryN_createM_en/data_en`、`entryN_inst` | data mismatch 時追查 write destination 與 data mux；不能用 data_en 取代指定的 create enable |
| `push0/1/2`、`push*_bypass`、`pop0/1` | `push0`、`pop0` 是 clock 更新的 6-bit pointers；`push1/2`、`pop1` 是 combinational。實際 entry create routing 依 `push*_bypass`，不能把 port N 直接當成 entry N |
| `pop0/1_inst`、`pop0/1_vld`、`ibuf_inst32` | `pop*_inst` 是 entry data mux 的 combinational output；Verilog 的 `reg` 宣告不表示此處有 register。只在對應 read enable 有效時比對 data；`ibuf_inst32` 幫助解釋雙讀，不放入獨立 reference model |
| `idu_ifu_id_stall`、`ctrl_ibuf_pop_en`、`ipack_bypass_vld`、`pop_entry*` | stall/bypass 與下游 data path；六個 FIFO entries、pop-entry 與 direct bypass 要分開看 |
| `vec_ctrl_reset_mask`、`ibuf_flush_en`、`rtu_yy_xx_dbgon` | 確認三項既有 assumptions 的作用範圍；`vec_ctrl_reset_mask` 在 top 層，不能假設它是 IBUF 內部 signal |

目前 checker 只接了 clock/reset、create/retire enables、empty/full 與 `retire0_en_vld`，尚無 properties。
新增 data 或 occupancy assertion 時，記得同時擴充 module ports 與 bind connections。
每筆 data 為 16 bits，六個 entries；同 cycle 最多 3 個 write ports 與 2 個 read ports。
`createN_en` 與 `createN_data_en` 用途不同，checker 的 transaction event 以前者為準。
當 read enable 無效時，不要求 `popN_inst` 有指定值；entry data register 不需要在 reset 後有已知值。
同 cycle 只處理 enabled ports，依 0→1→2 enqueue、0→1 dequeue；不要 assume port enable 必須連續，
也不要 assume input data 彼此不同。reference model 不抄用 DUT pointer 或 `ibuf_vld_num`。
固定環境為 `aq_ifu_top`、`forever_cpuclk`、`!cpurst_b`，保留 `assume_skip_init`、
`assume_no_flush`、`assume_no_debug_mode` 的原始語意；不可新增限制來排除 failure。

### 3.2 每條 transaction 的 trace 順序

- **Write path**：`ibuf_createN_en/inst` → push routing → `entryM_createN_en/data_en`
  → entry instance 的 port connections → `aq_ifu_ibuf_entry.entry_inst_upd/entry_inst/entry_vld`。
- **Read path**：`pop0/pop1` 選取 entry → `pop0/1_inst` 與 `pop0/1_vld`
  → `ibuf_retire0/1_en` → entry retire/pointer 更新，以及後級 `pop_entry*_create_en`。
- **Status path**：六個 `entryN_vld` → `ibuf_vld_num`、`ibuf_empty/full`
  → 與依 transaction 獨立計算的 `ref_count` 比對。

讀 RTL 是為了定位「哪裡偏離預期」。例如只檢查 `ibuf_full == (ibuf_vld_num == 6)`
幾乎是在重述 DUT 既有的 assign，不能取代與獨立 reference count 的一致性檢查。

### 3.3 優先釐清 retire0 路徑

在 `aq_ifu_ibuf.v` 搜尋：

```systemverilog
assign ibuf_retire0_en = pop0_vld && ctrl_ibuf_pop_en;
assign ibuf_retire0_en_vld = ibuf_retire0_en &&
                            (ibuf_inst32 || ibuf_create0_en);
```

目前 RTL 用後者控制 pop pointer 更新與 entry retire0，而 `pop_entry0_create_en` 使用前者。
將來可自行撰寫 cover，尋找兩者不同的 trace。看到此情境後：

1. 看 `pop0_inst`、`ibuf_inst32`、create enables 與 stall。
2. 比較 edge 前後 `pop0`、六個 entry valid、選中的 entry data、pop-entry valid/data。
3. 依 PDF 的 read interface 判斷是否應該 dequeue 一筆，以及是否出現 duplicate read 或 count 分歧。

**不可因為 RTL 使用 `_en_vld` 就跟著改 reference model 的 dequeue event。** 作業明列的
`ibuf_retire0_en` 仍是檢查依據；這個差異可能正是 DUT bug。cover 只提供 reachable waveform，
仍須用 assertion failure 建立違反 FIFO 規格的 evidence。若確實缺少 interface semantics，記錄具體
waveform 與疑問向助教釐清，兩套 checker 再共同更新，不私自增加 assumption 或縮小邊界。

## 4. 實作 Steps

每次只新增一組相關 properties，執行 Jasper，記錄結果，再進下一步。遇到 assertion failure，
先檢查 checker 與 sampling；若已有 RTL bug 證據，直接跳到 Step 8 處理，不必等後續 Steps。

### Step 0 — 保存 baseline

記錄 RTL、checker、Tcl 的 revision、未提交 diff、Jasper 版本與原有三項 assumptions。
完成：能重建這次執行的輸入；舊 Jasper log 不冒充新版結果。

### Step 1 — 核對 checker 與 bind

確認 module ports、bit width、`bind aq_ifu_ibuf` scope，以及 top/clock/reset/assumptions。
完成：加入第一條 property 後，能成功 analyze/elaborate，且在 IBUF checker instance 下找到它。

### Step 2 — 寫第一條 cover

先自行寫 create0 event 的 cover，再逐條加 read、empty/full、concurrent read/write covers。
在 Jasper Tcl Console 的專案根目錄執行 `source script/fifo_integrity.tcl`；`clear -all` 會清除當前 session state。
若 Jasper 在另一台主機，先確認使用的是本次的 SV/Tcl/RTL 版本。
完成：保存每條 cover 的結果與 witness；未 `covered` 不等於已證明 `unreachable`。

### Step 3 — 讀 witness

比較 sampling edge 前的 enable/data/entry valid 與 edge 後的 state；依實際 witness 追 write/read routing。
SVA 在 rising edge 取樣更新前的值，sequential nonblocking assignment 隨後才更新 state。
完成：能用一條 witness 說明當拍 transaction；多讀與 concurrent read/write 可在後續補查。

### Step 4 — 寫 count 與 boundary assertions

以 4-bit `ref_count`（reset=0）及 5-bit 加法計算 enabled writes `w`、reads `r`。
assert `r <= q`、`q + w <= 6 + r`、`q <= 6`；合法時以 `q_next = q - r + w` 更新。
完成：underflow/overflow 不能被 model 更新 guard、unsigned wraparound 或額外 assumption 掩蓋。

### Step 5 — 寫 occupancy 與 status assertions

bind 六個 `entryN_vld` 及 `ibuf_vld_num`，比對 `ref_count`、六個 valid 的總和，
以及 `ibuf_empty == (q == 0)`、`ibuf_full == (q == 6)`。
完成：比較使用同一 sampling edge；若不一致，找出第一個分歧 cycle。

### Step 6 — 寫 data correctness 與 ordering assertions

bind 三組 `ibuf_createN_inst[15:0]` 與兩組 `popN_inst[15:0]`，建立固定 6×16-bit reference FIFO。
有效 read 先比對 edge 前的 queue；read port 的 index 等於它之前 enabled read ports 的數量。
再 dequeue `r` 筆，依有效 create port 0→1→2 enqueue；用 next-state array 避免重複 nonblocking assignment 覆蓋。
完成：單/雙讀、multi-write、concurrent read/write 的 data order 可檢查；無效 index 不讀取。

### Step 7 — 補 cover 與 vacuity 檢查

補 fill→full、drain→empty、wraparound、stall/bypass、multi-port 與 concurrent read/write 的 sequence covers；
每個有條件的 assertion 都確認 antecedent reachable。單看 reset 後的 empty 不算 drain cover。
完成：區分 `covered`、`unreachable`、`unknown/timeout`；`covered` 不代表 assertion `proven`。
Tcl 的 `check_cov -init -type all` 只初始化 coverage model，Bonus 仍需實際量測與分析。

### Step 8 — 分析 counterexample，交接 RTL fix

排除 checker/reset/sampling 錯誤，記錄首次 failure cycle、expected/actual、property、
RTL/checker/Tcl revision（含未提交 diff）、waveform、log 與 root cause，再交 B 一次修一個 bug。
報告可用截圖說明，但要同時保存可重現的 log、trace 與 revision。
完成：你先重跑該 assertion，再跑完整 SVA；保存 before/after。舊 counterexample 消失但變成 timeout，不算修正已 proven。
entry0/create0 的 bit 9/bit 8 接線只是靜態線索，須由 counterexample 證實。

### Step 9 — 與 Scoreboard 交叉確認

B 可先準備 wrapper；自製 SVA 無法再找出新 bug 後，再用 Scoreboard 尋找新問題。
你 review 共同的 transaction boundary、packing、reset；新 bug 補 SVA regression。
完成：同一 final RTL revision 上，自製 SVA 必要 assertions 與 Scoreboard `data_integrity` 均 `proven`。

### Step 10 — 整理技術內容與交付

所有必要 properties `proven` 後，用同一 RTL revision、Jasper/硬體/assumptions 分別量
gate count、memory usage、runtime，說明 property 範圍與差異。提供 SVA 與 bug 技術內容給 B。
完成：報告和 logs 對得上版本；解壓後在 `Project1_Group28/` 能執行兩份 Tcl，詳細清單見 [Spec.md](Spec.md)。
