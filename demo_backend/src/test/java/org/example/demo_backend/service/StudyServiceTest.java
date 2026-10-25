package org.example.demo_backend.service;

import org.example.demo_backend.dto.StudySubmitRequest;
import org.example.demo_backend.mapper.StudyMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class StudyServiceTest {
    @Mock
    private StudyMapper studyMapper;

    @InjectMocks
    private StudyService studyService;

    @Test
    void correctLearnAnswerDoesNotEnterWrongBook() {
        studyService.submit(request(false, true));

        verify(studyMapper, never()).upsertWrongWord(org.mockito.ArgumentMatchers.any());
        verify(studyMapper, never()).markLearnedWordReviewed(1L, 10L);
    }

    @Test
    void wrongLearnAnswerEntersWrongBook() {
        studyService.submit(request(false, false));

        verify(studyMapper).upsertWrongWord(org.mockito.ArgumentMatchers.any());
        verify(studyMapper, never()).markLearnedWordReviewed(1L, 10L);
    }

    @Test
    void correctReviewAnswerOnlyMarksReviewDate() {
        studyService.submit(request(true, true));

        verify(studyMapper, never()).upsertWrongWord(org.mockito.ArgumentMatchers.any());
        verify(studyMapper).markLearnedWordReviewed(1L, 10L);
    }

    @Test
    void wrongReviewAnswerAccumulatesAndMarksReviewDate() {
        studyService.submit(request(true, false));

        verify(studyMapper).upsertWrongWord(org.mockito.ArgumentMatchers.any());
        verify(studyMapper).markLearnedWordReviewed(1L, 10L);
    }

    private StudySubmitRequest request(boolean reviewMode, boolean correct) {
        StudySubmitRequest request = new StudySubmitRequest();
        request.setUserId(1L);
        request.setWordId(10L);
        request.setBookTitle("测试词书");
        request.setWord("test");
        request.setMeaning("测试");
        request.setIsCorrect(correct);
        request.setPracticeMode(reviewMode ? "review" : "learn");
        return request;
    }
}