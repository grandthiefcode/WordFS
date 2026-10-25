package org.example.demo_backend.fsrs;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 背单词业务的 FSRS 服务：把核心算法与数据库持久化串起来。
 *
 * <p>核心流程：
 * <ol>
 *   <li>用户答完一题，调用 {@link #recordAnswer} 提交评分；</li>
 *   <li>后端用 {@link FsrsAlgorithm} 计算新记忆状态与下次复习时间并落库；</li>
 *   <li>用户进入复习页，调用 {@link #getDueWords} 拉取“到期待复习”的单词。</li>
 * </ol>
 */
@Service
public class WordReviewService {

    private final FsrsAlgorithm fsrs = new FsrsAlgorithm();
    private final WordReviewRepository repository;

    public WordReviewService(WordReviewRepository repository) {
        this.repository = repository;
    }

    /**
     * 提交一次作答并更新记忆状态。
     *
     * @param userId 用户 ID
     * @param wordId 单词 ID
     * @param rating 本次评分（again/hard/good/easy）
     * @param now    当前时间
     * @return 更新后的记录（含算法预测的下次复习时间）
     */
    @Transactional
    public WordReviewRecord recordAnswer(Long userId, Long wordId, Rating rating, LocalDateTime now) {
        WordReviewRecord rec = repository.findByUserIdAndWordId(userId, wordId);

        // 计算距上次复习的天数；新词为 null（首次作答）
        double elapsedDays = 0.0;
        MemoryState state = null;
        if (rec != null && rec.getLastReviewTime() != null) {
            state = new MemoryState(rec.getStability(), rec.getDifficulty());
            elapsedDays = Duration.between(rec.getLastReviewTime(), now).toSeconds() / 86400.0;
        }

        // 执行 FSRS 更新（新词自动初始化状态）
        double retention = (rec != null && rec.getRequestedRetention() != null)
                ? rec.getRequestedRetention()
                : FsrsAlgorithm.DEFAULT_REQUESTED_RETENTION;
        ReviewResult result = fsrs.review(state, rating, elapsedDays, retention);

        if (rec == null) {
            rec = new WordReviewRecord();
            rec.setUserId(userId);
            rec.setWordId(wordId);
            rec.setRequestedRetention(retention);
        }

        rec.setStability(result.getNewState().getStability());
        rec.setDifficulty(result.getNewState().getDifficulty());
        rec.setElapsedDays(elapsedDays);
        rec.setLastReviewTime(now);
        rec.setNextReviewTime(now.plusSeconds((long) Math.round(result.getIntervalDays() * 86400.0)));
        rec.setRepetitions(rec.getRepetitions() + 1);
        if (rating == Rating.AGAIN) {
            rec.setLapses(rec.getLapses() + 1);
            // 连续答错计数 +1，并打断连续答对
            rec.setConsecutiveWrong(rec.getConsecutiveWrong() + 1);
            rec.setConsecutiveCorrect(0);
        } else {
            // 答对（hard/good/easy）：连续答对 +1，并清零连续答错
            rec.setConsecutiveCorrect(rec.getConsecutiveCorrect() + 1);
            rec.setConsecutiveWrong(0);
        }
        repository.save(rec);
        return rec;
    }

    /**
     * 查询某用户某单词的复习记录（未学时为 null）。
     */
    public WordReviewRecord find(Long userId, Long wordId) {
        return repository.findByUserIdAndWordId(userId, wordId);
    }

    /**
     * 预测某个单词当前（距离上次复习 elapsedDays 天后）的遗忘概率，用于前端展示。
     */
    public double predictForgettingProbability(Long userId, Long wordId, double elapsedDays) {
        WordReviewRecord rec = repository.findByUserIdAndWordId(userId, wordId);
        if (rec == null) {
            throw new IllegalArgumentException("该单词尚无学习记录");
        }
        MemoryState state = new MemoryState(rec.getStability(), rec.getDifficulty());
        return fsrs.predictForgettingProbability(state, elapsedDays);
    }

    /**
     * 拉取当前时间点“到期待复习”的单词列表（next_review_time <= now）。
     * 智能复习模式就靠它替代原先的“全量已学单词复习”。
     */
    public List<WordReviewRecord> getDueWords(Long userId, LocalDateTime now) {
        return repository.findDueWords(userId, now);
    }
}
