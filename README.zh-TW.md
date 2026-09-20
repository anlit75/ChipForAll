# ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

**開源晶片的驗證與 CI 起手式。** 模擬你的 RTL、用 Python 驅動它、模擬它合成出來的閘級電路、讀懂 signoff 數字——實體流程交給 LibreLane。每件事一個 `make` 指令，什麼都不用裝。

## ✨ 特色

* **🧪 真的會失敗的測試平台**：`make sim` 寫 Verilog，`make cocotb` 寫 Python。在壞掉的設計上還會通過的測試，比沒有測試更糟，所以兩者該紅的時候都會回傳非零——這沒有聽起來那麼理所當然，本專案大部分的修正都花在這件事上。
* **🔬 閘級模擬**：`make gatesim` 拿你的測試去跑合成真正產出的 netlist。latch 推導、reset 處理都卡在 RTL 和那些閘之間，從 RTL 完全看不出來。
* **📊 看得懂的 signoff**：`make report` 從沒人會打開的 300 個 key 的 `metrics.json` 裡，挑出真正要看的幾個數字——面積、時序、功耗、DRC/LVS/antenna。
* **✅ CI 全部都跑**：一份 GitHub Actions 工作流，每次 push 都 lint、模擬、合成、產 GDS、再重跑閘級模擬。
* **🐳 什麼都不用裝**：Docker，或 Dev Container / Codespace。`make gds` 三種都能跑。

### 這個專案不是什麼

實體流程——RTL 到 GDSII——是 [LibreLane](https://github.com/librelane/librelane) 的，`make gds` 只是薄薄一層包裝。如果你只想要一份 layout，LibreLane 用 `--dockerized` 就能單獨跑，你不需要這個專案。

LibreLane 沒有涵蓋的是**模擬與驗證**。那才是這個起手式加上去的東西，外加跑它們的 CI 和 Dev Container。

## 🚀 快速啟動

### 前置作業
* Docker (Desktop 或 Engine)
* Make
* Git

*……或者以上都不需要：用 GitHub Codespace 打開，一切都已經就緒。*

### 1. 做一份自己的副本

這個儲存庫是 **GitHub 範本（template）**。按 **Use this template → Create a new repository**，然後 clone 你自己的副本：

```bash
git clone https://github.com/<你>/<你的儲存庫>.git
cd <你的儲存庫>
```

直接 clone 本儲存庫也能跑，但你會帶著它的 git 歷史，而且沒有地方可以 push。

### 2. 執行完整流程

將 Verilog 程式碼轉換為最終的 GDSII 佈局檔案：

```bash
make gds
```

*請稍等幾分鐘。系統將自動下載 PDK、執行電路合成（Synthesis）、佈局繞線（Place & Route）並產出佈局檔案。*

### 3. 換成你自己的設計

範例是一個 blinky——時脈除頻器。要換成你自己的設計，有四個地方必須互相對上，其他都不用動：

| 要改的 | 在哪裡 |
|---|---|
| 你的 RTL | `src/`，列在 `config.yaml` 的 `VERILOG_FILES` |
| `DESIGN_NAME` | `config.yaml`——必須和你的頂層模組同名 |
| 你的測試平台 | `test/`，列在 `"//TEST_FILES"` 和 `"//COCOTB_TESTS"` |
| 閘級測試平台 | `test/gate/`，列在 `"//GATE_TESTS"`——為什麼要分開見下文 |

沒有別的地方寫死設計名稱。`Makefile` 和 CI 工作流都從 `config.yaml` 讀 `DESIGN_NAME`，改那裡就夠了。

**最後兩列是選用的。** 把 `"//COCOTB_TESTS"` 或 `"//GATE_TESTS"` 從 `config.yaml` 刪掉，CI 就會跳過那一類測試而不是失敗。值得堅持的只有 Verilog testbench；Python 的是同一件事的另一種寫法，而閘級的是這裡最難寫的檔案——它沒辦法像 `test/tb_blinky.v` 那樣用參數把設計縮小，只能用真實位寬驅動真實的 port。

但如果把 key 留著卻指向不存在的檔案，CI 還是會失敗——這是對的，你要求了不存在的測試。


第一列弄錯的話，你會立刻知道，而不是等到 `make gds` 跑了三分鐘之後：

```console
[ERROR] DESIGN_NAME is 'my_cpu', but no module by that name is declared in
        VERILOG_FILES. Declared there: blinky.
```

## 📖 使用指南

我們提供統一的 `Makefile` 來處理所有事務。

| 指令 | 說明 | 輸出路徑 |
| --- | --- | --- |
| `make lint` | 使用 Verilator 檢查 Verilog 語法錯誤。 | `終端機輸出` |
| `make sim` | 使用 Icarus Verilog 執行模擬。 | `build/sim.vvp` |
| `make cocotb` | 執行 Python (cocotb) 測試平台。 | `build/cocotb-results.xml` |
| `make synth` | 使用 Yosys 將 RTL 進行電路合成。 | `build/synthesis.json` |
| `make schematic` | 把電路畫成到處都開得了的 SVG。 | `build/schematic.svg` |
| `make gatesim` | 對合成後的 netlist 重跑一次模擬，需先執行 `make gds`。 | `終端機輸出` |
| `make gds` | 使用 LibreLane 產生實體佈局。 | `build/<DESIGN_NAME>.gds` |
| `make report` | 顯示上次 `make gds` 的面積、時序、功耗與 DRC/LVS/antenna signoff。 | `終端機輸出` |
| `make shell` | 進入 c4o-core 容器的互動式 shell。 | `N/A` |
| `make clean` | 清除所有產出的檔案。 | `N/A` |

> **💡 注意：** 首次執行 `make gds` 時，系統會自動下載並安裝 Sky130 PDK（約 3GB）。請耐心等候！

### 看懂執行結果

`make gds` 結束時會直接印出這次流程量到的數字，不必自己去翻檔案：

```
  blinky

  die              100 x 100 um  (10000 um^2)
  utilization      29.2%
  standard cells   243
  setup slack      +4.69 ns  (0 violations)
  hold slack       +0.11 ns  (0 violations)
  power            0.292 mW
  signoff          clean  (Magic DRC, KLayout DRC, LVS, antenna, XOR)
  lint warnings    0
  layout           runs/blinky_run/final/render/blinky.png
```

**`signoff`** 是那一列沒人會說的話：你的版圖通過了可製造性檢查。LibreLane 預設
對每一項都會直接讓流程失敗，所以能跑到這一行就代表都過了——`clean` 只是把它
講出來，並列出它實際看到哪幾項。有問題的時候它會改成指名道姓：`2 Magic DRC, 1 LVS`。

**`layout`** 是流程幫你的晶片畫的 PNG。每次執行都會畫一張然後留在 run 目錄裡；
打開來看看。

slack 為正值代表設計滿足 `config.yaml` 裡設定的時脈。想再看一次而不重跑整個
流程，單獨執行 `make report` 即可。

**負值代表沒滿足**，而答案只有兩種。給設計更多時間——把 `config.yaml` 裡的
`CLOCK_PERIOD` 調大，重跑 `make gds`——或者把慢的那條路徑縮短，插 pipeline 或把
邏輯搬出去。哪一種才對，取決於那個時脈速度是需求還是隨手填的；第一個設計通常是
隨手填的。

想知道*哪裡*慢，讀流程已經寫好的時序報告：

```bash
cat runs/*/final/*.rpt          # 或到 runs/<tag>/ 底下找 STA 那幾步
```

最差路徑會連同上面經過的每一個閘一起列出來，時間就花在那裡。流程不會因為負 slack
停下來，所以一次成功結束的執行，仍然可能正在告訴你它沒達標。

### 不重跑整條流程的迭代方式

第一次 `make gds` 大約三分鐘。之後你會改的東西——`DIE_AREA`、`CLOCK_PERIOD`、
floorplan——多半不需要重做合成，所以把恢復上次執行的旗標傳給 LibreLane：

```bash
make gds LIBRELANE_ARGS="--last-run --from floorplan"
```

`runs/` 留在 LibreLane 放它的地方，這一點才是讓上面能動的關鍵。它以前每次跑完
會被搬進 `build/`，看起來比較整齊，卻悄悄讓 `--last-run` 失效——LibreLane 會去
`runs/` 找上一次的執行結果，而那裡從來沒有。`make clean` 兩個都會清掉。

### 看看電路長什麼樣

```bash
make schematic
```

畫出 `build/schematic.svg`——你的設計以 flop、加法器、多工器呈現，帶著你取的名字。
用瀏覽器開，或在 VS Code 裡點一下都行；它是 SVG，不需要任何特別的東西才能看。

這不是 netlist 的圖。`make synth` 會跑完整合成，留下幾百個技術元件，沒有人能從
那張圖看懂自己的設計。`make schematic` 停得更早，停在電路還看得出原始碼樣子的地方。

不到一秒，所以每改一次都可以跑——和 `make gds` 不一樣。

### 幫你自己的設計寫測試平台

`test/tb_blinky.v` 是一份完整的範例，讀起來也像範例。下面是它底下的骨架——
能夠真的失敗的最小測試平台：

```verilog
`timescale 1ns/1ps

module tb_my_design;

    reg clk = 0;
    reg rst = 1;
    wire result;

    my_design uut (.clk(clk), .rst(rst), .result(result));

    always #5 clk = ~clk;          // 100 MHz 時脈

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb_my_design);

        repeat (2) @(posedge clk);
        rst = 0;

        @(posedge clk);
        #1;                        // 等 non-blocking assignment 生效
        if (result !== 1'b1)
            $fatal(1, "result should be high after reset, got %b", result);

        $display("tb_my_design: PASS");
        $finish;
    end

endmodule
```

真正在做事的是三個地方：

*   **`$fatal` 才是讓壞掉的設計變成紅色 CI 的東西。** `$display` 印完就繼續跑，
    而模擬器兩種情況都回傳 0——一個回報了失敗卻沒有失敗的測試只是裝飾。`$fatal`
    會回傳非零，那才是 `make sim` 和工作流在讀的東西。
*   **邊緣之後的 `#1`。** `@(posedge clk)` 是*在*邊緣當下恢復，此時 non-blocking
    assignment 還沒生效，所以在那裡讀到的是上一拍的值。相對檢查照樣會過，這正是
    它難以察覺的原因。
*   **`$dumpfile`/`$dumpvars` 來自你**，不是來自工具。沒有它們，上面那個斷言炸掉
    的時候你沒有波形可以看。

試試看：把 `src/blinky.v` 改壞，執行 `make sim`，看著它變紅。一個你從沒看它失敗過的
測試平台，是一個你不知道它有沒有用的測試平台。

### 測試失敗的時候：去看波形

`make sim` 會寫出 `build/wave.vcd`——每一條訊號、每一個週期。用 GTKWave 打開，
或用 Dev Container 已經裝好的 **WaveTrace** 擴充套件（直接點那個 `.vcd` 檔）。
失敗的斷言告訴你設計*錯了*，波形才告訴你*為什麼*。

它來自測試平台而不是工具本身，所以你自己寫的測試平台需要這兩行才會產生波形：

```verilog
initial begin
    $dumpfile("build/wave.vcd");
    $dumpvars(0, tb_your_design);
end
```

`test/tb_blinky.v` 已經有了。`*.vcd` 在 `.gitignore` 裡，而 CI 會把每次執行的副本
留在 `chipforall-build-artifacts` 上傳中保存五天——所以只在 CI 上失敗的測試，
一樣可以回頭檢查。

### 用 Python 寫測試平台

`make cocotb` 執行 [cocotb](https://www.cocotb.org/) 測試：用 Python coroutine
驅動同一份 RTL，底層是同一個模擬器。它是 `test/tb_blinky.v` 的另一種選擇，不是
取代——哪種語言適合這個測試就用哪種。

```bash
make cocotb
```

`test/test_blinky_cocotb.py` 這個範例展示的是 Python 在這裡明顯佔優的一件事：
直接寫入設計**內部**的訊號。

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # 停在翻轉前一拍
await tick(dut)
assert dut.led.value == 1
```

用這個方式驗證「led 就是計數器最高位元」只需要四個 cycle。Verilog testbench 要
做到同一件事，只能覆寫 `WIDTH`（閘級 testbench 做不到），或是老實跑完 2^25 個
cycle——也就是下面 `make gatesim` 花四分鐘在做的事。

範例裡還記下一個容易踩的坑：`RisingEdge` 是在時脈邊緣**當下**恢復執行，此時
non-blocking assignment 還沒生效。所以檔案裡每次讀值前都再等一個 `Timer`，否則
讀到的是上一個 cycle 的值。

### 模擬閘級電路，而不只是 RTL

`make sim` 驗證的是你寫的 Verilog，它並不能證明工具從中產生的 netlist 也對。
latch 被誤推斷、reset 處理方式、合成器如何解讀有歧義的 `always` 區塊——這些都
夾在兩者之間，而且從 RTL 看不出來。`make gatesim` 補上這一段：它拿 `make gds`
留下的閘級 netlist（`runs/<tag>/final/nl/`），對著 Sky130 元件自己的
Verilog model 跑模擬。

```bash
make gds       # 產生 netlist
make gatesim   # 模擬它
```

它需要自己的 testbench，放在 `test/gate/`，因為合成會把參數固定下來：
`test/tb_blinky.v` 靠把 `WIDTH` 設成 4 來縮小設計，而 netlist 裡已經沒有
`WIDTH` 可以設。因此 `test/gate/tb_blinky_gl.v` 只驅動真正的接腳，並觀察 `led`
走完一個完整的除頻週期——整整 2^26 個 cycle，大約需要四分鐘（CI runner 上實測 3 分 36 秒）。

這個代價就是為什麼 CI 只在推送到 `main` 與 `v*` tag 時跑 `make gatesim`，而不
是每個 pull request 都跑。

### 在容器內開發

本專案附有 [Dev Container](https://containers.dev/)。用 GitHub Codespaces 開啟，或在 VS Code 選擇「在容器中重新開啟」，即可取得與 CI 相同的映像檔，Verilog 相關擴充套件也已裝好——不必手動輸入任何 Docker 指令。`Makefile` 會偵測到自己已在容器內，直接呼叫工具，而不會再疊一層容器。

容器內以 `root` 執行。在 Linux 主機上，這代表它寫進 `build/` 的檔案擁有者會是 `root`，從主機執行 `make clean` 可能需要 `sudo`。改用一般使用者會讓 Codespaces 無法連線，所以我們選擇承受這個代價。

`make gds` 在這裡面也能跑。它以 sidecar 的方式啟動 LibreLane 容器，因此 Dev Container 內建了一個自己的 Docker daemon 供它使用——不必再退回主機終端機，而在 Codespaces 上，那原本代表你根本無法執行這個招牌指令。

這裡用的是 docker-**in**-docker 而不是 docker-outside-of-docker，兩者的差別不是偏好問題。`make gds` 會把工作目錄 bind-mount 進去，而在容器內那是 `/workspace`。外部 daemon 會把這個路徑解析到你的主機上，那裡並沒有 `/workspace`，於是 Docker 會建立一個空目錄，LibreLane 就對著空氣跑——不會報錯，只會在流程深處出現一個令人困惑的失敗。內部 daemon 則解析到這個容器的檔案系統，那裡就是你的專案。

代價是第一次執行要在容器內拉一次 LibreLane 映像檔，而且 Dev Container 需要重建一次才會裝上這個 feature。如果 `make gds` 說它找不到 Docker daemon，它要的就是一次重建。

**在 Codespace 裡要注意磁碟。** 那個內部 daemon 有自己的映像檔儲存區，所以 LibreLane
映像檔是重拉一份而不是跟主機共用，再加上 Sky130 PDK 的 3GB。在最小規格的 Codespace
上那已經吃掉大半個磁碟。選大一點的規格，或者 Codespace 空間不夠時改從自己的主機跑
`make gds`。

習慣用自己的編輯器？`make shell` 可以從任何終端機進入同一個映像檔。

## 📂 專案架構

```text
.
├── .devcontainer/     # 🐳 VS Code Dev Container 定義
├── config.yaml        # ⚙️ 專案配置 (設計名稱、時序、面積)
├── Makefile           # 🎮 指令控制中心
├── src/               # ✍️ 您的 Verilog
│   └── blinky.v
├── test/              # 🧪 您的測試平台 (Testbenches)
│   ├── tb_blinky.v              # RTL 模擬 (make sim)
│   ├── test_blinky_cocotb.py    # Python 測試平台 (make cocotb)
│   └── gate/                    # 閘級模擬 (make gatesim)
│       └── tb_blinky_gl.v
└── build/             # 📦 所有產出的檔案 (GDS, Logs, Netlists)
```

## 📝 配置設定

修改根目錄下的 `config.yaml` 來變更您的設計設定。它是一份 [LibreLane](https://github.com/librelane/librelane) 配置檔——同一個檔案同時驅動模擬與實體設計流程，檔案內的註解標示了哪些設定是您通常會改的：

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

檔案中其餘的 key（`PDK`、`DIE_AREA`、`FP_SIZING`…）用於設定實體設計流程。在需要之前請保持原樣——若缺少任何一項，`make gds` 會告訴您。

---

由 **[c4o-core](https://github.com/anlit75/c4o-core)** 引擎驅動。
