<div align="center">

# ChipForAll

**一個讓晶片設計自己證明它是對的模板。用開源工具，一個指令就好。**

寫 Verilog。用真的會失敗的測試證明它是對的。每個 commit 都拿到一份真正的晶片版圖和一個結果網頁。所有 EDA 工具都包在一個 Docker 映像檔裡，一個都不用自己裝。

[![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml)
[![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)](https://github.com/anlit75/ChipForAll/releases)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

[**線上結果網頁**](https://anlit75.github.io/ChipForAll/) · [快速開始](#-快速開始) · [指南](docs/guide.zh-TW.md) · [English](README.md)

</div>

---

## 為什麼是 ChipForAll

用開源流程產出一份版圖，[LibreLane](https://github.com/librelane/librelane) 已經做得到。但它不會告訴你那份版圖**對不對**。ChipForAll 補上缺的那一塊：流程周圍的測試、檢查和 CI。

| | |
|---|---|
| 🧪 **真的會失敗的測試** | Verilog 與 Python（cocotb）測試平台，設計壞了就回傳非零。 |
| 🔬 **閘級模擬** | 在合成產出的 netlist 上重跑你的測試。latch 和 reset 的 bug 就藏在那裡。 |
| 📊 **看得懂的 signoff** | 九行就列出面積、時序、功耗和 DRC/LVS。不用去讀 300 個 key 的 JSON。 |
| 🌐 **每個 commit 一個結果網頁** | CI 把測試、signoff、版圖和波形發佈到 GitHub Pages。 |
| 🐳 **不用裝任何 EDA 工具** | 全部都在一個 Docker 映像檔裡。可以從 Docker、Dev Container 或 Codespace 執行。三種環境的指令都一樣。 |
| 🔓 **成果可以公開** | Sky130 是 Apache 2.0，沒有 NDA。GDS 可以直接放進作品集。 |

## 🚀 快速開始

你需要 Docker、Make 和 Git。Codespace 裡三樣都有：

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/anlit75/ChipForAll)

這個按鈕開的永遠是原始的 `anlit75/ChipForAll`，從你副本裡的這份 README 點也一樣。拿來試第 2、3 步就夠了。想保留成果、擁有自己的 CI 和結果網頁，就先做第 1 步。然後從你的副本開 Codespace（**Code → Codespaces**）。兩種情況都要選比最小規格大的機型，因為 `make gds` 需要磁碟空間。[原因 →](docs/guide.zh-TW.md#在容器內開發)

Apple Silicon 也能用，但有些指令會走模擬。[是哪些 →](docs/guide.zh-TW.md#開始之前)

**1. 做一份自己的副本。** 按 **Use this template → Create a new repository**。然後 clone 下來：

```bash
git clone https://github.com/<you>/<your-repo>.git && cd <your-repo>
```

在 Codespace 裡 repo 已經在了。不用 clone。

**2. 確認測試通過**（幾秒鐘）：

```bash
make all
```

**接著故意把它改壞。** 這一步是版圖工具做不到的。把 `src/blinky.v` 裡的 `count[WIDTH-1]` 改成 `count[WIDTH-2]`。LED 的閃爍會快一倍。再跑一次 `make all`：

```
[ERROR] cocotb tests failed: led_rises_half_a_period_after_reset, led_toggles_with_a_full_period, reset_in_the_middle_restarts_the_count, random_resets_match_the_model
```

最後一行指出哪些測試失敗。它上面，每個失敗的測試會印出自己的訊息。`make` 回傳非零，所以 CI 也會失敗。用 `git checkout -- src/blinky.v` 還原。[幫你的設計寫這種測試 →](docs/guide.zh-TW.md#幫你自己的設計寫測試平台)

**3. 做出版圖**（約 3 分鐘。第一次還要下載 3 GB 的 PDK，另外約 20 分鐘）：

```bash
make gds
```

最後它會告訴你做出了什麼：

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

`signoff clean` 加上正的 slack，代表版圖通過了製造檢查，也滿足時脈。流程到這個 GDS 檔為止：下線製造不在這個 repo 的範圍內。[每一行怎麼讀 →](docs/guide.zh-TW.md#看懂執行結果)

## 🌐 結果直接上線

`main` 上每次 CI 都會把結果網頁發佈到 `https://<you>.github.io/<your-repo>/`。頁面最前面是你的設計版圖，可以用 3D 開啟，也可以下載 GDS。接著是判定和測試，然後是 signoff、波形、時序、面積和功耗。頁面上會寫建置時間和對應的 commit。

只要開一次：**Settings → Pages → Source: GitHub Actions**。本機用 `make site` 產生這個網頁。[更多 →](docs/guide.zh-TW.md#發佈結果網頁)

## 🎮 指令

| 指令 | 做什麼 |
|---|---|
| `make all` | Lint、你的測試、合成：幾秒內跑完的所有步驟 |
| `make gds` | 完整 RTL 到 GDSII 流程，最後印出上面的摘要 |
| `make gatesim` | 在閘級電路上重跑你的測試（`make gds` 之後） |
| `make report` | 不重跑，再印一次摘要 |
| `make site` | 結果網頁，產在 `build/site/` |
| `make shell` | 進到工具鏈容器裡的 shell |

`make help` 列出全部指令。[完整表格](docs/guide.zh-TW.md#指令)列出每個指令的產出。

## ✍️ 換成你的設計

刪掉 blinky 的檔案。Verilog 放 `src/`，測試放 `test/`。在 `config.yaml` 列出它們，並把 `DESIGN_NAME` 設成你的頂層模組。其他資料 `Makefile` 和 CI 都從那個檔案讀。[必須一致的四件事 →](docs/guide.zh-TW.md#換成你自己的設計)

## 適合誰

- **學生與自學者**：想要第一顆拿得出手的晶片，而且有測試證明它是對的。要改設計需要[一點 Verilog](docs/guide.zh-TW.md#開始之前)。
- **簽了 foundry NDA 的工程師**：想要一份可以公開的第二份成果。
- **正在學驗證的人**：完整的 UVM 風格環境請看 [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm)，它就是從這個模板建出來的。

**先說清楚：** 這裡用的是商用工具的開源對應。Icarus 對 VCS，Yosys 對 Design Compiler，OpenSTA 對 PrimeTime。流程和詞彙轉得過去。工具名稱轉不過去。[完整對照 →](docs/guide.zh-TW.md#這個專案是什麼不是什麼)

## 📚 延伸閱讀

- [指南](docs/guide.zh-TW.md)：前置條件、寫測試平台、看波形、閘級模擬、slack 為負時、設定參考
- [c4o-core](https://github.com/anlit75/c4o-core)：每個指令背後的工具鏈引擎
- [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm)：跑在真實 UART 上的 pyuvm 驗證環境

---

<div align="center">

[MIT License](LICENSE) · Powered by [c4o-core](https://github.com/anlit75/c4o-core)

</div>
