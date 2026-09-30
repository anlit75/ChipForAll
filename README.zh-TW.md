# ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

*[English](README.md)*

**開源晶片的驗證與 CI 範本，一套現成的起點。** 模擬你的 RTL、用 Python 驅動它、模擬它合成出來的閘級電路、讀懂 signoff 數字——實體流程交給 LibreLane。每件事一個 `make` 指令，什麼都不用裝。

範例設計是 Verilog 寫的。你不必先會 Verilog 才能跑完整條流程看結果，但要改設計或寫測試就需要——[前置作業](#前置作業)講得更清楚。

## ✨ 特色

* **🧪 真的會失敗的測試平台**：`make sim` 寫 Verilog，`make cocotb` 寫 Python。兩者該紅的時候都會回傳非零——在壞掉的設計上還會通過的測試，比沒有測試更糟。
* **🔬 閘級模擬**：`make gatesim` 拿你的測試去跑合成真正產出的 netlist。合成器會不會意外推論出一顆你沒寫的 latch、reset 怎麼被實作出來，都發生在 RTL 和那些閘之間，從 RTL 完全看不出來。
* **📊 看得懂的 signoff**：`make report` 從沒人會打開的 300 個 key 的 `metrics.json` 裡，挑出真正要看的幾個數字——面積、時序、功耗、DRC/LVS/antenna。
* **✅ CI 全部都跑**：一份 GitHub Actions 工作流，每次 push 都 lint、模擬、合成、產 GDS、再重跑閘級模擬。
* **🐳 什麼都不用裝**：Docker，或 Dev Container / Codespace。`make gds` 三種都能跑。

### 這個專案不是什麼

實體流程——RTL 到 GDSII——是 [LibreLane](https://github.com/librelane/librelane) 的，`make gds` 只是薄薄一層包裝。如果你只想要一份 layout，LibreLane 用 `--dockerized` 就能單獨跑，你不需要這個專案。

LibreLane 沒有涵蓋的是**模擬與驗證**。那才是這個起手式加上去的東西，外加跑它們的 CI 和 Dev Container。

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

流程的形狀一樣，詞彙也轉得過去；但你履歷上的工具名稱不會是職缺條列的那幾個，所以要講清楚你用的是哪一套。

**在找一個完整的驗證範例嗎？** 這個 repo 的測試是一份 Verilog testbench 加兩份 cocotb 的——足以示範「一個會失敗的測試長什麼樣」，但不是一套分層的驗證環境。[c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm) 才是：一個跑在真實 UART 上的 pyuvm 環境，有 agent、driver、monitor、scoreboard，以及從 SystemRDL 生成的暫存器模型，而且是從這個模板建出來的。

**這裡做出來的東西你可以公開。** 製程是 [Sky130](https://github.com/google/skywater-pdk)，SkyWater 用 Apache 2.0 開放出來的 PDK，沒有 NDA——所以 layout、面積、時序數字、GDS 全都能放進 GitHub、作品集或文章裡。foundry 在保密條款下給的 PDK 不允許這些事，所以有那種 PDK 的人會來這裡做第二份可以公開的結果——而從來沒有過那種 PDK 的人，在這裡才有結果可做。

## 🚀 快速啟動

### 前置作業
* Docker (Desktop 或 Engine)
* Make
* Git

*……或者以上都不需要：用 GitHub Codespace 打開，一切都已經就緒。*

**在 Apple Silicon 上，有一部分會走模擬。** c4o-core 的映像檔只建 `amd64`——一台
runner、沒有 `platforms:`——所以在 `arm64` 機器上，`lint`、`sim`、`cocotb`、`synth`
和 `gatesim` 是透過模擬跑的。`make gds` 不是：最重的那一步跑的是 LibreLane 自己的映像
檔，而它有出 `arm64`，所以那一步是原生的。被模擬的那幾個會慢多少，這裡沒有量過。
Codespace 全程都是 `amd64`。

**有一個前置條件不是下載就有的：一點 Verilog。** 不用多——看得懂一個 `always @(posedge clk)` 區塊、一個 `<=` 指定、一個 `$fatal` 就夠。在 [HDLBits](https://hdlbits.01xz.net/) 上大約是 *Verilog Language* 那一段，不是整個網站。

**SystemVerilog 也讀得進來。** `logic`、`always_ff` 和可合成的那個子集在每個指令下都
能用，條件是 c4o-core 2.8.3 或更新——釘住的 `2.9` 標籤就會給你。在那之前，同一個檔案會
過 `make cocotb` 和 `make gds`，卻掛在 `make sim` 和 `make synth`。仍然不行的是把
`interface` 當成模組邊界——yosys 讀得懂宣告，然後在 `hierarchy` 階段失敗——所以 interface
留在測試平台裡，不要放在可合成模組之間。

**你不需要先會它才能開始。** `make gds` 直接就能把範例跑完，印出真實的面積、時序和功耗；`make all` 會讓你看到測試通過。先做這件事是值得的，因為它告訴你整套工具在你的機器上是通的。真正需要 Verilog 的是下一步：改 `src/blinky.v`、判斷一個「通過」的測試到底證明了什麼、或者自己寫一個。先跑再學，然後回來做那一步。

### 1. 做一份自己的副本

這個儲存庫是 **GitHub 範本（template）**。按 **Use this template → Create a new repository**，然後 clone 你自己的副本：

```bash
git clone https://github.com/<你>/<你的儲存庫>.git
cd <你的儲存庫>
```

### 2. 執行完整流程

```bash
make gds
```

*第一次執行會先把 Sky130 PDK（約 3GB）抓下來才開始動——網路快大約二十分鐘，慢就更久。
流程本身大約三分鐘，那也是第一次以後每一次的成本。想先把下載做完，單獨跑 `make pdk`。*

### 3. 換成你自己的設計

範例是一個 blinky——時脈除頻器。要換成你自己的設計，有五個地方必須互相對上，其他都不用動：

| 要改的 | 在哪裡 |
|---|---|
| 你的 RTL | `src/`，列在 `config.yaml` 的 `VERILOG_FILES` |
| `DESIGN_NAME` | `config.yaml`——必須和你的頂層模組同名 |
| 你的測試平台 | `test/`，列在 `"//TEST_FILES"` 和 `"//COCOTB_TESTS"` |
| 閘級測試平台 | `test/gate/`，列在 `"//GATE_TESTS"` |
| 波形圖的訊號 | `"//WAVE_SIGNALS"`，從你的測試平台頂層往下寫 |

沒有別的地方寫死設計名稱：`Makefile` 和 CI 工作流都從 `config.yaml` 讀 `DESIGN_NAME`。

**最後三列是選用的。** 把 `"//COCOTB_TESTS"`、`"//GATE_TESTS"` 或 `"//WAVE_SIGNALS"` 從 `config.yaml` 刪掉——連 key 那一行**和它下面縮排的路徑**一起刪，只刪 key 會留下一個沒有主人的列表項，YAML 會直接解析失敗——CI 就會跳過那一類測試而不是失敗。但如果把 key 留著卻指向不存在的檔案，CI 還是會失敗，這是對的：你要求了不存在的測試。

**第二個 Verilog 測試平台要多一個 key。** `"//TEST_FILES"` 吃萬用字元，而 Icarus 會把每一個沒有被實例化的模組各自當成一個 root——所以第一個 `$finish` 就會結束整場模擬，其餘的根本沒跑。一旦對到超過一個檔案，就用 `"//SIM_TOP"` 指定你要的那一個。

第一列弄錯的話，你會立刻知道，而不是等到 `make gds` 跑到一半才發現：

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

## 📖 指令

| 指令 | 說明 | 輸出 |
|---|---|---|
| `make all` | `lint`、`sim`、`cocotb`、`synth`——幾秒內跑完的全部。 | `終端機` |
| `make lint` | 用 Verilator 檢查 Verilog。 | `終端機` |
| `make sim` | 用 Icarus Verilog 跑 Verilog 測試平台。 | `build/wave.vcd` |
| `make cocotb` | 執行 Python (cocotb) 測試平台。 | `build/cocotb-results.xml` |
| `make synth` | 用 Yosys 把 RTL 合成成通用邏輯閘——沒有面積、沒有時序，見[指南](docs/guide.zh-TW.md#看看電路長什麼樣)。腳本是固定的一份；想自己操作 Yosys 就用 `make shell`。 | `build/synthesis.json` |
| `make pdk` | 安裝 Sky130 PDK。`make gds` 會自己叫它；單獨跑可以把那 3GB 的下載提前做掉。 | `pdks/` |
| `make schematic` | 把電路畫成到處都開得了的 SVG。 | `build/schematic.svg` |
| `make gds` | 用 LibreLane 產生實體版圖。大約三分鐘，第一次還要加上 PDK 下載。 | `build/<DESIGN_NAME>.gds` |
| `make gatesim` | 對合成後的 netlist 重跑模擬，需先執行 `make gds`。 | `終端機` |
| `make report` | 顯示上次 `make gds` 的面積、時序、功耗與 signoff。 | `終端機` |
| `make site` | 把 `report`、版圖、電路圖和 cocotb 結果放進同一個網頁。 | `build/site/index.html` |
| `make shell` | 進入 c4o-core 容器的互動式 shell。 | — |
| `make clean` | 清除 `build/`。保留 `runs/`，`report` 和 `gatesim` 要讀它。 | — |
| `make distclean` | 清除 `build/` 和 `runs/`。 | — |

`make help` 會在終端機列出這些指令。

## 📊 看懂執行結果

`make gds` 結束時會直接印出這次流程量到的數字，不必自己去翻檔案：

```
  blinky

  die              69.5 x 80.2 um  (5573 um^2)
  utilization      57.1%
  standard cells   198
  setup slack      +4.70 ns  (0 violations)
  hold slack       +0.11 ns  (0 violations)
  power            0.248 mW  (nom_tt_025C_1v80)
  signoff          clean  (Magic DRC, KLayout DRC, LVS, antenna, XOR)
  lint warnings    0
  layout           runs/blinky_run/final/render/blinky.png
```

那是範例設計的數字，出自某一版 PDK。你的會不一樣；要看的是那些欄位。

**`signoff`** 是那一列沒人會說的話：你的版圖通過了可製造性檢查。這裡釘的 LibreLane 3.0.14 預設讓每一項都直接中止流程（`ERROR_ON_MAGIC_DRC` 那一族預設都是 `True`），而 `config.yaml` 沒有覆寫任何一個，所以能跑到這一行就代表都過了。這是那一版的預設行為，不是這個 repo 掛保證的事——升版之後要自己確認一次。`clean` 只是把它講出來，並列出它實際看到哪幾項。有問題的時候它會改成指名道姓：`2 Magic DRC, 1 LVS`。

**`layout`** 是流程幫你的晶片畫的 PNG。打開來看看。

其中 `XOR` 不是製程規則檢查，是兩套工具把同一份 layout 各自寫成 GDS 之後互相比對——一致才算過。它抓的是其中任一個寫出器的 stream-out bug。它不是兩家原廠工具對一份設計各自下判斷——兩邊讀的是同一個資料庫——所以不要把 XOR 乾淨當成對版圖本身的第二意見。

**slack 為正值**代表設計滿足 `config.yaml` 裡設定的時脈；負值代表沒滿足，而流程不會因此停下來——所以一次成功結束的執行，仍然可能正在告訴你它沒達標。[該怎麼辦](docs/guide.zh-TW.md#slack-為負值的時候)寫在指南裡。

**這九行是摘要，不是簽核報告。** 它從 300 個 key 的 `metrics.json` 裡挑出來，所以它沒
告訴你的比告訴你的多：clock uncertainty 和 derate 設多少、clock tree 的 skew 是多少、九
個 corner（`ss`/`tt`/`ff` 各配 `min`/`nom`/`max` 連線）裡是哪一個給出這個 slack。這些全是 LibreLane 的預設值——`config.yaml` 一個都沒設——而且全都
在 `runs/` 底下，一個 step 一個目錄。差別是實務上的：一個 `+0.11 ns` 的 hold slack，在
自己填 OCV derate 的簽核流程裡不會被當成「過了」。要對這些數字有商用流程等級的信心，
就去讀那些 per-corner 報告，別只讀這九行。

單獨執行 `make report` 可以再看一次，不必重跑流程。

### 發佈結果網頁

`make site` 把上面那幾行、版圖、電路圖，以及每個 cocotb 測試的結果和 seed 放進同一
個網頁 `build/site/index.html`。跑過 `make gds` 之後，頁面還會列出每一項 signoff 檢查、
OpenSTA 報出的最差 setup path、面積拆分（flip-flop、邏輯、繞線階段加進來的），以及按
sequential、combinational、clock 拆開的功耗。跑過 `make sim` 之後，還會把
`"//WAVE_SIGNALS"` 列的訊號畫成波形圖。功耗用的是 OpenSTA 預設的切換活動率，不是
你的測試平台的，所以它告訴你功耗花在哪裡，不是真實工作負載的耗電。每一塊在你跑過對應
的指令之後才會出現。

CI 每次都會產生這個網頁，並從 `main` 發佈到 GitHub Pages，網址是
`https://<你的帳號>.github.io/<你的-repo>/`。剛從 template 複製出來的 repo 沒有開
Pages，而且沒有任何 workflow 能替你打開。做一次就好：**Settings → Pages → Source:
GitHub Actions**。在那之前 CI 照樣會過，只會用一則 notice 告訴你這次沒有發佈。

## 📚 接下來

[使用指南](docs/guide.zh-TW.md)涵蓋第一次執行之後的事：

* [幫你自己的設計寫測試平台](docs/guide.zh-TW.md#幫你自己的設計寫測試平台)——能真的失敗的最小骨架
* 測試變紅的時候[去看波形](docs/guide.zh-TW.md#測試失敗的時候去看波形)
* 用 [Python 寫測試平台](docs/guide.zh-TW.md#用-python-寫測試平台)、[隨機刺激對參考模型](docs/guide.zh-TW.md#隨機刺激與參考模型)，以及[閘級模擬](docs/guide.zh-TW.md#模擬閘級電路而不只是-rtl)
* [不重跑整條流程的迭代方式](docs/guide.zh-TW.md#不重跑整條流程的迭代方式)，以及[看看電路長什麼樣](docs/guide.zh-TW.md#看看電路長什麼樣)
* [在容器內開發](docs/guide.zh-TW.md#在容器內開發)，以及[完整的設定參考](docs/guide.zh-TW.md#設定參考)

## 📂 專案架構

```text
.
├── .devcontainer/     # 🐳 VS Code Dev Container 定義
├── config.yaml        # ⚙️ 設計名稱、時脈、floorplan
├── Makefile           # 🎮 指令控制中心
├── docs/              # 📚 第一次執行之後的所有事
├── src/               # ✍️ 您的 Verilog
│   └── blinky.v
├── test/              # 🧪 您的測試平台 (Testbenches)
│   ├── tb_blinky.v              # RTL 模擬 (make sim)
│   ├── test_blinky_cocotb.py    # Python 測試平台 (make cocotb)
│   ├── test_blinky_random.py    # 隨機刺激對參考模型
│   └── gate/                    # 閘級模擬 (make gatesim)
│       └── tb_blinky_gl.v
└── build/             # 📦 所有產出的檔案 (GDS, Logs, Netlists)
```

## 📝 配置設定

`config.yaml` 是一份 [LibreLane](https://github.com/librelane/librelane) 配置檔——同一個檔案同時驅動模擬與實體設計流程。以下是你通常會改的 key：

```yaml
DESIGN_NAME: my_design

VERILOG_FILES:
  - dir::src/my_design.v

# 僅供模擬使用。LibreLane 會忽略以 '//' 開頭的 key。
"//TEST_FILES":
  - dir::test/*.v

CLOCK_PORT: clk
CLOCK_PERIOD: 10.0
```

其餘的 key（`PDK`、`FP_SIZING`、`FP_CORE_UTIL`…）用於設定實體設計流程，在需要之前請保持原樣。晶片尺寸不需要你自己決定——`FP_SIZING: relative` 會把 die 長到剛好放得下你的設計。細節見[設定參考](docs/guide.zh-TW.md#設定參考)。

---

由 **[c4o-core](https://github.com/anlit75/c4o-core)** 引擎驅動。
