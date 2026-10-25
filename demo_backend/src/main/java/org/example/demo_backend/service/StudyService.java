package org.example.demo_backend.service;

import org.example.demo_backend.common.Result;
import org.example.demo_backend.dto.StudySubmitRequest;
import org.example.demo_backend.entity.Word;
import org.example.demo_backend.fsrs.Rating;
import org.example.demo_backend.fsrs.WordReviewService;
import org.example.demo_backend.mapper.StudyMapper;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class StudyService {
    private final StudyMapper studyMapper;
    private final WordReviewService wordReviewService;

    public StudyService(StudyMapper studyMapper, WordReviewService wordReviewService) {
        this.studyMapper = studyMapper;
        this.wordReviewService = wordReviewService;
    }

    public Result<String> submit(StudySubmitRequest request) {
        Integer correctRate = request.getIsCorrect() ? 100 : 0;
        boolean reviewMode = "review".equalsIgnoreCase(request.getPracticeMode());

        studyMapper.insertStudyRecord(request.getUserId(), request.getBookTitle(), correctRate,
                request.getPracticeMode());

        if (request.getWordId() != null) {
            studyMapper.ensureLearnedWord(request.getUserId(), request.getWordId());
            if (!request.getIsCorrect()) {
                studyMapper.upsertWrongWord(request);
            }
            if (reviewMode) {
                studyMapper.markLearnedWordReviewed(request.getUserId(), request.getWordId());
            }

            // FSRS 记忆状态更新:评分缺省时按对错映射(答对=good,答错=again)
            Rating fsrsRating = resolveRating(request);
            wordReviewService.recordAnswer(request.getUserId(), request.getWordId(),
                    fsrsRating, LocalDateTime.now());
        }

        studyMapper.updateUserStats(request.getUserId(), correctRate, request.getIsCorrect(),
            request.getPracticeMode());

        if (request.getWordId() != null && !reviewMode) {
            studyMapper.ensureUserBook(request.getUserId(), request.getWordId());
            studyMapper.updateUserBookProgress(request.getUserId(), request.getWordId());
        }

        return Result.success("submit success");
    }

    /** FSRS 四级评分解析:前端显式传有效 rating(1~4) 用之,否则按对错映射。 */
    private Rating resolveRating(StudySubmitRequest request) {
        if (request.getRating() != null && request.getRating() >= 1 && request.getRating() <= 4) {
            return Rating.fromCode(request.getRating());
        }
        return request.getIsCorrect() ? Rating.GOOD : Rating.AGAIN;
    }

    /** 复习模式:优先返回 FSRS 到期队列,无到期词时回退错题优先的已学词列表。 */
    public List<Word> findReviewWords(Long userId, Long bookId, Integer limit) {
        List<Word> fsrsDue = studyMapper.findFsrsDueWords(userId, bookId, limit);
        if (fsrsDue != null && !fsrsDue.isEmpty()) {
            return fsrsDue;
        }
        return studyMapper.findReviewWords(userId, bookId, limit);
    }
}
