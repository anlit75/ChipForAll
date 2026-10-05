# 使用指南

[README](../README.zh-TW.md) 沒寫的都在這裡。這份指南說明這個專案是什麼、不是什麼，以及完整的前置條件。它也說明怎麼換成你自己的設計、怎麼看懂數字，以及第一次執行之後要做的事。

*[English](guide.md)*

## 這個專案是什麼、不是什麼

實體流程（RTL 到 GDSII）是 [LibreLane](https://github.com/librelane/librelane) 的。`make gds` 只是薄薄一層包裝。如果你只想要一份版圖，LibreLane 用 `--dockerized` 就能單獨跑，你不需要這個專案。

LibreLane 不做**模擬與驗證**。這個起手式加上去的就是這兩樣，外加跑它們的 CI 和 Dev Container。

**這裡用的是開源的對應工具，不是商用那幾套。**

| 階段 | 這裡用的 | 商用流程放的 |
|---|---|---|
| Lint | Verilator | SpyGlass、Questa Lint |
| 模擬 | Icarus Verilog，由 cocotb 從 Python 驅動 | VCS、Questa、Xcelium |
| 合成 | Yosys | Design Compiler、Genus |
| 佈局繞線 | OpenROAD，由 LibreLane 包裝 | IC Compiler II、Innovus |
| 靜態時序 | OpenSTA | PrimeTime、Tempus |
| DRC | Magic、KLayout | Calibre nmDRC、Pegasus |
| LVS | Netgen | Calibre nmLVS |

流程的形狀一樣，詞彙也轉得過去。但職缺條列的是商用工具，所以履歷上要講清楚你用的是哪一套。

**在找一個完整的驗證範例嗎？** 這個 repo 的測試是兩份 cocotb 測試平台。它們足以示範「一個會失敗的測試長什麼樣」。它們不是一套分層的驗證環境。[c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) 才是：一個跑在真實 UART 上的 pyuvm 環境，從這個模板建出來。它有 agent、driver、monitor、scoreboard，以及從 SystemRDL 生成的暫存器模型。

**這裡做出來的東西你可以公開。** 製程是 [Sky130](https://github.com/google/skywater-pdk)，SkyWater 用 Apache 2.0 開放出來的 PDK，沒有 NDA。版圖、面積、時序數字和 GDS 全都能放進 GitHub、作品集或文章裡。foundry 在保密條款下給的 PDK 不允許這些事。所以有那種 PDK 的人會來這裡做第二份可以公開的結果。從來沒有過那種 PDK 的人，也是在這裡才有結果可做。

## 開始之前

**在 Apple Silicon 上，有一部分會走模擬。** c4o-core 的映像檔只建 `amd64`（一台 runner、沒有 `platforms:`）。所以在 `arm64` 機器上，`lint`、`cocotb`、`gatesim` 和 `synth` 是透過模擬跑的。加了 Verilog 測試平台之後，`sim` 也是。`make gds` 不是。它最重的那一步跑的是 LibreLane 自己的映像檔，而那個映像檔有出 `arm64`，所以那一步是原生的。

被模擬的那幾個指令會慢多少，這裡沒有量過。Codespace 全程都是 `amd64`。

**有一個前置條件不是下載就有的：一點 Verilog。** 不用多。看得懂一個 `always @(posedge clk)` 區塊和一個 `<=` 指定就夠。測試是 Python，所以你也要看得懂 `assert`。在 [HDLBits](https://hdlbits.01xz.net/) 上大約是 *Verilog Language* 那一段，不是整個網站。

**SystemVerilog 也讀得進來。** 從 c4o-core 2.8.3 開始，`logic`、`always_ff` 和可合成的那個子集在每個指令下都能用。這個 repo 之後釘過的每一版都包含這項修改。在 2.8.3 之前，同一個檔案會通過 `make cocotb` 和 `make gds`，卻在 `make sim` 和 `make synth` 失敗。仍然不行的是把 `interface` 當成模組邊界：yosys 讀得懂宣告，然後在 `hierarchy` 階段失敗。所以 interface 留在測試平台裡，不要放在可合成模組之間。

**你不需要先會 Verilog 才能開始。** `make gds` 直接就能把範例跑完，印出真實的面積、時序和功耗。`make all` 會讓你看到測試通過。先做這兩件事，因為它們告訴你整套工具在你的機器上是通的。真正需要 Verilog 的是下一步：改 `rtl/blinky.v`、判斷一個「通過」的測試到底證明了什麼，或者自己寫一個測試。先跑範例，再學 Verilog，然後回來做那一步。

## 換成你自己的設計

範例是一個 blinky，也就是時脈除頻器。要換成你自己的設計，有三個地方必須互相對上，其他都不用動：

| 要改的 | 在哪裡 |
|---|---|
| 你的 RTL | `rtl/`，列在 `config.yaml` 的 `VERILOG_FILES` |
| `DESIGN_NAME` | `config.yaml`——必須和你的頂層模組同名 |
| 你的測試平台 | `tb/`，列在 `"//COCOTB_TESTS"` |

沒有別的檔案寫死設計名稱。`Makefile` 和 CI 工作流都從 `config.yaml` 讀 `DESIGN_NAME`。

第一次換設計時，還有四件事常造成問題：

*   **刪掉被你取代的 blinky 檔案**：`rtl/blinky.v` 和 `tb/test_blinky_*.py`。也可以改成把它們從 `config.yaml` 移除。測試用的 key 使用萬用字元 `tb/*.py`，所以還留在 `tb/` 的 blinky 測試檔仍然會被包含進來。`VERILOG_FILES` 要逐一列出檔名，所以要在那裡用檔名取代 `rtl/blinky.v`。
*   **為你的測試改寫 `tb/regression.yaml`。** 清單裡的項目指向你已刪掉的測試檔時，`make regress` 會停下來，CI 也一樣。不想用清單，就刪掉那個檔案和 `"//REGRESSION"` 這個 key。
*   **每個 RTL 檔第一行寫 `` `timescale 1ns/1ps ``。** 少了它，`make cocotb` 會失敗，訊息是 `Unable to accurately represent 10(ns)`。`make sim` 照樣通過，因為 Verilog 測試平台自己有宣告。
*   **改寫 `config.yaml` 的 `"//DESCRIPTION"`。** 不改的話，你的結果網頁會說這個設計是一個讓 LED 閃爍的時脈除頻器。

**一個 repo 至少要有一種測試。** 設了 `"//COCOTB_TESTS"`，`make all` 就跑 `cocotb`。設了 `"//TEST_FILES"`，就跑 `sim`。沒設 key 的那一種，它會印一行跳過的訊息。兩個 key 都沒設，`make all` 會失敗。CI 照同樣的規則走。如果把 key 留著卻對不到任何檔案，CI 會失敗。這是對的：你要求了不存在的測試。

第一列弄錯的話，你會立刻收到錯誤，不用等到 `make gds` 跑了三分鐘才發現：

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

**檔案放在哪裡。**

```text
.
├── .devcontainer/     # Dev Container 定義
├── config.yaml        # 設計名稱、時脈、floorplan
├── Makefile           # 映像檔名稱。指令來自映像檔
├── docs/              # 這份指南
├── rtl/               # 你的 Verilog
│   └── blinky.v
├── tb/                # 你的測試平台
│   ├── test_blinky_cocotb.py    # Directed test（make cocotb、make gatesim）
│   ├── test_blinky_random.py    # 隨機刺激對參考模型
│   └── regression.yaml          # make regress 的測試清單
├── build/             # 產生物：GDS、log、netlist、結果網頁
└── runs/              # make gds 產生：LibreLane 的執行目錄
```

## 指令

| 指令 | 說明 | 輸出 |
|---|---|---|
| `make all` | 執行 `lint`、`cocotb`、`synth`，設了 `"//TEST_FILES"` 時再加上 `sim`：幾秒內跑完的所有步驟。 | `終端機` |
| `make lint` | 用 Verilator 檢查 Verilog。 | `終端機` |
| `make sim` | 用 Icarus Verilog 跑 Verilog 測試平台。需要 `"//TEST_FILES"`：見[加入 Verilog 測試平台](#加入-verilog-測試平台)。 | `build/wave.vcd` |
| `make cocotb` | 在 RTL 上執行 Python (cocotb) 測試平台。加了 `WAVES=1` 時，也會在 `build/` 寫出 VCD。 | `build/cocotb-results.xml` |
| `make regress` | 執行 `tb/regression.yaml` 的測試，每個測試跑它的 seed 數。見[多個 seed](#多個-seed)。 | `build/regress/` |
| `make coverage` | 用 Verilator 把 Python 測試再跑一次，數出測試跑過的 RTL。它不決定通過或失敗。見[程式碼覆蓋率](#程式碼覆蓋率)。 | `build/coverage/` |
| `make synth` | 用 Yosys 把 RTL 合成成通用邏輯閘。沒有面積，也沒有時序：見[看看電路長什麼樣](#看看電路長什麼樣)。腳本是固定的。想自己操作 Yosys 就用 `make shell`。 | `build/synthesis.json` |
| `make pdk` | 安裝 Sky130 PDK。`make gds` 會自己執行它。單獨跑可以把那 3GB 的下載提前做完。 | `pdks/` |
| `make schematic` | 把電路畫成到處都開得了的 SVG。 | `build/schematic.svg` |
| `make gds` | 用 LibreLane 產生實體版圖。大約三分鐘，第一次還要加上 PDK 下載。 | `build/<DESIGN_NAME>.gds` |
| `make gatesim` | 對合成後的 netlist 重跑 cocotb 測試平台。設了 `"//GATE_TESTS"` 時，改跑那份 Verilog 測試平台。要先執行 `make gds`。 | `build/cocotb-gl-results.xml` |
| `make report` | 顯示上次 `make gds` 的面積、時序、功耗與 signoff。 | `終端機` |
| `make site` | 把 `report`、版圖和 cocotb 結果放進同一個網頁。 | `build/site/index.html` |
| `make shell` | 進入 c4o-core 容器的互動式 shell。 | — |
| `make clean` | 清除 `build/`。保留 `runs/`，因為 `report` 和 `gatesim` 要讀它。 | — |
| `make distclean` | 清除 `build/` 和 `runs/`。 | — |

`make help` 會在終端機列出這些指令。

## 看懂執行結果

`make gds` 結束時會印出這次流程量到的數字摘要，不必自己去翻檔案：

```
  blinky

  die                56.375 x 67.095 um  (3782.48 um^2)
  utilization        56.6%
  instances          65 after synthesis, 113 after routing
  instance classes   32 logic, 27 well taps, 18 timing-repair buffers, 17 inverters, 16 sequential, 3 clock buffers
  drive strength     X1 0->18, X2 65->65, X16 0->3  (synthesis->routing)
  setup slack        +5.52 ns  (0 violations)
  hold slack         +0.11 ns  (0 violations)
  power              0.143 mW  (nom_tt_025C_1v80)
  signoff            clean  (DRC, LVS, antenna, XOR)
  lint warnings      0
  layout             runs/blinky_run/final/render/blinky.png
```

那是範例設計的數字，出自某一版 PDK。你的數字會不一樣。要學的是該讀哪幾行。

**`signoff`** 說的是其他列都沒說的事：你的版圖通過了可製造性檢查。`Makefile` 釘了一個 LibreLane 版本（`LIBRELANE_IMAGE`）。那個版本預設會在每一項檢查失敗時中止流程（`ERROR_ON_MAGIC_DRC` 那一族預設都是 `True`）。`config.yaml` 沒有覆寫任何一個。所以能跑到這一行，就代表那些檢查都過了。

這是那一版的預設行為，不是這個 repo 的保證，所以升版之後要再確認一次。`clean` 寫出結果，並列出它實際看到哪幾項檢查。有檢查失敗的時候，這一行會列出失敗的項目：`2 Magic DRC, 1 LVS`。

**`instances`** 數的是設計裡的 cell，合成之後一次，繞線之後一次。兩者的差就是 place and route 加進去的東西，例如 well tap、clock buffer 和修時序用的 buffer。`instance classes` 把繞線之後的數量分類。`drive strength` 用 Sky130 cell 名稱的 `_N` 後綴，數同一批 instance，從合成到繞線。`X1 0->18` 的意思是合成沒有做出 X1 instance，繞線之後有 18 個。像 well tap 這種只有實體、沒有邏輯功能的 cell 不在那一行裡。

**`layout`** 是流程幫你的晶片畫的 PNG。打開來看看。

那一行裡的 `XOR` 不是製程規則檢查。兩套工具把同一份版圖各自寫成 GDS，這項檢查比對兩份結果，一致才算過。它抓的是其中一個寫出器的 stream-out bug。它不是兩家廠商的工具對設計做交叉檢查，因為兩邊讀的是同一個資料庫。所以不要把 XOR 乾淨當成對版圖本身的第二意見。

**slack 為正值**代表設計滿足 `config.yaml` 裡設定的時脈。負值代表沒滿足。流程不會因為負 slack 停下來，所以一次成功結束的執行，仍然可能在告訴你設計沒達標。見[slack 為負值的時候](#slack-為負值的時候)。

**這幾行是摘要，不是簽核報告。** 它們從 300 個 key 的 `metrics.json` 裡挑出來，所以它們沒寫的東西很重要。它們沒寫 clock uncertainty 和 derate 設多少，也沒寫 clock tree 的 skew 是多少。它們沒寫九個 corner（`ss`/`tt`/`ff` 各配 `min`/`nom`/`max` 連線）裡是哪一個給出這個 slack。這些全是 LibreLane 的預設值，因為 `config.yaml` 一個都沒設。這些全都在 `runs/` 底下，一個 step 一個目錄。

差別是實務上的。在自己填 OCV derate 的簽核流程裡，`+0.11 ns` 的 hold slack 不會被當成「過了」。要有那種等級的信心，就去讀 per-corner 報告，不要只讀這幾行。

`make report` 會再印一次摘要，不會重跑任何東西。

## 發佈結果網頁

`make site` 產生一個網頁 `build/site/index.html`。網頁最前面是版圖和判定。網頁列出每個 cocotb 測試的判定和 seed。跑過 `make coverage` 之後，網頁會列出覆蓋率區塊。跑過 `make gds` 之後，網頁還會依序列出四個區塊：時序、面積與 instance、功耗，以及 signoff 檢查。

時序區塊說明設計有沒有滿足時脈，並給出最差的 setup 和 hold slack。接著列出這次執行用到的限制條件。每一項都註明是 `config.yaml` 設的，還是流程用了預設值。面積與 instance 區塊數出合成之後和繞線之後的 instance，依類別和 drive strength 分開。它也寫出標準元件庫的名稱，並說明這個元件庫只有單一臨界電壓。

功耗區塊寫出 corner、時脈頻率和切換活動率。這個活動率是 OpenSTA 預設的切換活動率，不是你的測試平台的活動率。它告訴你功耗花在哪裡，不是真實工作負載的耗電。signoff 檢查放在最後：DRC 一列（Magic 和 KLayout 合計）、LVS、antenna、XOR，以及靜態 IR drop。網頁會寫明 electromigration、crosstalk 和動態 IR drop 沒有分析。每一塊在你跑過對應的指令之後才會出現。

這個網頁是照「拿去分享、放進作品集」來排的。版圖在最前面，接著是數字，再來是測試。標題下方是你的 `"//DESCRIPTION"`。有按鈕可以用 3D 開啟晶片、下載 GDS 和看原始碼。頁首寫著網頁的建置時間和對應的 commit。頁首寫這兩項，是因為 `main` 失敗時 CI 不會發佈：網頁會一直顯示最後一次通過的結果。

CI 每次執行都會產生這個網頁。在 `main` 上，它會把網頁發佈到 GitHub Pages，網址是 `https://<你的帳號>.github.io/<你的-repo>/`。在 `main` 上手動執行 workflow 會再發佈一次網頁。用它可以不用 commit 就更新網頁。剛從 template 複製出來的 repo 沒有開 Pages，而且沒有任何 workflow 能替你打開。做一次就好：**Settings → Pages → Source: GitHub Actions**。在你打開之前，CI 照樣會過，並用一則 notice 告訴你這次沒有發佈。

## 程式碼覆蓋率

`make coverage` 顯示 Python 測試跑過你 RTL 的多少部分。它用有覆蓋率計數器的 Verilator，把 `"//COCOTB_TESTS"` 再跑一次。Icarus 沒有覆蓋率。`make all` 不會執行它，但 CI 會。

它計算三種點。Block 是執行過的一段程式碼。Branch 是 `if` 或 `case` 的一邊。Toggle 是值變過的一個訊號位元。結果網頁依種類列出命中的點數和總數。網頁頂端的摘要也有一張卡片顯示它們。

通過或失敗仍由在 Icarus 上跑的 `make cocotb` 決定。Verilator 是 2 值模擬，所以 reset 之前是 `x` 的訊號在那裡讀成 0。同一個測試可能在一個模擬器通過，在另一個失敗。Verilator 那次執行失敗，不會讓 `make coverage` 失敗。Verilator 建不起來的設計才會。

`make coverage SEED=<n>` 設定 seed。網頁會寫出這次執行用的 seed。設了 `"//REGRESSION"` 時，它會量那份清單的每一次執行並合併，所以數字涵蓋每一個 seed。[完整細節 →](https://github.com/anlit75/c4o-core/blob/main/docs/commands.md#code-coverage-coverage)

## slack 為負值的時候

負 slack 代表設計沒有滿足 `config.yaml` 裡的時脈。**你自己能用的答案有兩種。** 第一種是給設計更多時間：把 `CLOCK_PERIOD` 調大，重跑 `make gds`。第二種是把慢的那條路徑縮短：插 pipeline，或把邏輯移出去。哪一種才對，取決於那個時脈速度是需求還是猜的。第一個設計通常是猜的。

這兩種答案改的都是設計或它的約束。**實體層面的答案是 placement density、clock tree 的目標、resizer margin 和繞線努力度。** 它們屬於 LibreLane，也真的存在，但這份指南不涵蓋。`config.yaml` 一個都沒設，[設定參考](#設定參考)也停在 LibreLane 自己的變數開始的地方。如果你是為了練手動收時序而來，那一塊要讀 LibreLane 的文件。

第三種答案是約束本身。失敗的那條路徑可能根本不該被算時序。流程假設的 input delay 也可能不是你板子上的那一個。這些問題怎麼改設計都修不好。SDC 檔才修得好，[設定參考](#設定參考)裡寫了怎麼給一份。

想知道*哪裡*慢，就讀流程已經寫好的時序報告：

```bash
cat runs/*/*-openroad-stapostpnr/*ss_*/checks.rpt
```

每個時序 corner 有一個檔。hold 是相反的問題：setup 在慢的 corner 失敗，hold 在快的 corner 失敗。

```bash
cat runs/*/*-openroad-stapostpnr/*ff_*/checks.rpt    # hold
ls -d runs/*/*-openroad-stapostpnr/*/                # 這次到底跑了哪些
```

上面每個 glob 都會對到不只一個檔。這個設計跑一次會產生九個 corner 目錄：三個 PVT 點（`ss`、`tt`、`ff`）各配三個連線 corner（`min`、`nom`、`max`）。所以 `cat` 會把三份報告接在一起印出來，不會告訴你哪一份最差。最差的要自己找，跟你平常從 summary 找一樣。

每一份報告裡，最差路徑都會列出它經過的每一個閘，以及每一個閘的延遲。你可以從那裡看出時間花在哪裡。

## 幫你自己的設計寫測試平台

`tb/test_blinky_cocotb.py` 是一份完整的範例。下面是它的基本骨架：能夠真的失敗的最小測試平台。

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

@cocotb.test()
async def result_is_high_after_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())   # 100 MHz 時脈
    dut.rst.value = 1
    await ClockCycles(dut.clk, 2)
    dut.rst.value = 0

    await ClockCycles(dut.clk, 1)
    await Timer(3, units="ns")     # 等輸出穩定
    assert dut.result.value == 1, f"result should be high after reset, got {dut.result.value}"
```

把檔案列在 `"//COCOTB_TESTS"`。讓你的 RTL 宣告 `` `timescale ``（見[換成你自己的設計](#換成你自己的設計)），因為 `10, units="ns"` 的時脈需要它。

真正在做事的是三個地方：

* **`assert` 才會讓壞掉的設計變成失敗的 CI。** 就算有測試失敗，模擬器還是回傳 0。`make cocotb` 讀的是 cocotb 寫出的結果檔，那裡有測試失敗就回傳非零。一個印出失敗卻沒有 assert 的測試只是裝飾。
* **邊緣之後的 `Timer`。** `ClockCycles` 是*在*邊緣當下恢復，此時設計的輸出還沒變。在那裡讀到的是上一個 cycle 的值。在閘級電路上，輸出還要再晚幾 ns 才變。相對檢查照樣會過，所以這個錯誤很難察覺。等待的時間要小於半個時脈週期。
* **`make cocotb WAVES=1` 才會產生波形。** 沒有 `WAVES=1`，`make cocotb` 什麼都不會輸出。上面那個斷言失敗的時候，就加上 `WAVES=1` 再跑一次。

試試看。把 `rtl/blinky.v` 改壞，執行 `make cocotb`，看它失敗。如果你從沒看過一個測試平台失敗，你就不知道它有沒有用。

**這就是整套方法，而且對任何設計都成立。** 一次改壞一個地方，然後跑測試。確認你瞄準的那個測試會失敗，而且訊息你看得懂。然後執行 `git checkout -- rtl/blinky.v`，再改壞下一個地方。

你學到的不是「測試都過了」。你學到的是哪個測試抓得到哪種錯。你也學到哪裡沒有任何測試抓得到：那就是你還沒寫的測試。這是「我的測試到底有沒有在檢查設計」唯一的答案，因為一個不會失敗的測試什麼都告訴不了你。

## 測試失敗的時候：去看波形

`make cocotb WAVES=1` 會寫出 `build/<DESIGN_NAME>.vcd`，裡面有你設計的每一條訊號在每一個 cycle 的值。沒有 `WAVES=1`，`make cocotb` 不會寫 VCD。檔案裡的名字從設計頂層開始，例如 `blinky.count`。用 GTKWave 打開，或用 Dev Container 已經裝好的 **WaveTrace** 擴充套件（直接點那個 `.vcd` 檔）。失敗的斷言告訴你設計*錯了*。波形告訴你*為什麼*。

`*.vcd` 在 `.gitignore` 裡。CI 不會寫 VCD。只在 CI 上失敗的測試，要用 CI log 裡的 seed 在本機跑 `make cocotb WAVES=1 SEED=<seed>` 來檢查。

## 用 Python 寫測試平台

`make cocotb` 執行 [cocotb](https://www.cocotb.org/) 測試：用 Python coroutine 透過模擬器驅動設計。`make gatesim` 在閘級電路上跑同樣的檔案。

```bash
make cocotb
```

`tb/` 裡的兩個檔案只碰 `dut.clk`、`dut.rst` 和 `dut.led`。它們不讀 `dut.count`，也不強制寫入它。你的測試也只碰設計的接腳，這樣它們在閘級電路上也能跑。[為什麼 →](#模擬閘級電路而不只是-rtl)

沒有計數器可以碰，測試就只能等 `led` 變化。reset 之後，經過 2^(`WIDTH`-1) 個時脈週期，`led` 才會上升。每個 cycle 都花模擬時間，所以 `rtl/blinky.v` 的 `WIDTH` 很小。板子的時脈需要更寬的計數器，那個檔案裡的註解寫了要多寬。測試要等那麼久，時間會長得離譜。

`tb/test_blinky_cocotb.py` 有四個 directed test。一個檢查 reset 讓 `led` 維持低電位。一個檢查 reset 放開之後，`led` 剛好在 2^(`WIDTH`-1) 個 cycle 上升，不早也不晚一個 cycle。一個檢查完整的一個週期。一個檢查週期中間的 reset。`led` 必須不等時脈邊緣就回到低電位，計數也要重新開始。

兩個測試檔都重複寫了 `WIDTH`，因為 netlist 沒有參數可以讀。這個常數要和 `rtl/blinky.v` 的 `WIDTH` 保持相同。

## 隨機刺激與參考模型

`tb/test_blinky_random.py` 是驗證的另一半。directed test 在某人挑的幾個時刻做斷言。這一支測試則建立一個「設計應該怎麼動」的模型。它在沒有人手寫的刺激下，每個 cycle 都拿設計和模型比對一次。

它有三個部分，每個大約十行：

* **模型**是 `BlinkyModel`：用 Python 把 blinky 的行為再寫一次。它刻意不是 RTL 的逐行翻譯。如果模型把設計的錯誤照抄一遍，它在每一點上都會同意設計，也就永遠抓不到任何錯。
* **刺激**是先跑到 `led` 上升的第一段，reset 之後的第二次上升，接著是隨機的 reset 脈衝。第一段確保一次執行不會整場盯著一條不動的訊號。
* **scoreboard** 在每個時脈之後把 `led` 和模型比對。失敗時印出第幾個 cycle、兩邊的值，以及模型的計數。

```bash
make cocotb                   # 每次換一個 seed
make cocotb SEED=1789965785   # 完全重現某一次
```

cocotb 會 seed Python 的 `random`，並把用的 seed 印出來。所以 CI 上的失敗可以照著那一行 log 在你的機器上重現。`make gatesim SEED=1789965785` 用同樣的方式重現一次閘級執行。

`led` 從頭到尾沒動過的話，這個測試也會失敗。通過的 cycle 如果盯著一條常數訊號，什麼都沒證明。一個會為此回報 PASS 的測試套件，正是這個專案花最多力氣在避免的東西。

它不檢查 reset 是否不等時脈邊緣就生效。刺激在下降緣動 `rst`，下一個下降緣才讀 `led`。所以非同步 reset 和同步 reset 在這裡看起來一樣。directed test `reset_in_the_middle_restarts_the_count` 檢查這一點。reset 的*時序*屬於靜態時序：recovery 和 removal。那九行摘要沒有它，因為摘要裡那兩列 slack 是 setup 和 hold，是不同的檢查。per-corner 報告有它，而且放在獨立的 path group：

```bash
grep -A12 'Path Group: asynchronous' runs/*/*-openroad-stapostpnr/*/checks.rpt
```

這是量過的，不是猜的。這個設計的一次 CI 執行在九份 corner 報告裡都產出了 `recovery check against rising-edge clock clk`。CI 每次都會把它在那裡找到的內容印出來。同步 reset 的設計在那個 path group 裡什麼都沒有。那對它來說是正確的答案，不是缺漏。

## 多個 seed

一個 seed 是一次隨機執行。`make regress` 執行一份測試清單，每個測試跑多個 seed。清單是 `tb/regression.yaml`，由 `config.yaml` 的 `"//REGRESSION"` 指定。每一項有一個 `test`，可以是 `"//COCOTB_TESTS"` 的一個模組，或寫成 `<module>.<function>` 的單一測試，另有選用的 `seeds`。RTL 只編譯一次。

```bash
make regress                  # 整份清單，從新的 base seed 開始
make regress SEED=1789965785  # 整份清單再跑一次，用同樣的 seed
```

指令會印出 base seed，以及每一項通過的次數表。一次失敗不會讓其他執行停下來，結束碼是 1。每一次失敗的執行，指令都會印出重現它的方法：

```text
make cocotb SEED=910098751 TEST=test_blinky_random
```

CI 在每個 pull request 都會跑這份清單。要讓新測試也在其中，就加一項。[完整細節 →](https://github.com/anlit75/c4o-core/blob/main/docs/commands.md#many-seeds-regress)

## 加入 Verilog 測試平台

這個模板不附 Verilog 測試平台，但路還是開著的。把檔案放進 `tb/`，再列出來：

```yaml
"//TEST_FILES":
  - dir::tb/tb_my_design.v
```

`make sim` 會跑它，`make all` 和 CI 也會。檢查失敗時必須呼叫 `$fatal`。`$display` 印完就繼續跑，模擬器回傳 0，但 `$fatal` 會回傳非零，`make sim` 讀的就是這個回傳值。`$dumpfile` 和 `$dumpvars` 要由你自己寫。

`"//TEST_FILES"` 接受萬用字元。Icarus 會把每一個沒有被其他模組實例化的模組各自當成一個 root。所以有一個以上的測試平台時，第一個 `$finish` 就會結束整場模擬，其餘的測試平台根本沒跑。對到超過一個檔案時，用 `"//SIM_TOP"` 指定你要的那一個測試平台。沒有設定的話，`make sim` 會停下來並報錯，要你設定它。一次 `make sim` 只跑一個頂層模組。

要在閘級電路上跑 Verilog 測試平台，就把它列在 `"//GATE_TESTS"`。這樣 `make gatesim` 會跑它，不跑 cocotb 測試。`"//GATE_TOP"` 指定它的頂層模組，用法和 `"//SIM_TOP"` 一樣。合成會把參數固定下來，所以閘級測試平台不能像 RTL 的那樣縮小設計。

## 模擬閘級電路，而不只是 RTL

`make cocotb` 告訴你寫的 Verilog 行為正確。它沒有告訴你工具從中產生的 netlist 對不對。latch 被誤推斷、reset 處理方式、合成器如何解讀有歧義的 `always` 區塊，這些都夾在兩者之間。從 RTL 看不出這些。

`make gatesim` 補上這一段。它拿 `make gds` 留下的閘級 netlist（`runs/<tag>/final/nl/`），對著 Sky130 元件自己的 Verilog model，跑同樣的 cocotb 測試。`<tag>` 是這次執行的目錄：沒有自己命名的話就是 `<DESIGN_NAME>_run`。判定寫在 `build/cocotb-gl-results.xml`。

```bash
make gds       # 產生 netlist
make gatesim   # 在它上面跑測試
```

同樣的檔案能跑，是因為它們只碰接腳。合成會把參數固定下來，也會拿掉內部訊號的名字。netlist 裡沒有 `WIDTH` 可以讀，也沒有 `count` 可以寫。任何伸手進設計內部的東西在 RTL 上能用，到這一步就不能用。讓你看到這件事，是這一步存在的理由之一。

`rtl/blinky.v` 的 `WIDTH` 是 16，也是出於這個原因。只看得到接腳的測試必須等 `led` 上升，而閘級電路跑得比 RTL 慢。`WIDTH` 小的時候，等待的時間夠短，CI 才能在每個 pull request 都跑這些測試。

**這是功能驗證，不是時序驗證。** 這裡沒有任何地方做 SDF back-annotation。元件是零延遲切換的，所以這次模擬看不到只在真實延遲下才出現的競態。它看得到合成做的每一個決定：被推論出來的 latch、reset 的實作方式，以及有歧義的 `always` 區塊被怎麼解讀。

時序是 STA 的工作，在 `make gds` 裡，答案在上面那些 per-corner 報告。有些流程把 SDF-annotated 閘級模擬當成時序的最後一道關卡。這一步不是那道關卡。

CI 在每個事件都對閘級電路跑 cocotb 測試，pull request 也不例外。接著它拿這次的通過、失敗、跳過數量和 RTL 那次比對，不同就失敗。Verilog 閘級測試平台維持舊的規則：CI 只在推送和 `v*` tag 時跑它，不是每個 pull request 都跑。

## 不重跑整條流程的迭代方式

floorplan 相關的參數（`FP_CORE_UTIL`、die 的大小、擺放）不需要重做合成。用 LibreLane 自己的旗標，從 floorplan 恢復上次的執行：

```bash
make gds LIBRELANE_ARGS="--from OpenROAD.Floorplan --with-initial-state runs/blinky_run/13-openroad-floorplan/state_in.json"
```

`--from` 接的是 LibreLane 的 step id。`--with-initial-state` 接的是那個步驟在上次執行收到的狀態：那個步驟目錄裡的 `state_in.json`。沒有這個檔案，LibreLane 會從已經做完的設計開始，流程會失敗。`runs/<tag>/` 裡的目錄名稱就是小寫的 step id，所以你可以從任何一個步驟恢復。

這個指令讀的是 `runs/` 裡上一次的執行結果。所以 `make clean` 會保留 `runs/`，只有 `make distclean` 會清掉它。

LibreLane 會把恢復後重跑的步驟接在舊步驟後面，編號接著往下排。恢復之後，每個重跑過的步驟在執行目錄裡會有兩個目錄，這份指南裡的 glob 兩個都會對到。編號比較大的那個是新的。

不加 `--from` 的 `make gds` 是完整執行。它會先刪掉上一次的執行。

你必須知道你的修改影響哪些步驟。排在 `--from` 之前的步驟不會重跑，所以看不到你的修改。

**`CLOCK_PERIOD` 不在裡面。** 時脈是合成的輸入，合成會依它挑元件尺寸、插 buffer。從 floorplan 恢復的話，流程量到的是「**舊**週期合成出來的閘，在新週期下的時序」。這樣時序可能會收，但它對「你實際會拿到的那個設計」什麼都沒說。改時脈就要完整重跑 `make gds`，不加 `--from`。[slack 為負值的時候](#slack-為負值的時候)那節叫你這樣做，原因就在這裡。

## 看看電路長什麼樣

```bash
make schematic
```

這個指令畫出 `build/schematic.svg`：你的設計以 flop、加法器、多工器呈現，帶著你取的名字。用瀏覽器開，或在 VS Code 裡點一下。它是 SVG，不需要特別的工具就能看。

這不是 netlist 的圖。`make synth` 會跑完整合成，產出一長串通用邏輯閘，沒有人能從那些閘看懂自己的設計。`make schematic` 停得更早，停在電路還看得出原始碼樣子的地方。

**是通用閘，不是 Sky130 的元件。** `make synth` 只映射到 Yosys 自己的 cell 就停了。範例的 `build/synthesis.json` 裡只有這種 cell（`$_DFF_PP0_`、`$_OR_`、`$_XOR_` 之類），一顆 `sky130_` 都沒有，因為這裡沒有東西給 Yosys liberty 檔。這個指令回答的是「它合得起來嗎、大概多少邏輯」。它回答不了面積和時序。

`make report` 裡合成之後的 instance 數量是 `make gds` 裡 LibreLane 自己對著真實元件庫合成的結果。它是另一個數字，兩者不能互相比較。

這個指令不到一秒，所以每改一次都可以跑，和 `make gds` 不一樣。

## 在容器內開發

本專案附有 [Dev Container](https://containers.dev/)。用 GitHub Codespaces 開啟，或在 VS Code 選擇「在容器中重新開啟」。你會拿到與 CI 相同的映像檔，Verilog 相關擴充套件也已裝好。`Makefile` 會偵測到自己已在容器內。它會直接呼叫工具，不會再疊一層容器。

`make gds` 在這裡面也能跑，因為容器內建了一個自己的 Docker daemon 給 LibreLane sidecar 用。如果 `make gds` 說它找不到 Docker daemon，就重建一次 Dev Container。

兩件要知道的事：

* **容器內以 `root` 執行。** 在 Linux 主機上，它寫進 `build/` 的檔案擁有者會是 `root`，所以從主機執行 `make clean` 可能需要 `sudo`。改用一般使用者會讓 Codespaces 無法連線。
* **在 Codespace 裡要注意磁碟。** 內部 daemon 有自己的映像檔儲存區。它會重拉一份 LibreLane 映像檔，不跟主機共用。Sky130 PDK 還要再加 3GB。在最小規格的 Codespace 上，這已經佔掉大半個磁碟。選大一點的規格，或者改從自己的主機跑 `make gds`。

**一份 PDK 可以給好幾個 checkout 用。** Sky130 裝起來是 3GB，而且每次都一模一樣。`PDK_ROOT` 會把兩邊同時指到同一個目錄：安裝，以及讀它的 LibreLane sidecar。

```bash
make gds PDK_ROOT=/opt/sky130
```

不設它的話，每個 clone 都會在自己的 `pdks/` 底下留一份。設了它，共用的機器，或是放了不只一個設計的機器，那 3GB 就只存一次。這需要 c4o-core 2.8.2 或更新的版本，`Makefile` 釘的版本已經符合。

習慣用自己的編輯器？`make shell` 可以從任何終端機進入同一個映像檔。

## 複製之後怎麼拿到修正

從這個模板建立的 repo 和模板沒有共同的 git 歷史。模板改了，GitHub 不會改你的 repo。有三個部分不用你動手就會拿到修正：

| 部分 | 修正怎麼到你手上 |
|---|---|
| 工具 | `Makefile` 和 `.devcontainer/devcontainer.json` 都寫著映像檔 `ghcr.io/anlit75/c4o-core:2.22`。2.22 的修正會在下一次拉映像檔時到。2.23 發佈之後，要改這兩行才拿得到它的修正。這兩行不一樣的話 CI 會失敗。 |
| make 指令 | `Makefile` 從映像檔引入它的規則。像 `make gds` 這樣的指令有修正時，修正會隨映像檔到。見[你自己的 target 可以用什麼](https://github.com/anlit75/c4o-core/blob/main/docs/makefile.md)。 |
| CI 的步驟 | `.github/workflows/verify.yml` 呼叫 c4o-core 的 action，版本是 `@v2`。action 的修正會在下一次執行時到。見[每個 action 做什麼](https://github.com/anlit75/c4o-core/blob/main/docs/actions.md)。 |

其他部分在你複製之後就不會再變。它們是 `Makefile` 裡的映像檔名稱和 stub 文字、workflow 的觸發條件和 job、`devcontainer.json`，以及文件。

你自己的 target 放在 `Makefile` 的最後面，`include` 那一行的下面。

你自己的步驟放在 `verify.yml` 裡的 action 之間。它們在同一個 job 裡執行，所以讀得到 `runs/` 和 `build/`。

`verify.yml` 裡有些步驟帶著 `Template only` 的註解。它們檢查的是這個模板的 README 和指南裡的句子。它們只在模板 repo 執行，在你的 repo 會被跳過。你可以把它們刪掉。

## 設定參考

`config.yaml` 是一份 [LibreLane](https://github.com/librelane/librelane) 配置檔。不屬於 LibreLane 的 key 前面加 `//`。LibreLane 會完全忽略這些 key，所以一份檔案能同時給兩個工具用。

| Key | 作用 |
|---|---|
| `DESIGN_NAME` | 你的頂層模組名稱。其他地方都從這裡讀。 |
| `VERILOG_FILES` | 可合成的原始碼。一行一個檔案：LibreLane 會把每一項當成字面路徑驗證，不展開 `**`。 |
| `"//COCOTB_TESTS"` | 給 `make cocotb` 和 `make gatesim` 的 Python 測試平台。可以用萬用字元。 |
| `"//REGRESSION"` | `make regress` 的測試清單：一個列出 `test` 和 `seeds` 的 YAML 檔。選用。 |
| `"//TEST_FILES"` | 給 `make sim` 的 Verilog 測試平台。選用。可以用萬用字元。 |
| `"//SIM_TOP"` | 要 elaborate 的 Verilog 測試平台模組。`"//TEST_FILES"` 對到超過一個檔案時必填。 |
| `"//GATE_TESTS"` / `"//GATE_TOP"` | 給 `make gatesim` 的 Verilog 閘級測試平台。選用。設了之後，`make gatesim` 跑它們，不跑 cocotb 測試。 |
| `"//DESCRIPTION"` | 用一句話說明你的設計是什麼。它出現在結果網頁標題下方，以及分享連結的預覽裡。選用。 |
| `CLOCK_PORT` / `CLOCK_PERIOD` | 要約束的時脈，以及它的週期（ns）。 |
| `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE` | 你自己的時序約束，當上面那兩個 key 不夠用的時候。見下。 |
| `FP_SIZING` / `FP_CORE_UTIL` | die 的尺寸怎麼決定。見下。 |
| `PDK` / `STD_CELL_LIBRARY` | Sky130 與它的標準元件庫。不要改。 |

**晶片尺寸會自己調整。** `FP_SIZING: relative` 依 `FP_CORE_UTIL` 算出 floorplan。這個 key 是 core 要放多滿，單位是百分比：這裡的 40 就是 40%。所以較大的設計會得到較大的 die，不會得到「放不下」的錯誤。繞線太擠就調低。想要更小的晶片就調高。

仍然可以固定尺寸。把 `FP_SIZING` 改成 `absolute`，並加上 `DIE_AREA: [0, 0, 寬, 高]`。用 relative 的時候不要把 `DIE_AREA` 留在檔案裡。流程已經不讀它了，但 GDS stream-out 還是會照它畫晶片邊界。signoff 就會在一個沒有其他東西用到的邊界上失敗。

檔案中其餘的 key 都屬於 LibreLane。完整清單見[它的文件](https://librelane.readthedocs.io/)。這個引擎讀哪些，見 [c4o-core README](https://github.com/anlit75/c4o-core)。

**這張表沒列的 key 一樣有效。** 沒有任何東西會過濾 `config.yaml`。c4o-core 只檢查它需要的那幾個 key 在不在、值合不合理。然後 `make gds` 把整份檔案原封不動交給 LibreLane。所以 `PL_TARGET_DENSITY`、`CTS_*`、`GRT_*` 以及 LibreLane 其餘的變數都可以直接加進去，而且會生效。這張表列的是**這個 repo 有理由去設的** key，不是**你被允許設的**所有 key。

**時序約束就只有兩個 key，而 SDC 檔可以取代它們。** 這個 repo 只約束 `CLOCK_PORT` 和 `CLOCK_PERIOD`。靜態時序工具還需要更多：input/output delay、transition 和 fanout 上限、clock uncertainty，以及所有的例外。這些全都來自 LibreLane 的預設值。單一時脈、沒有 false path 的設計用預設值就夠，其他任何設計都遠遠不夠。要自己寫約束，就把檔案指出來：

```yaml
PNR_SDC_FILE: dir::constraints/pnr.sdc
SIGNOFF_SDC_FILE: dir::constraints/signoff.sdc
```

這兩個是 LibreLane 自己的路徑變數，所以它們走上面那條直通進去，不需要 c4o-core 做任何事。分成兩個 key 是有原因的。你可以把 place and route 約束得更緊，再用設計真正必須滿足的條件去簽核。CI 會斷言釘住的那版 LibreLane 仍然宣告這兩個 key，所以升版不會讓這段話悄悄變成錯的。CI 不會檢查流程有沒有讀你的檔案。那件事只有用了這個檔案跑一次才知道。

**第二個時脈放在那個檔案裡，不在這一份。** `CLOCK_PORT` 和 `CLOCK_PERIOD` 都是單一值，而 c4o-core 在開跑之前會要求這兩個都在。所以雙時脈的設計在這裡指定其中一個，並在自己的 SDC 裡把兩個都 create 出來。那些便利 key 只約束這份檔案裡的那一對。設計真正被簽核的依據是 SDC。

**Macro 是 LibreLane 的事，這份指南不涵蓋。** 一顆硬 macro（SRAM、PLL、別人做的 block）是透過 LibreLane 的 `MACROS` 變數進來的。那個變數是一個定義的字典，每一項帶自己的 GDS 和 LEF view。macro 還會連帶帶進跨 macro 的電源繞線和 placement blockage。因為是直通的，你可以直接從 `config.yaml` 做這件事，這裡什麼都不用改。這個 repo 能提供的，是一個小到可以一次讀完的設計，那是另一個極端。
