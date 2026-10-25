package org.example.demo_backend.fsrs;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 单词复习记录实体（对应表 word_review）。
 *
 * <p>保存每个单词的 FSRS 记忆状态与复习进度，是预测算法的持久化载体。
 */
@Data
public class WordReviewRecord {

    private Long id;

    /** 用户 ID（FSRS 按用户独立建模）。 */
    private Long userId;

    /** 单词 ID（关联单词表）。 */
    private Long wordId;

    /** 记忆稳定性 S（天）。 */
    private Double stability;

    /** 记忆难度 D（1~10）。 */
    private Double difficulty;

    /** 距上次复习经过天数（用于计算 R）。 */
    private Double elapsedDays;

    /** 上次复习时间。 */
    private LocalDateTime lastReviewTime;

    /** 算法预测的下次复习时间。 */
    private LocalDateTime nextReviewTime;

    /** 目标记忆保持率（默认 0.9）。 */
    private Double requestedRetention = 0.9;

    /** 累计复习次数。 */
    private Integer repetitions = 0;

    /** 累计遗忘次数。 */
    private Integer lapses = 0;

    /** 连续答对次数（用于复习队列权重：连续答对降低优先级）。 */
    private Integer consecutiveCorrect = 0;

    /** 连续答错次数（用于复习队列权重：连续答错提高优先级）。 */
    private Integer consecutiveWrong = 0;
}
