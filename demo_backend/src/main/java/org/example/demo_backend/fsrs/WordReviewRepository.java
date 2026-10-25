package org.example.demo_backend.fsrs;

import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 单词复习记录数据访问层（MyBatis 注解实现，对应表 word_review）。
 */
@Mapper
public interface WordReviewRepository {

    @Select("""
        SELECT id, user_id AS userId, word_id AS wordId, stability, difficulty,
               elapsed_days AS elapsedDays, last_review_time AS lastReviewTime,
               next_review_time AS nextReviewTime, requested_retention AS requestedRetention,
               repetitions, lapses, consecutive_correct AS consecutiveCorrect,
               consecutive_wrong AS consecutiveWrong
        FROM word_review
        WHERE user_id = #{userId} AND word_id = #{wordId}
    """)
    WordReviewRecord findByUserIdAndWordId(@Param("userId") Long userId,
                                           @Param("wordId") Long wordId);

    @Insert("""
        INSERT INTO word_review(user_id, word_id, stability, difficulty, elapsed_days,
                                last_review_time, next_review_time, requested_retention,
                                repetitions, lapses, consecutive_correct, consecutive_wrong)
        VALUES(#{userId}, #{wordId}, #{stability}, #{difficulty}, #{elapsedDays},
               #{lastReviewTime}, #{nextReviewTime}, #{requestedRetention},
               #{repetitions}, #{lapses}, #{consecutiveCorrect}, #{consecutiveWrong})
        ON DUPLICATE KEY UPDATE
            stability = #{stability},
            difficulty = #{difficulty},
            elapsed_days = #{elapsedDays},
            last_review_time = #{lastReviewTime},
            next_review_time = #{nextReviewTime},
            requested_retention = #{requestedRetention},
            repetitions = #{repetitions},
            lapses = #{lapses},
            consecutive_correct = #{consecutiveCorrect},
            consecutive_wrong = #{consecutiveWrong},
            update_time = NOW()
    """)
    int save(WordReviewRecord record);

    /** 查询某用户到期待复习的单词（智能复习队列）。 */
    @Select("""
        SELECT id, user_id AS userId, word_id AS wordId, stability, difficulty,
               elapsed_days AS elapsedDays, last_review_time AS lastReviewTime,
               next_review_time AS nextReviewTime, requested_retention AS requestedRetention,
               repetitions, lapses, consecutive_correct AS consecutiveCorrect,
               consecutive_wrong AS consecutiveWrong
        FROM word_review
        WHERE user_id = #{userId} AND next_review_time <= #{now}
        ORDER BY (consecutive_wrong * 10 - consecutive_correct * 3) DESC, next_review_time ASC
    """)
    List<WordReviewRecord> findDueWords(@Param("userId") Long userId,
                                        @Param("now") LocalDateTime now);
}
