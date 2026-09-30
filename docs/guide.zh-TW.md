# 使用指南

[README](../README.zh-TW.md) 沒寫的都在這裡：這個專案是什麼、不是什麼，完整的前置條件，換成你自己的設計，看懂數字，以及第一次執行之後的所有事。

*[English](guide.md)*

## 這個專案是什麼、不是什麼

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

## 開始之前

**在 Apple Silicon 上，有一部分會走模擬。** c4o-core 的映像檔只建 `amd64`——一台
runner、沒有 `platforms:`——所以在 `arm64` 機器上，`lint`、`sim`、`cocotb`、`synth`
和 `gatesim` 是透過模擬跑的。`make gds` 不是：最重的那一步跑的是 LibreLane 自己的映像
檔，而它有出 `arm64`，所以那一步是原生的。被模擬的那幾個會慢多少，這裡沒有量過。
Codespace 全程都是 `amd64`。

**有一個前置條件不是下載就有的：一點 Verilog。** 不用多——看得懂一個 `always @(posedge clk)` 區塊、一個 `<=` 指定、一個 `$fatal` 就夠。在 [HDLBits](https://hdlbits.01xz.net/) 上大約是 *Verilog Language* 那一段，不是整個網站。

**SystemVerilog 也讀得進來。** `logic`、`always_ff` 和可合成的那個子集在每個指令下都
能用，從 c4o-core 2.8.3 開始——這個 repo 之後釘過的每一版都包含它。在那之前，同一個檔案會
過 `make cocotb` 和 `make gds`，卻掛在 `make sim` 和 `make synth`。仍然不行的是把
`interface` 當成模組邊界——yosys 讀得懂宣告，然後在 `hierarchy` 階段失敗——所以 interface
留在測試平台裡，不要放在可合成模組之間。

**你不需要先會它才能開始。** `make gds` 直接就能把範例跑完，印出真實的面積、時序和功耗；`make all` 會讓你看到測試通過。先做這件事是值得的，因為它告訴你整套工具在你的機器上是通的。真正需要 Verilog 的是下一步：改 `src/blinky.v`、判斷一個「通過」的測試到底證明了什麼、或者自己寫一個。先跑再學，然後回來做那一步。

## 換成你自己的設計

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

## 指令

| 指令 | 說明 | 輸出 |
|---|---|---|
| `make all` | `lint`、`sim`、`cocotb`、`synth`——幾秒內跑完的全部。 | `終端機` |
| `make lint` | 用 Verilator 檢查 Verilog。 | `終端機` |
| `make sim` | 用 Icarus Verilog 跑 Verilog 測試平台。 | `build/wave.vcd` |
| `make cocotb` | 執行 Python (cocotb) 測試平台。 | `build/cocotb-results.xml` |
| `make synth` | 用 Yosys 把 RTL 合成成通用邏輯閘——沒有面積、沒有時序，見[看看電路長什麼樣](#看看電路長什麼樣)。腳本是固定的一份；想自己操作 Yosys 就用 `make shell`。 | `build/synthesis.json` |
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

## 看懂執行結果

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

**`signoff`** 是那一列沒人會說的話：你的版圖通過了可製造性檢查。`Makefile` 釘的 LibreLane 版本（`LIBRELANE_IMAGE`）預設讓每一項都直接中止流程（`ERROR_ON_MAGIC_DRC` 那一族預設都是 `True`），而 `config.yaml` 沒有覆寫任何一個，所以能跑到這一行就代表都過了。這是那一版的預設行為，不是這個 repo 掛保證的事——升版之後要自己確認一次。`clean` 只是把它講出來，並列出它實際看到哪幾項。有問題的時候它會改成指名道姓：`2 Magic DRC, 1 LVS`。

**`layout`** 是流程幫你的晶片畫的 PNG。打開來看看。

其中 `XOR` 不是製程規則檢查，是兩套工具把同一份 layout 各自寫成 GDS 之後互相比對——一致才算過。它抓的是其中任一個寫出器的 stream-out bug。它不是兩家原廠工具對一份設計各自下判斷——兩邊讀的是同一個資料庫——所以不要把 XOR 乾淨當成對版圖本身的第二意見。

**slack 為正值**代表設計滿足 `config.yaml` 裡設定的時脈；負值代表沒滿足，而流程不會因此停下來——所以一次成功結束的執行，仍然可能正在告訴你它沒達標。[該怎麼辦](#slack-為負值的時候)寫在下面。

**這九行是摘要，不是簽核報告。** 它從 300 個 key 的 `metrics.json` 裡挑出來，所以它沒
告訴你的比告訴你的多：clock uncertainty 和 derate 設多少、clock tree 的 skew 是多少、九
個 corner（`ss`/`tt`/`ff` 各配 `min`/`nom`/`max` 連線）裡是哪一個給出這個 slack。這些全是 LibreLane 的預設值——`config.yaml` 一個都沒設——而且全都
在 `runs/` 底下，一個 step 一個目錄。差別是實務上的：一個 `+0.11 ns` 的 hold slack，在
自己填 OCV derate 的簽核流程裡不會被當成「過了」。要對這些數字有商用流程等級的信心，
就去讀那些 per-corner 報告，別只讀這九行。

單獨執行 `make report` 可以再看一次，不必重跑流程。

## 發佈結果網頁

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

## slack 為負值的時候

負 slack 代表設計沒有滿足 `config.yaml` 裡的時脈。**從這裡你自己伸手拿得到的答案有兩種**：給設計更多時間——把 `CLOCK_PERIOD` 調大，重跑 `make gds`——或者把慢的那條路徑縮短，插 pipeline 或把邏輯搬出去。哪一種才對，取決於那個時脈速度是需求還是隨手填的；第一個設計通常是隨手填的。

這兩種動的都是設計或它的約束。**實體層面的答案——placement density、clock tree 的目標、resizer margin、繞線努力度——是 LibreLane 的，它們真的存在，而這份指南不涵蓋**：`config.yaml` 一個都沒設，[設定參考](#設定參考)也停在 LibreLane 自己的變數開始的地方。如果你是為了練手動收時序而來，那一塊你會是在讀 LibreLane 的文件。

還有第三種答案，是約束本身。如果失敗的那條路徑根本不該被算時序，或者流程假設的input delay 不是你板子上的那一個，那再怎麼改設計都不對——這是 SDC 檔的事，[設定參考](#設定參考)裡寫了怎麼給一份。

想知道*哪裡*慢，讀流程已經寫好的時序報告：

```bash
cat runs/*/*-openroad-stapostpnr/*ss_*/checks.rpt
```

每個時序 corner 一個檔，而 hold 是相反的問題：setup 掛在慢的 corner，hold 掛在快的。

```bash
cat runs/*/*-openroad-stapostpnr/*ff_*/checks.rpt    # hold
ls -d runs/*/*-openroad-stapostpnr/*/                # 這次到底跑了哪些
```

注意上面每個 glob 都會命中不只一個檔。這個設計跑一次會產生九個 corner 目錄——三個 PVT
點（`ss`、`tt`、`ff`）對三個連線 corner（`min`、`nom`、`max`）——所以 `cat` 是把三份報告
接在一起印出來，不會告訴你哪一份最差。最差的要自己挑，跟你平常從 summary 挑一樣。

兩種情況下，最差路徑都會連同上面經過的每一個閘、以及每一個閘花了多久一起列出來，時間
就花在那裡。

## 幫你自己的設計寫測試平台

`test/tb_blinky.v` 是一份完整的範例，讀起來也像範例。下面是它底下的骨架——能夠真的失敗的最小測試平台：

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

* **`$fatal` 才是讓壞掉的設計變成紅色 CI 的東西。** `$display` 印完就繼續跑，而模擬器兩種情況都回傳 0——一個回報了失敗卻沒有失敗的測試只是裝飾。`$fatal` 會回傳非零，那才是 `make sim` 和工作流在讀的東西。
* **邊緣之後的 `#1`。** `@(posedge clk)` 是*在*邊緣當下恢復，此時 non-blocking assignment 還沒生效，所以在那裡讀到的是上一拍的值。相對檢查照樣會過，這正是它難以察覺的原因。
* **`$dumpfile`/`$dumpvars` 來自你**，不是來自工具。沒有它們，上面那個斷言炸掉的時候你沒有波形可以看。

試試看：把 `src/blinky.v` 改壞，執行 `make sim`，看著它變紅。一個你從沒看它失敗過的測試平台，是一個你不知道它有沒有用的測試平台。

**這就是整套方法，而且對任何設計都成立，不只是這一個。** 一次改壞一個地方、跑測試、確認你瞄準的那個測試會失敗而且訊息你看得懂，然後 `git checkout -- src/blinky.v` 再改壞下一個。你得到的不是「測試都過了」，而是哪個測試抓得到哪種錯——以及哪裡什麼都抓不到，那就是你還沒寫的那個測試。這也是「我的測試到底有沒有在檢查設計」唯一的答案，因為一個不會失敗的測試什麼都告訴不了你。

## 測試失敗的時候：去看波形

`make sim` 會寫出 `build/wave.vcd`——每一條訊號、每一個週期，前提是你的測試平台有上面骨架裡那兩行 `$dumpfile`/`$dumpvars`。用 GTKWave 打開，或用 Dev Container 已經裝好的 **WaveTrace** 擴充套件（直接點那個 `.vcd` 檔）。失敗的斷言告訴你設計*錯了*，波形才告訴你*為什麼*。

`*.vcd` 在 `.gitignore` 裡，而 CI 會把每次執行的副本留在 `chipforall-build-artifacts` 上傳中保存五天——所以只在 CI 上失敗的測試，一樣可以回頭檢查。

## 用 Python 寫測試平台

`make cocotb` 執行 [cocotb](https://www.cocotb.org/) 測試：用 Python coroutine 驅動同一份 RTL，底層是同一個模擬器。它是 `test/tb_blinky.v` 的另一種選擇，不是取代——哪種語言適合這個測試就用哪種。

```bash
make cocotb
```

`test/test_blinky_cocotb.py` 這個範例展示的是 Python 在這裡明顯佔優的一件事：直接寫入設計**內部**的訊號。

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # 停在翻轉前一拍
await tick(dut)
assert dut.led.value == 1
```

用這個方式驗證「led 就是計數器最高位元」只需要四個 cycle。Verilog testbench 要做到同一件事，只能覆寫 `WIDTH`（閘級 testbench 做不到），或是老實跑完 2^25 個 cycle。

Verilog 那個邊緣的坑在這裡一樣成立：`RisingEdge` 是在時脈邊緣**當下**恢復執行，此時 non-blocking assignment 還沒生效，所以檔案裡每次讀值前都再等一個 `Timer`。

## 隨機刺激與參考模型

`test/test_blinky_random.py` 是驗證的另一半。directed test 針對某人挑的幾個時刻做斷言；這一支則建立一個「設計應該怎麼動」的模型，在沒有人手寫的刺激下，每個 cycle 都拿來對一次。

三個部分，每個大約十行：

* **模型**——`BlinkyModel`，用 Python 把 blinky 的行為再寫一次。刻意不是 RTL 的逐行翻譯：如果模型把設計的錯誤照抄一遍，那它在每一點上都會同意設計，也就永遠抓不到任何錯。
* **刺激**——隨機的起始計數與隨機的 reset 脈衝，五個視窗裡有兩個固定放在 `led` 會變的位置，這樣一次執行不會整場盯著一條不動的訊號。
* **scoreboard**——每個時脈之後把 `led` 和模型比對，失敗時印出第幾個 cycle、兩邊的值，以及那個視窗的起始計數。

```bash
make cocotb                   # 每次換一個 seed
make cocotb SEED=1789965785   # 完全重現某一次
```

cocotb 自己會 seed Python 的 `random` 並把用的 seed 印出來，所以 CI 上的失敗可以照著那一行在你機器上重現。

`led` 從頭到尾沒動過的話，這個測試也會失敗——200 個綠色 cycle 盯著一條常數訊號，什麼都沒證明，而一個會為此回報 PASS 的測試套件，正是這個專案花最多力氣在避免的東西。

它不檢查 reset 的*時序*：刺激只在時脈邊緣之後才動 `rst`，所以非同步 reset 和同步 reset 在這裡看起來一樣。那是靜態時序的問題——recovery 和 removal——而那九行摘要沒有帶它：摘要裡那兩列 slack 是 setup 和 hold，是不同的檢查。但 per-corner 報告有帶，而且自己一個 path group：

```bash
grep -A12 'Path Group: asynchronous' runs/*/*-openroad-stapostpnr/*/checks.rpt
```

量過的，不是猜的：這個設計的一次 CI 執行在九份 corner 報告裡都產出了 `recovery check against rising-edge clock clk`，而 CI 每次都會把它在那裡找到什麼印出來。同步 reset 的設計在那個 path group 裡什麼都沒有，那對它來說是正確的答案，不是缺漏。

## 模擬閘級電路，而不只是 RTL

`make sim` 驗證的是你寫的 Verilog，它並不能證明工具從中產生的 netlist 也對。latch 被誤推斷、reset 處理方式、合成器如何解讀有歧義的 `always` 區塊——這些都夾在兩者之間，而且從 RTL 看不出來。`make gatesim` 補上這一段：它拿 `make gds` 留下的閘級 netlist（`runs/<tag>/final/nl/`，`<tag>` 是這次執行的目錄，沒有自己命名的話就是 `<DESIGN_NAME>_run`），對著 Sky130 元件自己的 Verilog model 跑模擬。

```bash
make gds       # 產生 netlist
make gatesim   # 模擬它
```

它需要自己的 testbench，放在 `test/gate/`，因為合成會把參數固定下來：`test/tb_blinky.v` 靠把 `WIDTH` 設成 4 來縮小設計，而 netlist 裡已經沒有 `WIDTH` 可以設——它被固定成 `src/blinky.v` 宣告的 26，這也是下面那個 2^26 的由來。因此 `test/gate/tb_blinky_gl.v` 只驅動真正的接腳，並觀察 `led` 走完一個完整的除頻週期——整整 2^26 個 cycle，需要幾分鐘。

合成拿掉的不只是參數。內部訊號的名字也會消失，所以上面 cocotb 測試用的那一招——直接寫 `dut.count` 來跳過 2^25 個 cycle——在這裡沒有東西可以寫：netlist 裡沒有 `count` 這個名字。任何伸手進設計內部的東西在 RTL 上會過、到這一步就停止運作，而這正是這一步存在的理由之一。

**這是功能驗證，不是時序驗證。** 這裡沒有任何地方做 SDF back-annotation，所以元件是
零延遲切換的，這次模擬看不到只在真實延遲下才出現的競態。它看得到的是合成做的每一個
決定：被推論出來的 latch、reset 被實作成什麼樣、有歧義的 `always` 區塊被怎麼解讀。時
序是 STA 的工作，在 `make gds` 裡，負責回答它的是上面那些 per-corner 報告——如果你習
慣的流程是把 SDF-annotated 閘級模擬當成時序的最後一道關卡，那道關卡不是這一步。

這個代價就是為什麼 CI 只在推送和 `v*` tag 時跑 `make gatesim`，而不是每個 pull request 都跑。

## 不重跑整條流程的迭代方式

floorplan 相關的參數——`FP_CORE_UTIL`、die 的大小、擺放——不需要重做合成，所以把恢復上次執行的旗標傳給 LibreLane：

```bash
make gds LIBRELANE_ARGS="--last-run --from floorplan"
```

它讀的是 `runs/` 裡上一次的執行結果，這也是為什麼 `make clean` 不會動那個目錄，要清掉它得用 `make distclean`。

**`CLOCK_PERIOD` 不在裡面。** 時脈是合成的輸入，合成會依它挑元件尺寸、插 buffer，所以
從 floorplan 恢復的話，你量到的是「**舊**週期合成出來的閘，在新週期下的 timing」。這樣
很可能真的收了，但它對「你實際會拿到的那個設計」什麼都沒說。改時脈就要乾淨重跑
`make gds`——這也正是[slack 為負值的時候](#slack-為負值的時候)那節叫你做的事，以及它為什
麼那樣講。

## 看看電路長什麼樣

```bash
make schematic
```

畫出 `build/schematic.svg`——你的設計以 flop、加法器、多工器呈現，帶著你取的名字。用瀏覽器開，或在 VS Code 裡點一下都行；它是 SVG，不需要任何特別的東西才能看。

這不是 netlist 的圖。`make synth` 會跑完整合成，留下上百個通用邏輯閘，沒有人能從那張圖看懂自己的設計。`make schematic` 停得更早，停在電路還看得出原始碼樣子的地方。

**是通用閘，不是 Sky130 的元件。** `make synth` 只映射到 Yosys 自己的 cell 就停了：範例
的 `build/synthesis.json` 裡是 94 顆這種 cell——`$_DFF_PP0_`、`$_OR_`、`$_XOR_` 之
類——一顆 `sky130_` 都沒有，因為這裡沒有人餵 liberty 檔給 Yosys。所以這個指令回答的是
「它合得起來嗎、大概多少邏輯」，它回答不了面積和時序。`make report` 裡那 `198 standard
cells` 是 `make gds` 裡 LibreLane 自己對著真實元件庫合成的結果，不是這個數字，兩者也不能
互相比較。

不到一秒，所以每改一次都可以跑——和 `make gds` 不一樣。

## 在容器內開發

本專案附有 [Dev Container](https://containers.dev/)。用 GitHub Codespaces 開啟，或在 VS Code 選擇「在容器中重新開啟」，即可取得與 CI 相同的映像檔，Verilog 相關擴充套件也已裝好。`Makefile` 會偵測到自己已在容器內，直接呼叫工具，而不會再疊一層容器。

`make gds` 在這裡面也能跑：容器內建了一個自己的 Docker daemon 給 LibreLane sidecar 用。如果 `make gds` 說它找不到 Docker daemon，重建一次 Dev Container 就是它要的。

兩件要知道的事：

* **容器內以 `root` 執行。** 在 Linux 主機上，這代表它寫進 `build/` 的檔案擁有者會是 `root`，從主機執行 `make clean` 可能需要 `sudo`。改用一般使用者會讓 Codespaces 無法連線。
* **在 Codespace 裡要注意磁碟。** 內部 daemon 有自己的映像檔儲存區，所以 LibreLane 映像檔是重拉一份而不是跟主機共用，再加上 Sky130 PDK 的 3GB。在最小規格的 Codespace 上那已經吃掉大半個磁碟——選大一點的規格，或者改從自己的主機跑 `make gds`。

**一份 PDK 可以給好幾個 checkout 用。** Sky130 裝起來是 3GB，而且每次都一模一樣，所以 `PDK_ROOT` 會把兩邊——安裝，以及讀它的 LibreLane sidecar——同時指到同一個目錄：

```bash
make gds PDK_ROOT=/opt/sky130
```

不設它的話，每個 clone 都會在自己的 `pdks/` 底下留一份。共用的機器，或是你手上不只一個設計的時候，那 3GB 就只付一次，而不是每個 checkout 各付一次。這需要 c4o-core 2.8.2 或更新的版本；`Makefile` 釘的版本已經符合。

習慣用自己的編輯器？`make shell` 可以從任何終端機進入同一個映像檔。

## 設定參考

`config.yaml` 是一份 [LibreLane](https://github.com/librelane/librelane) 配置檔。不屬於 LibreLane 的 key 前面加 `//`，它會直接忽略——這就是一份檔案能同時給兩個工具用的原因。

| Key | 作用 |
|---|---|
| `DESIGN_NAME` | 你的頂層模組名稱。其他地方都從這裡讀。 |
| `VERILOG_FILES` | 可合成的原始碼。一行一個檔案：LibreLane 會把每一項當成字面路徑驗證，不展開 `**`。 |
| `"//TEST_FILES"` | 給 `make sim` 的 Verilog 測試平台。可以用萬用字元。 |
| `"//SIM_TOP"` | 要 elaborate 的測試平台模組。`"//TEST_FILES"` 對到超過一個檔案時必填。 |
| `"//COCOTB_TESTS"` | 給 `make cocotb` 的 Python 測試平台。選用。 |
| `"//GATE_TESTS"` / `"//GATE_TOP"` | 給 `make gatesim` 的閘級測試平台。選用。 |
| `"//WAVE_SIGNALS"` | `make site` 從 `make sim` 的 VCD 畫的訊號，從測試平台頂層往下寫（`tb_blinky.uut.count`）。VCD 裡沒有的名字會讓 `make site` 失敗。選用。 |
| `CLOCK_PORT` / `CLOCK_PERIOD` | 要約束的時脈，以及它的週期（ns）。 |
| `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE` | 你自己的時序約束，當上面那兩個 key 不夠用的時候——見下。 |
| `FP_SIZING` / `FP_CORE_UTIL` | die 怎麼算出來的——見下。 |
| `PDK` / `STD_CELL_LIBRARY` | Sky130 與它的標準元件庫。保持原樣。 |

**晶片尺寸會自己長。** `FP_SIZING: relative` 依 `FP_CORE_UTIL`（core 要放多滿，單位是百分比，所以這裡的 40 就是 40%）算出 die，所以較大的設計會得到較大的 die，而不是「放不下」。繞線太擠就調低，想要更小的晶片就調高。

仍然可以固定尺寸：把 `FP_SIZING` 改成 `absolute`，並加上 `DIE_AREA: [0, 0, 寬, 高]`。但用 relative 的時候不要把 `DIE_AREA` 留在檔案裡——流程已經不讀它了，GDS stream-out 卻還是會照它畫晶片邊界，signoff 就會對著一個沒人用的邊界失敗。

檔案中其餘的 key 都屬於 LibreLane，完整清單見[它的文件](https://librelane.readthedocs.io/)；這個引擎讀哪些，見 [c4o-core README](https://github.com/anlit75/c4o-core)。

**這張表沒列的 key 一樣有效。** 沒有任何東西會過濾 `config.yaml`：c4o-core 只檢查它需
要的那幾個 key 在不在、值合不合理，而 `make gds` 是把整份檔案原封不動交給 LibreLane。
所以 `PL_TARGET_DENSITY`、`CTS_*`、`GRT_*` 以及 LibreLane 其餘的變數都可以直接加進去，
而且真的會生效。這張表列的是**這個 repo 有理由去設的** key，不是**你被允許設的**。

**時序約束就只有兩個 key，而 SDC 檔可以取代它們。** 這個 repo 約束的東西就是
`CLOCK_PORT` 和 `CLOCK_PERIOD`。一個靜態時序工具需要的其他東西——input/output
delay、transition 和 fanout 上限、clock uncertainty，以及所有的例外——都來自
LibreLane 的預設值：單一時脈、沒有 false path 的設計這樣就夠，其他任何東西都遠遠不夠。
要自己寫，就把檔案指出來：

```yaml
PNR_SDC_FILE: dir::constraints/pnr.sdc
SIGNOFF_SDC_FILE: dir::constraints/signoff.sdc
```

這兩個是 LibreLane 自己的路徑變數，所以它們是走上面那條直通進去的，不需要 c4o-core 做
任何事。分成兩個而不是一個正是重點：把 place and route 約束得更緊，再用設計真正必須滿足
的條件去簽核。CI 會斷言釘住的那版 LibreLane 仍然宣告這兩個 key，所以升版不會讓這段話
悄悄變成錯的。它不會檢查你的檔案有沒有真的被讀進去：那件事只有真的跑一次才知道。

**第二個時脈住在那個檔案裡，不在這一份。** `CLOCK_PORT` 和 `CLOCK_PERIOD` 都是單一值，
而 c4o-core 在開跑之前會要求這兩個都在，所以雙時脈的設計是在這裡指定其中一個、在自己的
SDC 裡把兩個都 create 出來——這份檔案裡那一對是那些便利 key 在約束的東西，SDC 才是設計
真正被簽核的依據。

**Macro 是 LibreLane 的事，這份指南不涵蓋。** 一顆硬 macro——SRAM、PLL、別人做的
block——是透過 LibreLane 的 `MACROS` 變數進來的，那是一個定義的字典，每一項帶自己的 GDS
和 LEF view，而且它會連帶把跨 macro 的電源繞線和 placement blockage 一起帶進來。因為
是直通的，你可以直接從 `config.yaml` 做這件事，這裡什麼都不用改。而這個 repo 能提供的，
是一個小到可以一次讀完的設計，那是另一個極端。
