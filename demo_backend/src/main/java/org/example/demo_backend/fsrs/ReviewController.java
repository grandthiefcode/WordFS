package org.example.demo_backend.fsrs;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.example.demo_backend.common.Result;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 背单词 App 的 FSRS 复习接口。
 */
@Tag(name = "智能复习", description = "FSRS-4.5 记忆算法复习接口")
@RestController
@RequestMapping("/api/review")
public class ReviewController {

    private final WordReviewService service;

    public ReviewController(WordReviewService service) {
        this.service = service;
    }

    /**
     * 提交一次作答并返回更新后的记忆状态与下次复习时间。
     * <pre>
     * POST /api/review/answer
     * Body: {"userId":1, "wordId":101, "rating":3}
     * rating: 1=again(忘了) 2=hard(模糊) 3=good(记得) 4=easy(超熟)
     * </pre>
     */
    @Operation(summary = "提交评分并更新 FSRS 记忆状态")
    @PostMapping("/answer")
    public Result<Map<String, Object>> answer(@RequestBody AnswerRequest req) {
        Rating rating = Rating.fromCode(req.getRating());
        WordReviewRecord rec = service.recordAnswer(req.getUserId(), req.getWordId(), rating, LocalDateTime.now());
        return Result.success(Map.of(
                "wordId", rec.getWordId(),
                "stability", rec.getStability(),
                "difficulty", rec.getDifficulty(),
                "nextReviewTime", rec.getNextReviewTime() != null ? rec.getNextReviewTime().toString() : null,
                "repetitions", rec.getRepetitions(),
                "lapses", rec.getLapses()
        ));
    }

    /**
     * 获取当前到期待复习的单词 ID 列表（智能复习队列）。
     * <pre>
     * GET /api/review/due?userId=1
     * </pre>
     */
    @Operation(summary = "获取 FSRS 到期复习队列（单词 ID 列表）")
    @GetMapping("/due")
    public Result<List<Long>> due(@RequestParam Long userId) {
        List<Long> dueIds = service.getDueWords(userId, LocalDateTime.now())
                .stream().map(WordReviewRecord::getWordId).collect(Collectors.toList());
        return Result.success(dueIds);
    }

    /**
     * 预测某个单词当前的遗忘概率（用于前端可视化展示）。
     * <pre>
     * GET /api/review/predict?userId=1&wordId=101
     * </pre>
     */
    @Operation(summary = "预测单词当前遗忘概率")
    @GetMapping("/predict")
    public Result<Map<String, Object>> predict(@RequestParam Long userId, @RequestParam Long wordId) {
        WordReviewRecord rec = service.find(userId, wordId);
        if (rec == null) {
            return Result.error(404, "该单词尚无学习记录");
        }
        double elapsed = (rec.getLastReviewTime() != null)
                ? java.time.Duration.between(rec.getLastReviewTime(), LocalDateTime.now()).toSeconds() / 86400.0
                : 0.0;
        double forget = service.predictForgettingProbability(userId, wordId, elapsed);
        return Result.success(Map.of(
                "wordId", wordId,
                "elapsedDays", elapsed,
                "forgettingProbability", forget,
                "stability", rec.getStability(),
                "difficulty", rec.getDifficulty()
        ));
    }

    /** 请求体。 */
    public static class AnswerRequest {
        private Long userId;
        private Long wordId;
        private int rating;

        public Long getUserId() { return userId; }
        public void setUserId(Long userId) { this.userId = userId; }
        public Long getWordId() { return wordId; }
        public void setWordId(Long wordId) { this.wordId = wordId; }
        public int getRating() { return rating; }
        public void setRating(int rating) { this.rating = rating; }
    }
}
