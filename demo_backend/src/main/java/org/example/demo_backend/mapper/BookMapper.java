package org.example.demo_backend.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;
import org.example.demo_backend.entity.Book;
import org.example.demo_backend.dto.BookProgressResponse;


import java.util.List;

@Mapper
public interface BookMapper {
    @Select("""
        SELECT books.id,
               books.title,
               books.level_tag AS levelTag,
               books.description,
               COALESCE(actual_words.total_words, books.total_words) AS totalWords,
               books.accent_color AS accentColor,
               books.soft_color AS softColor,
               books.created_at AS createdAt,
               books.updated_at AS updatedAt
        FROM books
        LEFT JOIN (
            SELECT book_id, COUNT(*) AS total_words
            FROM words
            WHERE difficulty IS NULL OR difficulty <> 'API'
            GROUP BY book_id
        ) actual_words ON books.id = actual_words.book_id
        ORDER BY id
    """)
    List<Book> findAll();

    @Select("""
    SELECT b.id,
           b.title,
           b.level_tag AS levelTag,
           b.description,
           COALESCE(actual_words.total_words, b.total_words) AS totalWords,
           b.accent_color AS accentColor,
           b.soft_color AS softColor,
           COALESCE(ub.learned_words, 0) AS learnedWords,
           COALESCE(ub.today_new, 0) AS todayNew,
           (
             SELECT COUNT(*)
                         FROM learned_words lw
                         JOIN words w ON w.id = lw.word_id AND w.book_id = b.id
                         WHERE lw.user_id = #{userId}
                             AND (lw.last_reviewed_at IS NULL OR DATE(lw.last_reviewed_at) <> CURDATE())
           ) AS todayReview,
           CASE
             WHEN COALESCE(actual_words.total_words, b.total_words) <= 0 THEN 0
             ELSE LEAST(100, ROUND(COALESCE(ub.learned_words, 0) * 100 / COALESCE(actual_words.total_words, b.total_words)))
           END AS progress
    FROM books b
    LEFT JOIN (
        SELECT book_id, COUNT(*) AS total_words
        FROM words
        WHERE difficulty IS NULL OR difficulty <> 'API'
        GROUP BY book_id
    ) actual_words ON b.id = actual_words.book_id
    LEFT JOIN user_books ub
      ON b.id = ub.book_id
     AND ub.user_id = #{userId}
    ORDER BY b.id
""")
    List<BookProgressResponse> findProgressByUserId(Long userId);

}
