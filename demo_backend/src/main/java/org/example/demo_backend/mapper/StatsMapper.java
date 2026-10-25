package org.example.demo_backend.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;
import org.example.demo_backend.dto.StatsOverviewResponse;

import java.time.LocalDate;
import java.util.List;

@Mapper
public interface StatsMapper {
    @Select("""
         SELECT u.id AS userId,
             (SELECT COUNT(*)
                                FROM learned_words lw
                                JOIN words w ON w.id = lw.word_id
                                WHERE lw.user_id = u.id
                AND w.book_id = u.selected_book_id
                                    AND (lw.last_reviewed_at IS NULL OR DATE(lw.last_reviewed_at) <> CURDATE())) AS reviewDue
         FROM users u
         WHERE u.id = #{userId}
    """)
    StatsOverviewResponse findUserStats(Long userId);

    @Select("""
        SELECT COALESCE(SUM(finished_words), 0)
        FROM study_records
        WHERE user_id = #{userId}
    """)
    Integer findTotalLearnedWords(Long userId);

    @Select("""
        SELECT COALESCE(ROUND(AVG(correct_rate)), 0)
        FROM study_records
        WHERE user_id = #{userId}
    """)
    Integer findAccuracyRate(Long userId);

    @Select("""
        SELECT DISTINCT study_date
        FROM study_records
        WHERE user_id = #{userId}
        ORDER BY study_date DESC
    """)
    List<LocalDate> findStudyDates(Long userId);

    @Select("""
        SELECT COALESCE(SUM(finished_words), 0)
        FROM study_records
        WHERE user_id = #{userId}
          AND study_date = CURDATE()
    """)
    Integer findTodayFinishedWords(Long userId);

    @Select("""
        SELECT COALESCE(ROUND(AVG(correct_rate)), 0)
        FROM study_records
        WHERE user_id = #{userId}
          AND study_date = CURDATE()
    """)
    Integer findTodayCorrectRate(Long userId);

    @Select("""
        SELECT COALESCE(b.total_words - COALESCE(ub.learned_words, 0), b.total_words)
        FROM books b
        LEFT JOIN user_books ub ON ub.book_id = b.id AND ub.user_id = #{userId}
        WHERE b.id = (SELECT selected_book_id FROM users WHERE id = #{userId})
    """)
    Integer findRemainingLearnWords(Long userId);
}
