package org.example.demo_backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class StudySubmitRequest {
    @NotNull(message = "userId cannot be null")
    private Long userId;

    @NotBlank(message = "bookTitle cannot be empty")
    private String bookTitle;

    private Long wordId;

    @NotBlank(message = "word cannot be empty")
    private String word;

    @NotBlank(message = "meaning cannot be empty")
    private String meaning;

    @NotNull(message = "isCorrect cannot be null")
    private Boolean isCorrect;

    private String selectedAnswer;
    private String correctAnswer;
    private String sentence;
    private String reason;
    /** 练习模式:learn(学习模式) 或 review(复习模式),默认 learn */
    private String practiceMode;
    /** FSRS 四级评分:1=again(忘了) 2=hard(模糊) 3=good(记得) 4=easy(超熟);缺省时按 isCorrect 映射(答对=3,答错=1) */
    private Integer rating;
}
