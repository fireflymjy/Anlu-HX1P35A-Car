# -*- coding: utf-8 -*-
r"""
标志图离线校验工具 —— 与 FPGA 里 sign_detect.v 的判决逻辑一一对应

用法：
    python user_source\sim\sign_model_check.py                # 默认读 项目根目录\图标\
    python user_source\sim\sign_model_check.py D:\my_pics     # 指定目录

输出每张图：
    · 旧判据(B>=60 且 B>=max+15) 和 新判据(比值) 下的蓝像素数
    · 标志几何（直径/中心/纵向范围）、填充率、框内白像素、OSD 上的 L/R 票数、判决结果
    · 抗干扰能力：画面里另加一小块蓝（把整幅蓝框撑大）、整幅压暗、两者叠加

真值表 TRUTH 里可以填自己图片的期望结果，就会打印 OK/错。
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

NAME = {0: '无  ', 1: '左转', 2: '右转', 3: '红牌', 4: '直行'}

# ---- 判据门限：改这里等于改 isp_top.v 里 sign_detect 的例化参数 ----
MIN_BLUE, MIN_RED, MIN_WHITE = 300, 500, 40
WHITE_MIN, WHITE_SPREAD = 70, 60
COLOR_DIFF = 50                 # B >= (1+COLOR_DIFF/100)*max(R,G)
BOX_MIN, BOX_MAX = 8, 1280
FILL_MIN = 15                   # 蓝像素 / 直径² 下限(%)
RED_FILL_MIN = 40
MASK_FRAC = 35                  # 窗口半边长 = 35% 直径

TRUTH = {
    '057ae8819d15e0730d6ec81f5b4360c6.jpg': 2,   # 向右转弯
    '4ffa0467037afdbdce322a26c1785397.jpg': 4,   # 只准直行
    'b1d7f78fd611394dae5e075636b129c0.jpg': 1,   # 向左转弯
}


def detect(a, pool=0, wash=0.0, blue_rule='new', verbose=True):
    af = a.astype(np.float32)
    if wash > 0:                                   # 模拟白平衡把颜色晒淡
        af = af * (1 - wash) + 128.0 * wash
    R, G, B = af[..., 0].astype(np.int32), af[..., 1].astype(np.int32), af[..., 2].astype(np.int32)
    mx = np.maximum(R, G)
    mn = np.minimum(np.minimum(R, G), B)
    spread = np.maximum(mx, B) - mn

    if blue_rule == 'old':                         # 旧：带绝对亮度门限
        blue = (B >= 60) & (B >= mx + 15)
    else:                                          # 新：纯比值
        blue = (B >= 20) & (B * 100 >= mx * (100 + COLOR_DIFF))
    white = (mn >= WHITE_MIN) & (spread <= WHITE_SPREAD) & (B * 100 <= mx * 110)
    if pool:                                       # 远处另有一小块蓝
        blue[5:25, 5:5 + pool] = True

    h, w = blue.shape
    blue_cnt = int(blue.sum())
    if blue_cnt == 0:
        if verbose:
            print('      没有蓝色像素')
        return 0

    # --- 几何基准：蓝像素最宽的那一行 → 直径 dmax、中心 (dcx,dcy) ---
    rw = np.zeros(h, dtype=np.int32)
    rc = np.zeros(h, dtype=np.int32)
    for y in range(h):
        xs2 = np.where(blue[y])[0]
        if xs2.size:
            rw[y] = int(xs2.max() - xs2.min() + 1)
            rc[y] = int((xs2.min() + xs2.max()) // 2)
    wy = int(np.argmax(rw))
    dmax = int(rw[wy]); dcx = int(rc[wy]); dcy = wy

    # 连续"够宽的行"最长段：只作调试参考
    wide = rw * 20 >= 3 * dmax
    run = 0; cur = 0
    for y in range(h):
        if wide[y]:
            cur += 1
            run = max(run, cur)
        else:
            cur = 0

    barea = max(dmax * dmax, 1)
    blue_ok = (blue_cnt >= MIN_BLUE and BOX_MIN <= dmax <= BOX_MAX and
               blue_cnt * 100 >= barea * FILL_MIN)

    yy, xx = np.mgrid[0:h, 0:w]
    inside = (np.abs(xx - dcx) * 100 <= MASK_FRAC * dmax) & \
             (np.abs(yy - dcy) * 100 <= MASK_FRAC * dmax)
    head_band = inside & (yy < dcy)          # 头部带 = 窗口上半部分

    wb = white & inside
    cnt = int(wb.sum())
    arrow_ok = (cnt >= MIN_WHITE and cnt * 100 <= barea * 80)

    # 判据 A：头部带白像素偏离量之和（三档）
    head = wb & head_band
    lsum = int(np.maximum(dcx - xx, 0)[head].sum())
    rsum = int(np.maximum(xx - dcx, 0)[head].sum())
    lcnt = int((head & (xx < dcx)).sum())
    rcnt = int((head & (xx > dcx)).sum())
    lc_need = 40 if barea >= 2560 else (barea >> 6)
    ls_need = 400 if barea >= 12800 else (barea >> 5)
    up_need = 500 if barea >= 32000 else (barea >> 6)
    evid_l = lcnt >= lc_need and lsum > ls_need
    evid_r = rcnt >= lc_need and rsum > ls_need
    a_strong_left = evid_l and lsum * 16 > rsum * 23                # >1.44 倍，可单独定方向
    a_strong_right = evid_r and rsum * 16 > lsum * 23
    a_left = evid_l and lsum * 5 > rsum * 6                         # >1.2 倍，要与 B 相互印证
    a_right = evid_r and rsum * 5 > lsum * 6

    # 判据 B：窗口上半部蓝像素的左右不对称（1.25 倍，蓝偏右 ⇒ 箭头在左）
    up = blue & (np.abs(yy - dcy) * 100 <= MASK_FRAC * dmax) & (yy < dcy)
    ul = int((up & (xx < dcx)).sum()); ur = int((up & (xx > dcx)).sum())
    b_left = ur >= up_need and ur * 4 > ul * 5
    b_right = ul >= up_need and ul * 4 > ur * 5

    # 最终方向：A 单独够强(1.8)，或者 A、B 同时指向同一侧(各 1.25)
    t = 0
    if blue_ok and arrow_ok:
        if a_strong_left or (a_left and b_left):
            t = 1
        elif a_strong_right or (a_right and b_right):
            t = 2
        else:
            t = 4
    if verbose:
        print('      蓝=%6d 直径=%3d 中心=(%3d,%3d) 连续宽行=%3d 填充=%4.1f%% | 白=%6d 头带 lsum=%7d rsum=%7d 个数 %4d/%4d '
              '| 上半部蓝 左=%5d 右=%5d (%.2f) | ok=%d/%d -> %s'
              % (blue_cnt, dmax, dcx, dcy, run, blue_cnt * 100.0 / barea, cnt, lsum, rsum, lcnt, rcnt,
                 ul, ur, ur / max(ul, 1), blue_ok, arrow_ok, NAME[t]))
    return t


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), '图标')
    files = []
    for ext in ('*.jpg', '*.jpeg', '*.png', '*.bmp'):
        files += glob.glob(os.path.join(root, ext))
    files.sort()
    if not files:
        print('没找到图片：', root)
        return
    for p in files:
        name = os.path.basename(p)
        a = np.asarray(Image.open(p).convert('RGB'))
        print('=' * 100)
        print('%s  %dx%d%s' % (name, a.shape[1], a.shape[0],
                               ('   真值=%s' % NAME[TRUTH[name]]) if name in TRUTH else ''))
        print('  [旧判据：B>=60 且 B>=max(R,G)+15]')
        detect(a, blue_rule='old')
        print('  [新判据：比值 + 抗污染几何]')
        t = detect(a)
        if name in TRUTH:
            print('  => %s' % ('正确' if t == TRUTH[name] else '<<< 与真值不符'))
        print('  抗干扰：')
        for tag, kw in (('画面另加 40 像素宽蓝块', dict(pool=40)),
                        ('另加 160 像素宽蓝块', dict(pool=160)),
                        ('整幅压暗到 35%', dict(wash=0.35)),
                        ('整幅晒淡 35%', dict(wash=0.35)),
                        ('蓝块 + 晒淡 35%', dict(pool=40, wash=0.35))):
            td = detect(a, verbose=False, **kw)
            mark = ''
            if name in TRUTH:
                mark = 'OK' if td == TRUTH[name] else '<<< 错'
            print('      %-22s -> %s %s' % (tag, NAME[td], mark))
        print('  缩小（模拟标志离得远/在画面里很小）：')
        for sc in (0.6, 0.4, 0.25, 0.15):
            im = Image.open(p).convert('RGB')
            im = im.resize((max(8, int(im.width * sc)), max(8, int(im.height * sc))), Image.LANCZOS)
            td = detect(np.asarray(im), verbose=False)
            mark = ''
            if name in TRUTH:
                mark = 'OK' if td == TRUTH[name] else '<<< 错'
            print('      缩到 %3d%%  %-4s %s' % (sc * 100, NAME[td], mark))


if __name__ == '__main__':
    main()