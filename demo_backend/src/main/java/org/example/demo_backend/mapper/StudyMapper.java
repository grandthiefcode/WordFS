package org.example.demo_backend.mapper;

import org.apache.ibatis.annotations.*;
import org.example.demo_backend.dto.StudySubmitRequest;
import org.example.demo_backend.entity.Word;

import java.util.List;

@Mapper
public interface StudyMapper {
    @Insert("""
        INSERT INTO study_records(user_id, study_date, book_title, new_count, review_count, correct_rate, finished_words, duration_minutes)
         VALUES(#{userId}, CURDATE(), #{bookTitle},
             CASE WHEN #{practiceMode} = 'review' THEN 0 ELSE 1 END,
             CASE WHEN #{practiceMode} = 'review' THEN 1 ELSE 0 END,
             #{correctRate}, 1, 1)
    """)
    int insertStudyRecord(@Param("userId") Long userId,
                          @Param("bookTitle") String bookTitle,
                          @Param("correctRate") Integer correctRate,
                          @Param("practiceMode") String practiceMode);

    /** 仅记录答错单词；重复答错时累加错误次数。 */
    @Insert("""
        INSERT INTO wrong_words(user_id, word_id, word, meaning, book_title,
                                wrong_count, sentence_text, reason_text,
                                last_wrong_at)
        VALUES(#{request.userId}, #{request.wordId}, #{request.word}, #{request.meaning}, #{request.bookTitle},
               1,
               #{request.sentence}, #{request.reason},
               NOW())
        ON DUPLICATE KEY UPDATE
          wrong_count = wrong_count + 1,
          last_wrong_at = NOW(),
          sentence_text = #{request.sentence},
          reason_text = #{request.reason},
          updated_at = NOW()
    """)
    int upsertWrongWord(@Param("request") StudySubmitRequest request);

    @Update("""
        UPDATE wrong_words
        SET last_reviewed_at = NOW(),
            updated_at = NOW()
        WHERE user_id = #{userId}
          AND word_id = #{wordId}
    """)
    int markWordReviewed(@Param("userId") Long userId,
                         @Param("wordId") Long wordId);

    @Insert("""
        INSERT INTO learned_words(user_id, word_id, last_reviewed_at)
        VALUES(#{userId}, #{wordId}, NULL)
        ON DUPLICATE KEY UPDATE updated_at = NOW()
    """)
    int ensureLearnedWord(@Param("userId") Long userId,
                          @Param("wordId") Long wordId);

    @Update("""
        UPDATE learned_words
        SET last_reviewed_at = NOW(), updated_at = NOW()
        WHERE user_id = #{userId} AND word_id = #{wordId}
    """)
    int markLearnedWordReviewed(@Param("userId") Long userId,
                                @Param("wordId") Long wordId);

    @Update("""
        UPDATE users
          SET total_learned_words = total_learned_words
              + CASE WHEN #{practiceMode} = 'review' THEN 0 ELSE 1 END,
            accuracy_rate = #{correctRate}
        WHERE id = #{userId}
    """)
    int updateUserStats(@Param("userId") Long userId,
                        @Param("correctRate") Integer correctRate,
                        @Param("isCorrect") Boolean isCorrect,
                        @Param("practiceMode") String practiceMode);

    @Insert("""
        INSERT IGNORE INTO user_books(user_id, book_id, learned_words, today_new, today_review, progress)
        SELECT #{userId}, book_id, 0, 0, 0, 0
        FROM words
        WHERE id = #{wordId}
          AND (difficulty IS NULL OR difficulty <> 'API')
    """)
    int ensureUserBook(@Param("userId") Long userId,
                       @Param("wordId") Long wordId);

    @Update("""
        UPDATE user_books ub
        JOIN words w ON ub.book_id = w.book_id
        JOIN (
            SELECT book_id, COUNT(*) AS total_words
            FROM words
            WHERE difficulty IS NULL OR difficulty <> 'API'
            GROUP BY book_id
        ) actual_words ON actual_words.book_id = ub.book_id
        SET ub.learned_words = ub.learned_words + 1,
            ub.today_new = ub.today_new + 1,
            ub.progress = LEAST(100, ROUND((ub.learned_words + 1) * 100 / actual_words.total_words))
        WHERE ub.user_id = #{userId}
          AND w.id = #{wordId}
          AND (w.difficulty IS NULL OR w.difficulty <> 'API')
    """)
    int updateUserBookProgress(@Param("userId") Long userId,
                               @Param("wordId") Long wordId);

    /** 复习模式只返回已经进入错题本且今天尚未复习的单词。 */
    @Select("""
                SELECT w.id, w.book_id AS bookId, w.word, w.phonetic, w.meaning,
                             w.memory_tip AS memoryTip, w.example_text AS exampleText,
                             w.translation_text AS translationText, w.answer, w.difficulty
                FROM learned_words lw
                JOIN words w ON w.id = lw.word_id
                LEFT JOIN wrong_words ww ON ww.user_id = lw.user_id AND ww.word_id = lw.word_id
                WHERE lw.user_id = #{userId}
                    AND w.book_id = #{bookId}
                    AND (lw.last_reviewed_at IS NULL OR DATE(lw.last_reviewed_at) <> CURDATE())
                ORDER BY COALESCE(ww.wrong_count, 0) DESC, lw.created_at ASC
                LIMIT #{limit}
    """)
    List<Word> findReviewWords(@Param("userId") Long userId,
                               @Param("bookId") Long bookId,
                               @Param("limit") Integer limit);

    /** FSRS 到期复习队列:先按连续表现权重（连续答错优先、连续答对延后），同权重内按 next_review_time 升序。 */
    @Select("""
                SELECT w.id, w.book_id AS bookId, w.word, w.phonetic, w.meaning,
                             w.memory_tip AS memoryTip, w.example_text AS exampleText,
                             w.translation_text AS translationText, w.answer, w.difficulty
                FROM word_review wr
                JOIN words w ON w.id = wr.word_id
                WHERE wr.user_id = #{userId}
                    AND w.book_id = #{bookId}
                    AND wr.next_review_time <= NOW()
                ORDER BY (wr.consecutive_wrong * 10 - wr.consecutive_correct * 3) DESC, wr.next_review_time ASC
                LIMIT #{limit}
    """)
    List<Word> findFsrsDueWords(@Param("userId") Long userId,
                                @Param("bookId") Long bookId,
                                @Param("limit") Integer limit);
}
