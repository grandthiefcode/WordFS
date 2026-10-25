package org.example.demo_backend.fsrs;

/**
 * 一次复习的结果：更新后的记忆状态 + 预测信息。
 */
public final class ReviewResult {

    /** 更新后的记忆状态。 */
    private final MemoryState newState;

    /** 本次复习时的记忆保持率 R（0~1）。 */
    private final double retrievability;

    /** 预测的下次复习间隔（天）。 */
    private final double intervalDays;

    /** 本次评分。 */
    private final Rating rating;

    public ReviewResult(MemoryState newState, double retrievability, double intervalDays, Rating rating) {
        this.newState = newState;
        this.retrievability = retrievability;
        this.intervalDays = intervalDays;
        this.rating = rating;
    }

    public MemoryState getNewState() {
        return newState;
    }

    public double getRetrievability() {
        return retrievability;
    }

    public double getForgettingProbability() {
        return 1.0 - retrievability;
    }

    public double getIntervalDays() {
        return intervalDays;
    }

    public Rating getRating() {
        return rating;
    }

    @Override
    public String toString() {
        return "ReviewResult{newState=" + newState
                + ", retrievability=" + retrievability
                + ", intervalDays=" + intervalDays
                + ", rating=" + rating + '}';
    }
}
