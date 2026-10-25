package org.example.demo_backend.fsrs;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

/**
 * FSRS-4.5 核心算法实现。
 *
 * <p>本类是纯算法逻辑，不依赖任何框架，可直接复制进任意 Java 后端（Spring Boot、
 * 普通 Java 服务等）。公式严格遵循官方 FSRS-4.5 规范：
 *
 * <ul>
 *   <li>遗忘曲线（幂律）：R(t, S) = (1 + FACTOR·t/S)^DECAY，DECAY=-0.5，FACTOR=19/81</li>
 *   <li>初始稳定性：S0(G) = w[G-1]</li>
 *   <li>初始难度：D0(G) = w4 - e^(w5·(G-1)) + 1，裁剪到 [1,10]</li>
 *   <li>复习成功稳定性：S'_r = S·(e^w8·(11-D)·S^-w9·(e^(w10·(1-R))-1)·hardPenalty·easyBonus + 1)</li>
 *   <li>遗忘后稳定性：S'_f = w11·D^-w12·((S+1)^w13 - 1)·e^(w14·(1-R))，且 min(S, S'_f)</li>
 *   <li>难度更新：D' = w7·D0(3) + (1-w7)·(D - w6·(G-3))，裁剪到 [1,10]</li>
 *   <li>复习间隔：I(r, S) = (S/FACTOR)·(r^(1/DECAY) - 1)，当 r=0.9 时 I = S</li>
 * </ul>
 */
public final class FsrsAlgorithm {

    /** 遗忘曲线衰减指数。 */
    private static final double DECAY = -0.5;

    /** 遗忘曲线缩放因子，保证 R(S, S) = 0.9。 */
    private static final double FACTOR = 19.0 / 81.0;

    /** 默认目标记忆保持率。 */
    public static final double DEFAULT_REQUESTED_RETENTION = 0.9;

    private final FsrsParameters params;

    public FsrsAlgorithm() {
        this(new FsrsParameters());
    }

    public FsrsAlgorithm(FsrsParameters params) {
        this.params = params;
    }

    public FsrsParameters getParams() {
        return params;
    }

    // ------------------------------------------------------------------
    // 遗忘曲线
    // ------------------------------------------------------------------

    /**
     * 计算某个记忆状态经过 elapsedDays 天后的可提取性（记忆保持率）R。
     *
     * <p>这就是“预测遗忘概率”的核心：遗忘概率 = 1 - R。
     *
     * @param state       当前记忆状态（S, D）
     * @param elapsedDays 距上次复习经过的天数（>= 0）
     * @return 记忆保持率 R，范围约 (0, 1]
     */
    public double predictRetrievability(MemoryState state, double elapsedDays) {
        if (elapsedDays < 0) {
            throw new IllegalArgumentException("elapsedDays must be >= 0, got " + elapsedDays);
        }
        return Math.pow(1.0 + FACTOR * elapsedDays / state.getStability(), DECAY);
    }

    /**
     * 预测遗忘概率 = 1 - R。
     */
    public double predictForgettingProbability(MemoryState state, double elapsedDays) {
        return 1.0 - predictRetrievability(state, elapsedDays);
    }

    /**
     * 计算下一个复习间隔（天）。
     *
     * <p>即求解遗忘曲线，使复习时的记忆保持率达到目标 requestedRetention。
     *
     * @param state              最新记忆状态
     * @param requestedRetention 目标记忆保持率，默认 0.9（不传时用默认值）
     */
    public double nextIntervalDays(MemoryState state, double requestedRetention) {
        validateRetention(requestedRetention);
        double s = state.getStability();
        // 1/DECAY = -2
        return s / FACTOR * (Math.pow(requestedRetention, 1.0 / DECAY) - 1.0);
    }

    public double nextIntervalDays(MemoryState state) {
        return nextIntervalDays(state, DEFAULT_REQUESTED_RETENTION);
    }

    // ------------------------------------------------------------------
    // 新卡片初始化（首次学习）
    // ------------------------------------------------------------------

    /**
     * 初始化一个新单词（首次评分）的记忆状态。
     *
     * <p>对从未复习过的新词，用户第一次作答（按评分 G）后得到初始状态 S0(G)、D0(G)。
     *
     * @param rating 首次评分（again/hard/good/easy）
     */
    public MemoryState initNewState(Rating rating) {
        int g = rating.getCode();
        double s0 = params.w(g - 1);
        double d0 = initialDifficulty(g);
        return new MemoryState(s0, d0);
    }

    // ------------------------------------------------------------------
    // 核心复习更新
    // ------------------------------------------------------------------

    /**
     * 对一次复习结果执行 FSRS 状态更新，返回新记忆状态与预测间隔。
     *
     * @param state              复习前的记忆状态（新词可传 null，此时按首次评分初始化）
     * @param rating             本次评分（again/hard/good/easy）
     * @param elapsedDays        距上次复习经过的天数（>= 0；新词传 0 或忽略）
     * @param requestedRetention 目标记忆保持率，默认 0.9
     * @return 复习结果（新状态 + 预测的下次间隔 + 本次保持率）
     */
    public ReviewResult review(MemoryState state, Rating rating, double elapsedDays,
                               double requestedRetention) {
        validateRetention(requestedRetention);

        // 新词：先初始化状态
        if (state == null) {
            state = initNewState(rating);
            elapsedDays = 0.0;
        }
        if (elapsedDays < 0) {
            throw new IllegalArgumentException("elapsedDays must be >= 0, got " + elapsedDays);
        }

        int g = rating.getCode();
        double S = state.getStability();
        double D = state.getDifficulty();
        double R = predictRetrievability(state, elapsedDays);

        double newS = updateStability(S, D, R, g);
        double newD = updateDifficulty(D, g);

        MemoryState newState = new MemoryState(newS, newD);
        double intervalDays = nextIntervalDays(newState, requestedRetention);
        return new ReviewResult(newState, R, intervalDays, rating);
    }

    /** 便捷重载：使用默认目标保持率 0.9。 */
    public ReviewResult review(MemoryState state, Rating rating, double elapsedDays) {
        return review(state, rating, elapsedDays, DEFAULT_REQUESTED_RETENTION);
    }

    /**
     * 便捷方法：根据预测间隔计算下次复习时间。
     *
     * @param state 最新记忆状态
     * @return 距 now 之后 requestedRetention 天数的复习时刻
     */
    public Instant predictNextReviewTime(MemoryState state, Instant now, double requestedRetention) {
        double days = nextIntervalDays(state, requestedRetention);
        return now.plus((long) Math.round(days * 24 * 3600), ChronoUnit.SECONDS);
    }

    // ------------------------------------------------------------------
    // 内部公式
    // ------------------------------------------------------------------

    private double initialDifficulty(int g) {
        double d = params.w(4) - Math.exp(params.w(5) * (g - 1)) + 1.0;
        return clamp(d, 1.0, 10.0);
    }

    private double updateDifficulty(double D, int g) {
        // 线性阻尼：评分>3 降低难度，评分<3 提高难度
        double d1 = D - params.w(6) * (g - 3);
        // 均值回归，目标为 D0(3)（FSRS-4.5 使用首次 good 的难度）
        double target = initialDifficulty(3);
        double d2 = params.w(7) * target + (1.0 - params.w(7)) * d1;
        return clamp(d2, 1.0, 10.0);
    }

    private double updateStability(double S, double D, double R, int g) {
        if (g == 1) {
            // 遗忘（again）：稳定性必须下降，取 min 保证不反弹
            double sFail = params.w(11)
                    * Math.pow(D, -params.w(12))
                    * (Math.pow(S + 1.0, params.w(13)) - 1.0)
                    * Math.exp(params.w(14) * (1.0 - R));
            return Math.min(S, sFail);
        }
        // 复习成功（hard/good/easy）
        double hardPenalty = (g == 2) ? params.w(15) : 1.0;
        double easyBonus   = (g == 4) ? params.w(16) : 1.0;
        double growth = Math.exp(params.w(8))
                * (11.0 - D)
                * Math.pow(S, -params.w(9))
                * (Math.exp(params.w(10) * (1.0 - R)) - 1.0)
                * hardPenalty
                * easyBonus;
        return S * (1.0 + growth);
    }

    private static void validateRetention(double r) {
        if (r <= 0.0 || r >= 1.0) {
            throw new IllegalArgumentException("requestedRetention must be in (0,1), got " + r);
        }
    }

    private static double clamp(double v, double min, double max) {
        return Math.max(min, Math.min(max, v));
    }
}
