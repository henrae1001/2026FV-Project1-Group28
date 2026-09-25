# FV Project 1 — Group 28 共同規格

截止：**2026-10-12 23:59**。成員：**M16144041、N26140896**。
作業依據：`FV_2026_Project1.pdf`（本機位於專案上一層）；個人 SVA 操作與檔案導讀見 [Guide.md](Guide.md)。
以下區分作業要求與團隊約定；實作 Steps 不再重複放在本文件。

## 1. 作業要求

- Target：`aq_ifu_top` 內的 `aq_ifu_ibuf`，depth=6、每筆 16 bits，每 cycle 最多 3 writes / 2 reads（PDF 第 3–4 頁）。
- 自製 SVA 檢查 data integrity（drop、duplicate、out-of-order、corruption）、overflow、underflow；另用 Jasper Scoreboard 3 驗證 data integrity，兩者皆必做（第 10、12 頁）。
- 優先用自製 SVA 找 bug，無法再辨識新問題後才用 Scoreboard 繼續找；保存 counterexample、分析 root cause、修正 RTL 並重新驗證（第 25–26 頁）。
- 全部必要 properties proven 後，比較 formal gate count、memory usage、runtime，並解釋差異原因（第 10、27 頁）。
- 交付修正後 RTL、兩套 checker/Tcl、學號、PPTX、PDF report；兩份 Tcl 須能從解壓後根目錄執行（第 11 頁）。
- Coverage report 為 Bonus，最多加 15 分；若提交，附設定、結果與 uncovered/unreachable/vacuity 分析。

## 2. 共同驗證規格

### 固定環境

兩套驗證均保留作業指定的 `elaborate -top aq_ifu_top`、`clock forever_cpuclk`、
`reset -expression {!cpurst_b}` 及下列 assumptions 的完整原始語意（PDF 第 5 頁）：

| Assumption | 原始作用範圍 |
| --- | --- |
| `assume_skip_init` | reset 解除後，`vec_ctrl_reset_mask` 為 1 時，create/retire enables 全為 0 |
| `assume_no_flush` | reset 解除且初始化結束時，`ibuf_flush_en` 為 0 |
| `assume_no_debug_mode` | reset 解除且初始化結束時，`rtu_yy_xx_dbgon` 為 0 |

不得修改上述設定，或增加資料、stall、port 組合等限制來排除 failure。
若認為 interface 或環境缺少定義，保存具體 waveform 向助教釐清，不自行放寬驗收。

### Transaction 與 reference model（團隊約定）

- 只追蹤六個 FIFO entries；後級 pop-entry 與直接 bypass 不計入 depth=6。
- 每個 `posedge forever_cpuclk` 以 `ibuf_createN_en/inst` 作為 enqueue event，以 `ibuf_retireN_en` 與 `popN_inst` 作為 dequeue event 並比對 read data；reset 時清空 reference model。
- 只處理 enabled ports，依 port 0→1→2 排序；不改用 `*_data_en`、`ibuf_retire0_en_vld`，也不以 DUT full/empty 過濾 transactions。
- read data 與 edge 前的 reference queue 比對；先 dequeue 舊資料，再 enqueue 本 cycle 的 write data，不能用同 cycle 的 write data 補足 read。
- Reference model 依 transaction 獨立更新，不複製 DUT pointer 或 data selection logic，不以現有 RTL 的疑似錯誤行為改寫規格。

共用 packing（最低有效 chunk 為 port 0）：

```systemverilog
incoming_vld  = {ibuf_create2_en, ibuf_create1_en, ibuf_create0_en};
incoming_data = {ibuf_create2_inst, ibuf_create1_inst, ibuf_create0_inst};
outgoing_vld  = {ibuf_retire1_en, ibuf_retire0_en};
outgoing_data = {pop1_inst, pop0_inst};
```

令 `q` 為 edge 前的 reference count，`w/r` 為本 cycle 有效的 write/read count。共同驗收：

| 檢查 | 條件 |
| --- | --- |
| Data integrity | 每個有效輸出依序等於 reference queue 的 16-bit 資料 |
| Underflow / overflow | `r <= q`、`q + w <= 6 + r`；加法明確加寬，避免 truncation 或 wraparound |
| Occupancy（團隊追加） | `q_next = q - r + w`、count 維持 0–6，與六個 entry valid signal 的總和一致 |
| Full / empty（團隊追加） | 同一 sampling edge 的 `ibuf_full == (q == 6)`、`ibuf_empty == (q == 0)` |

資料值可合法重複；由 data order、count 與 occupancy 共同檢查 data integrity，不假設資料唯一。
本規格檢查 safety，並未保證在任意長 stall 下，每筆 data 最終都會 dequeue。
團隊另檢查 multi-port、concurrent read/write、empty/full、wraparound、stall、bypass，以及 assertion antecedent 的 reachability；
cover 不能代替 assertion，unreachable 與 unknown/timeout 分開記錄。

Scoreboard 使用相同 verification environment、transaction event 與 packing；wrapper/bind 須通過 compile/elaborate：

```systemverilog
.CHUNK_WIDTH(16), .IN_CHUNKS(3), .OUT_CHUNKS(2),
.PORT_ORDER(`JS3_RIGHT_TO_LEFT), .ORDERING(`JS3_IN_ORDER),
.SINGLE_CLOCK(1), .MAX_PENDING(6)
```

## 3. 分工與協作

| 成員 | 主責 |
| --- | --- |
| **A：N26140896** | `fifo_integrity.sv/.tcl`、自製 SVA、counterexample、修正後 SVA regression；提供 FIFO/SVA/bug 的技術文字與圖 |
| **B：M16144041** | `jasper_sb_3.sv/.tcl`、已確認 bug 的 RTL fix、Scoreboard proof、resource usage 比較、PPTX/PDF/ZIP 整合 |

流程：**checker/covers → 自製 SVA 與逐項 debug/fix → Scoreboard 與最終 proof → resource measurement/交付**。
B 可先準備 Scoreboard wrapper；若後續由 Scoreboard 發現新 bug，保留來源、共同確認後修正，
由 A 補足自製 SVA regression，不要求先用 SVA 重現才開始修正。兩人共同 review root cause 與報告。

Git：在 `feat/ibuf-formal-verification` 合作，完成後一次 PR 合併 `main`。
Property、單一 bug 的 RTL fix、文件分開 commit，明確選檔加入；Jasper cache 不混入。
已分享的 history 原則上不重寫；另有明確授權時先備份，推送須保護他人新提交。

## 4. 最終交付與驗收

```text
Project1_Group28.zip
└── Project1_Group28/
    ├── src/gen_rtl/                 # 修正後 RTL
    ├── property/
    │   ├── fifo_integrity.sv
    │   └── jasper_sb_3.sv
    ├── script/
    │   ├── fifo_integrity.tcl
    │   └── jasper_sb_3.tcl
    └── document/
        ├── Student_ID.txt           # M16144041、N26140896，各一行
        ├── Project1_Group28.pptx
        └── Project1_Group28.pdf
```

- [ ] 每個 bug 有發現來源、修正前 counterexample、root cause、RTL diff 與修正後結果，版本可重現。
- [ ] 同一 final RTL 的自製 SVA 必要 assertions 與 Scoreboard `data_integrity` 均 proven；有限深度或 timeout 不算完成。
- [ ] reachability/vacuity 檢查有紀錄，未解決 cover 的結果與原因清楚。
- [ ] resource usage 比較使用相同 final RTL/Jasper/硬體/環境，記錄 property 範圍、量測方式及差異原因。
- [ ] PPTX/PDF 包含 FIFO behavior 與 signals、兩種方法、SVA 說明、Scoreboard binding/結果、bug waveform 與修正、重新驗證及 resource usage 比較。
- [ ] ZIP 結構、學號與檔名正確；解壓後在 `Project1_Group28/` 執行兩份 Tcl 可重現，無本機絕對路徑依賴。
- [ ] 兩人都能說明完整驗證與修正流程；若提交 Bonus，補齊 coverage 分析。
