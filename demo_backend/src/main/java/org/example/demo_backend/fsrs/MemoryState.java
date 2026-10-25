package org.example.demo_backend.fsrs;

/**
 * FSRS 记忆状态（Memory State）。
 *
 * <p>FSRS 用两个核心变量描述一个单词/卡片的记忆状态：
 * <ul>
 *   <li><b>Stability S</b>：记忆稳定性，单位为“天”。定义为记忆可提取性 (R) 从 100%
 *       衰减到 90% 所需的时间。S 越大表示记得越牢。</li>
 *   <li><b>Difficulty D</b>：记忆难度，取值范围 [1, 10]。
 *       1 表示最容易，10 表示最难。难度高的材料，答对后稳定性提升更慢。</li>
 * </ul>
 *
 * <p>该类为不可变对象，每次复习后由 {@link FsrsAlgorithm} 返回新的状态。
 */
public final class MemoryState {

    /** 记忆稳定性（天）。 */
    private final double stability;

    /** 记忆难度（1~10）。 */
    private final double difficulty;

    public MemoryState(double stability, double difficulty) {
        this.stability = stability;
        this.difficulty = difficulty;
    }

    public double getStability() {
        return stability;
    }

    public double getDifficulty() {
        return difficulty;
    }

    @Override
    public String toString() {
        return "MemoryState{stability=" + stability + ", difficulty=" + difficulty + '}';
    }
}
