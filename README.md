# 基于 PH1P35 FPGA 的智能循迹 / 交通标志识别小车 — 完整工程源码

> 参赛队伍 / 作者：__________（提交前填写）

本目录是作品提交用的**纯净源码包**：只保留顶层实际引用到的 RTL 源码、引脚约束、IP 配置、安路 TD 工程文件和对应测试平台。
所有中间产物（综合/布局布线 run 目录、位流、时序报告）、历史备份（`.bak-* / .golden-* / .archive-*`）、日志、
ModelSim 波形与 work 库，以及**未被例化的历史模块**均已删除（明细见第 10 节）。

---

## 1. 工程信息

| 项 | 值 |
|---|---|
| 器件 | 安路 PH1P35MDG324（40 DSP / 21,216 LUT6 / 42,432 FF / 108 ERAM） |
| 工具链 | 安路 Tang Dynasty（TD）6.2 |
| 工程文件 | `td_project/camera_to_dsi_display.al` |
| 顶层 | `design_top_wrapper.v` |
| 图像 | 1280×720 @ 60 fps |
| 摄像头 | CS500（MIPI 2-lane，I²C 配置，AE 自动曝光 + 按键手动档） |
| 显示 | HDMI 720p，画面叠加 OSD（模式名、延迟、颜色/标志调试信息） |
| 执行机构 | 4 路直流电机（AT8236 双 IN 驱动）+ 二轴云台 PWM |

### 时钟域

| 时钟 | 频率 | 主要负载 |
|---|---|---|
| `MIPI_RX_BYTE_CLK` | 60 MHz | ISP、检测算法、DDR 写侧 |
| DDR `usr_clk` | 66.667 MHz | 帧缓存读写 |
| `HDMI_PIXEL_CLK` | 75.002 MHz | `hdmi_mixer`、OSD、云台 |
| `sys_clk_50m` | 50 MHz | 按键、I²C、AE |

---

## 2. 目录结构

```
submit_20261104/
├── README.md                     ← 本文件
├── td_project/                   ← 安路 TD 工程
│   ├── camera_to_dsi_display.al  ← 工程（内含 51 个 HDL + 8 个 IP + 约束的清单）
│   └── camera_to_dsi_display.sdc ← 时序约束
├── user_source/
│   ├── constraints_source/
│   │   └── pin.adc               ← 引脚约束
│   ├── ip_source/                ← TD IP（PLL / w128、w155 异步 FIFO / 除法器 / AWB 延时 RAM）
│   └── hdl_source/               ← 全部 RTL 源码
│       ├── design_top_wrapper.v  ← 顶层（数据通路 + 模式机 + 自动行驶状态机 + 电机）
│       ├── isp/isp_top.v         ← ISP 主链 + 各检测器例化
│       ├── isp/                  ← 去马赛克、边沿、二值化、车道、运动等
│       ├── mipi_dphy_rx/         ← MIPI D-PHY 接收层（厂商加密源码）
│       ├── ph1p35_ddr/           ← DDR2 控制器与 PHY（厂商源码 + DDR IP）
│       ├── uics500_cfg/          ← 摄像头 I²C 寄存器表、AE
│       ├── vtc/                  ← 视频时序（uivtc）
│       └── …                     ← 其余模块（详见第 4 节）
└── sim/                          ← ModelSim 测试平台（tb_*.v）与标志识别模型校验脚本
```

> 相对布局与源码目录保持一致：`td_project` 里的 `.al` 用 `../user_source/…` 引用源文件，
> 因此 **`td_project/` 与 `user_source/` 必须保持同级**，整个目录可以任意移动或解压。

---

## 3. 系统数据流

```
            ┌─────────────── isp_top ───────────────────────────────┐
CS500 ─MIPI─► csi_unpacket → raw10_unpacket → uial2axis → raw_pre → demosaic
            │      → awb → ccm → gamma → 灰度/边缘 → 输出 128bit ──┐ │
            │                                                      │ │
            │  并行检测：color_detect / target_tracker              │ │
            │            edge_detect_96 → lane_detect               │ │
            │            sign_detect（蓝箭头/红圆/黄三角）           │ │
            │            binarize / motion_box                      │ │
            └──────────────────────────────────────────────────────┘ │
                                                                     ▼
                                                   DDR2 帧缓存（写→读，跨时钟域）
                                                                     │
                    ┌────────────────────────────────────────────────┘
                    ▼
              video_out → hdmi_mixer（OSD 叠加）→ HDMI TX ──► 显示器
                    │
                    ▼
        design_top_wrapper 决策（mode6 自动行驶状态机）
             ▲ 标志类型 / 车道偏移 / 车道有效 / 路口行号 / 运行开关
             ▼
        motor_ctrl（4 路 15 kHz PWM，AT8236 IN/IN 时序）──► 四轮
```

---

## 4. 主要模块

| 文件 | 作用 |
|---|---|
| `design_top_wrapper.v` | 顶层：时钟/复位、MIPI→ISP→DDR→HDMI 通路、mode0~8 模式机、自动行驶状态机（循迹保持、路口处理、标志响应、丢线搜索）、LED、电机与云台控制 |
| `isp/isp_top.v` | ISP 主链（黑电平、去马赛克、AWB、CCM、Gamma、灰度/边缘）与全部检测器例化；`I_mode` 选择 HDMI 显示哪一级画面 |
| `isp/sign_detect.v` | 交通标志识别：蓝色箭头（左/右转）、红色圆形（停车）、黄色三角（减速），输出 `O_sign_type` 与调试计数 |
| `color_detect.v` | 四色（红/黄/绿/蓝）包围盒、面积、质心（Ping-Pong 统计） |
| `target_tracker.v` | 目标跟踪（云台伺服用） |
| `gimbal_ctrl.v` | 二轴云台 PD 控制与 PWM 输出 |
| `isp/edge_detect_96.v` | Sobel 边缘检测（4 lane） |
| `lane_detect.v` | 三段扫描式黑线检测：中心、偏移、有效性、路口/边角行号 |
| `binarize.v` | 灰度固定阈值二值化（mode5 显示） |
| `isp_top` 内 `motion_box` | 帧差运动框（mode3/4 显示） |
| `motor_ctrl.v` | 4 路 PWM + AT8236 IN/IN 时序 + 差速运算 + 自检选轮（`I_test_sel`） |
| `hdmi_mixer.v` | HDMI 720p 时序、OSD 字符叠加（模式名、延迟面板、颜色/标志调试行、标志框与图标） |
| `osd_char_lib.v` / `anlogic_logo_rom.v` | 16×16 点阵字模（纯 case 描述）/ 开机 logo |
| `awb.v`、`isp/demosaic_4x_2_0/*` | 自动白平衡、双线性去马赛克 |
| `uics500_cfg/uicfgcs500_720p.v` | 摄像头上电寄存器序列、AE 档位与按键联动 |
| `key_remove_shakes.v` | 2 ms 按键消抖 |
| `ph1p35_ddr/`、`mipi_dphy_rx/` | 安路官方 DDR2 与 MIPI D-PHY 接收参考设计（加密源码，请勿修改） |

> 说明：包内 `.al` 清单与 `hdl_source/` 一一对应，**只有顶层实际引用到的模块**；
> 未被例化的历史模块（`decision_arbiter`、`safety_fsm`、`median_filter`、`histogram_eq`、
> `cartoonize`、`edge_dilate`、`temporal_blk_med3`、`param_ctrl`、`motion_detect` 等）已全部删除。

---

## 5. 编译与烧录

1. 用安路 **TD 6.2** 打开 `td_project/camera_to_dsi_display.al`
   （请直接双击/“打开工程”选择该文件；工程内记录的历史路径不影响相对路径解析）。
2. 左侧 Process 栏：**Reset Runs** → **Launch Runs**（综合 syn_1 + 布局布线 phy_1，约 5 + 15 分钟）。
3. 检查 `Report → Timing`：DDR 域 / 50 MHz 域应满足；HDMI 与 MIPI 域为本设计的关键路径。
4. 打开 `Programmer`，将生成的位流下载到板卡（或固化到板载 SPI Flash）。

**命令行方式**（TD 安装目录下）：

```tcl
open_project {<本目录>/td_project/camera_to_dsi_display.al}
reset_run syn_1
reset_run phy_1
launch_runs -jobs 6
```

### 常见坑

- `pin.adc` 的注释只能用 `#`，写 `//` 会报 “is not a valid ADC command”。
- 不要在 TD 之外用脚本改 `.al` 的文件清单（TD 会周期性回写覆盖）；新增模块请内联进已有文件。
- 中文注释的 `.v` 请用 UTF-8（无 BOM）保存，不要用 `>` 重定向写入。
- ModelSim 单独编译需先 `vlib work`。

---

## 6. 引脚（`user_source/constraints_source/pin.adc`）

| 功能 | 引脚 | 备注 |
|---|---|---|
| 系统时钟 / 复位 | C4 / R10 | 50 MHz 晶振，低有效复位 |
| 按键 key0~key3 | D5 / A9 / B9 / C7 | key0 切显示模式，key1 调亮 / key2 调暗 / key3 锁定 AE |
| 运行开关 SW4 | D11 | 拨上＝运行，拨下＝停车 |
| 摄像头 SCL/SDA/24M/RST | K3 / J3 / L3 / L2 | I²C |
| 左前 电机 PWM/DIR | E12 / E16 | INVERT=1（IN1 恒 0，IN2 出 PWM） |
| 右前 电机 PWM/DIR | E17 / F13 | INVERT=0 |
| 左后 电机 PWM/DIR | J14 / J15 | INVERT=1 |
| 右后 电机 PWM/DIR | J16 / J18 | INVERT=0 |
| LED1~LED4 | D10 / E10 / C6 / D6 | 状态指示 |
| 背光 / 云台 pan/tilt | R11 / C18 / D15 | PWM |
| HDMI TMDS ch0/1/2/clk | G16 / F17 / H14 / C17 | TMDS33 |
| DDR2 / MIPI 差分 | 由 IP 自带约束 | `ph1p35_ddr/ddr2/src/sdc`、`ddr2.adc` |

> `I_sw1~I_sw3` 端口在本版本保留但未使用，因此未分配引脚。

### 电机驱动要点（AT8236，IN/IN 双输入）

| IN1(PWM) | IN2(DIR) | 效果 |
|---|---|---|
| 0 | 0 | 滑行（停） |
| 1 | 0 | 正转 |
| 0 | 1 | 反转 |
| 1 | 1 | 刹车 |

两侧电机镜像安装，因此左侧两轮采用 `INVERT_PWM=1`（IN1 恒 0、IN2 出 PWM：脉冲期=反转=物理前进，间隙=滑行）。
**DIR 不能当“方向位”用**：DIR=1 + 占空比是“反相驱动”，转速会异常放大。

---

## 7. 关键参数（均在源码里可改）

| 参数 | 值 | 位置 |
|---|---|---|
| PWM 频率 / 周期 | 15 kHz / 4000 @60 MHz | `design_top_wrapper.v`（`motor_ctrl` 例化） |
| 电机最低占空比 | 12 % | 同上 `MIN_PCT` |
| 循迹基准速度 | 40 % | `SPD_LANE` |
| 单轮最低速度 | 14 % | `WHEEL_MIN` |
| 转向限幅 | ±52 | `LANE_ST_MAX` |
| 路口检测行 | y = 660 | `CORNER_TRIG_ROW` |
| 路口时序 | 提前 60 ms / 停车 200 ms / 转向 400 ms（最短 150 ms）/ 冷却 1500 ms | `CORNER_*_MS` |
| 丢线搜索 | 速度 8 %、转向 50、最长 8 s | `SEEK_*` |
| 转弯加速窗口 | 600 ms | `TURN_FAST_MS` |

实测转速模型（40 % ≈ 1.5 圈/秒，轮径 8 cm）：`圈/秒 ≈ 0.0535 × (占空比% − 11.3)`，死区约 11 %。

---

## 8. 仿真

`sim/` 下是针对各模块的 ModelSim 测试平台，均为自检测（打印 PASS/FAIL 或统计计数）：

```powershell
$env:PATH = "<ModelSim>/win32aloem;" + $env:PATH
vlib work
vlog -work work ../user_source/hdl_source/sign_detect.v tb_sign_detect.v
vsim -c -do "run -all; quit" work.tb_sign_detect
```

| 测试平台 | 覆盖对象 |
|---|---|
| `tb_sign_detect.v` | 标志分类（蓝箭头 / 红圆 / 黄三角，含斜视与偏色模型） |
| `tb_color_detect.v` | 四色包围盒与质心 |
| `tb_lane_detect.v`、`tb_lane_track.v` | 车道线中心/偏移/路口 |
| `tb_motor_ctrl.v` | 四路 PWM 与 IN/IN 时序 |
| `tb_gimbal_ctrl.v`、`tb_gimbal_pd.v` | 云台 PD 与限位 |
| `tb_binarize.v`、`tb_edge_detect.v` | 二值化与 Sobel 边缘 |
| `tb_mode_fsm.v`、`tb_target_tracker.v` | 模式机与目标跟踪 |
| `tb_font_golden.v`、`tb_hdmi_mixer_frame.v`、`tb_rom_check.v` | 字模 / HDMI 帧 / ROM 内容校验 |
| `tb_loop_big.v`、`tb_loop_probe.v` | 闭环联调探针 |
| `sign_model_check.py` | 用 Python 复算标志判据，与 RTL 逐像素比对 |

---

## 9. 备注

- 本包只含源码，不含位流、不含综合/布线结果；复现请按第 5 节重新综合。
- 若打开工程后文件列表显示为未找到：说明 TD 用旧绝对路径缓存了列表，关闭工程后重新双击
  `td_project/camera_to_dsi_display.al` 即可（源文件全部是相对路径引用）。
- 作品演示视频、说明文档、标志样张等材料不在此包内。

---

## 10. 整理说明（相对原始工作目录）

**原则：只删没被例化的，在用的模块一行不改。**

| 动作 | 内容 |
|---|---|
| 保留 | 顶层实际引用的 **51 个 HDL** + `pin.adc` + 8 个 TD IP + `.al` / `.sdc` + 17 个测试平台；在用模块的逻辑、参数、阈值均未改动 |
| 剔除 | `.bak-* / .golden-* / .archive-* / *.corrupt-*` 备份，run 目录、位流、时序报告、各类 `.log`，ModelSim `work` 库与波形，`__pycache__` |
| 删除模块文件（33 个） | 从未被例化的：`decision_arbiter.v`、`safety_fsm.v`、`median_filter.v`、`histogram_eq.v`、`cartoonize.v`、`edge_dilate.v`、`temporal_blk_med3.v`、`param_ctrl.v`、`motion_detect.v`、`auto_white_balance.v`、`csi_unpacket.v`、`raw10_unpacket.v`、`raw8_to_rgb888.v`、`pll_hdmi.v`、`ps_wrapper.v`、`mipi_rx_error_detect.v`、`sort_stat_filter.v`、`video_cuttting.v`、`isp/BLC/BLC.v`、`uics500_cfg/uicfgcs500.v`、`uiisp_beta/ae_set.v`；与在用模块同名重复、且不在工程清单里的副本：`isp/awb/*`、`uiisp_beta/csi_unpacket_2lane.v`、`uiisp_beta/raw10_unpacket_2lane.v`、`uial2axis/uial2axis.v`、`osd_font_rom.v`、`data_96bit_to_128bit.v` |
| 删除模块定义（文件内） | `isp/isp_top.v` 的 `bin_dark`；`isp/edge_detect_96.v` 的 `fill_ccl`、`sign_fill`、`cartoon_96`、`gamma_luma_96`；`isp/data96_128/data96_128.v` 中已被注释掉的 `data96_128`（该文件 102 → 79 行，在用模块 `data_96bit_to_128bit` 保留） |
| 删除孤立 testbench（7 个） | `tb_decision_arbiter*.v`、`tb_safety_fsm.v`、`tb_median_filter.v`、`tb_histogram_eq.v`、`tb_cartoonize.v`、`tb_motion_detect.v`（其 DUT 已删除） |
| 删除未引用目录 | `ip_source/MCU`、`ip_source/w40_d512_fifo`（工程未引用）、`hdl_source/dsi_tx_packet`（本设计不出 DSI） |
| 同步工程清单 | `.al` 由 71 项减为 **61 项**（去掉上述 10 个被删文件的记录）；顶层、编译顺序、约束集、Run 设置均未动 |

