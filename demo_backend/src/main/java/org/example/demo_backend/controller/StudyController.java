package org.example.demo_backend.controller;

import jakarta.validation.Valid;
import org.example.demo_backend.common.Result;
import org.example.demo_backend.dto.StudySubmitRequest;
import org.example.demo_backend.entity.Word;
import org.example.demo_backend.service.StudyService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/study")
public class StudyController {
    private final StudyService studyService;

    public StudyController(StudyService studyService) {
        this.studyService = studyService;
    }

    @PostMapping("/submit")
    public Result<String> submit(@Valid @RequestBody StudySubmitRequest request) {
        return studyService.submit(request);
    }

    /** 复习模式:按错误次数优先返回已学习的错词 */
    @GetMapping("/review-list")
    public Result<List<Word>> reviewList(
            @RequestParam Long userId,
            @RequestParam Long bookId,
            @RequestParam(defaultValue = "20") Integer limit) {
        return Result.success(studyService.findReviewWords(userId, bookId, limit));
    }
}
