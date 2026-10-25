package org.example.demo_backend.fsrs;

import java.util.Arrays;

/**
 * FSRS-4.5 算法参数。
 *
 * <p>FSRS-4.5 使用 17 个可训练参数 w[0]~w[16]。默认参数为官方在
 * fsrs-benchmark（约 17 亿次复习、2 万用户）上优化得到的公开值，可直接使用，
 * 无需训练即可获得优于 SM-2 的预测效果。
 *
 * <p>参数含义：
 * <pre>
 *   w[0]~w[3]  首次评分对应的初始稳定性 S0(G)，G=again/hard/good/easy
 *   w[4]      初始难度基准（即 D0(1)，首次评分为 again 时的难度）
 *   w[5]      初始难度随评分衰减系数
 *   w[6]      难度更新幅度（每次复习难度线性调整量）
 *   w[7]      难度均值回归权重（防止“难度地狱”）
 *   w[8]      复习成功后的稳定性增长基准
 *   w[9]      稳定性增长关于 S 的指数（负值，S 越大增长越慢）
 *   w[10]     稳定性增长关于 R 的指数（间隔效应）
 *   w[11]     遗忘后稳定性基准
 *   w[12]     遗忘后稳定性关于 D 的指数
 *   w[13]     遗忘后稳定性关于 S 的指数
 *   w[14]     遗忘后稳定性关于 R 的指数
 *   w[15]     hard（勉强）评分惩罚系数
 *   w[16]     easy（轻松）评分奖励系数
 * </pre>
 */
public final class FsrsParameters {

    /** FSRS-4.5 官方默认参数（17 个权重）。 */
    public static final double[] DEFAULT_PARAMS_V4_5 = {
        0.4872, 1.4003, 3.7145, 13.8206,  // w0~w3 初始稳定性
        5.1618, 1.2298,                   // w4, w5 初始难度
        0.8975, 0.031,                    // w6, w7 难度更新
        1.6474, 0.1367, 1.0461,           // w8, w9, w10 复习成功稳定性
        2.1072, 0.0793, 0.3246, 1.587,    // w11~w14 遗忘后稳定性
        0.2272, 2.8755                    // w15, w16 hard/easy 调整
    };

    private final double[] w;

    public FsrsParameters() {
        this(DEFAULT_PARAMS_V4_5);
    }

    public FsrsParameters(double[] w) {
        if (w == null || w.length != 17) {
            throw new IllegalArgumentException("FSRS-4.5 requires exactly 17 parameters");
        }
        this.w = Arrays.copyOf(w, w.length);
    }

    /** 返回 w[i]。 */
    public double w(int i) {
        return w[i];
    }
}
