package org.example.demo_backend.config;

import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

@Component
public class DatabaseSchemaInitializer {
    private final DataSource dataSource;

    public DatabaseSchemaInitializer(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @jakarta.annotation.PostConstruct
    public void initialize() {
        try (Connection connection = dataSource.getConnection(); Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                CREATE TABLE IF NOT EXISTS learned_words (
                  id BIGINT NOT NULL AUTO_INCREMENT,
                  user_id BIGINT NOT NULL,
                  word_id BIGINT NOT NULL,
                  last_reviewed_at DATETIME DEFAULT NULL,
                  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                  PRIMARY KEY (id),
                  UNIQUE KEY uk_learned_words_user_word (user_id, word_id),
                  KEY fk_learned_words_user (user_id),
                  CONSTRAINT fk_learned_words_user FOREIGN KEY (user_id) REFERENCES users (id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                """);
            addColumnIfMissing(connection, "wrong_words", "last_reviewed_at", "DATETIME DEFAULT NULL");
                        statement.executeUpdate("""
                                DELETE duplicate_word
                                FROM wrong_words duplicate_word
                                JOIN wrong_words kept_word
                                    ON kept_word.user_id = duplicate_word.user_id
                                 AND kept_word.word_id = duplicate_word.word_id
                                 AND kept_word.id < duplicate_word.id
                                """);
            addUniqueIndexIfMissing(connection, "wrong_words", "uk_wrong_words_user_word", "user_id, word_id");
            statement.executeUpdate("""
                INSERT IGNORE INTO learned_words (user_id, word_id)
                SELECT user_id, word_id FROM wrong_words WHERE word_id IS NOT NULL
                """);
            statement.executeUpdate("""
                CREATE TABLE IF NOT EXISTS word_review (
                  id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                  user_id             BIGINT       NOT NULL,
                  word_id             BIGINT       NOT NULL,
                  stability           DOUBLE       NOT NULL,
                  difficulty          DOUBLE       NOT NULL,
                  elapsed_days        DOUBLE       DEFAULT 0,
                  last_review_time    DATETIME(3)  DEFAULT NULL,
                  next_review_time    DATETIME(3)  DEFAULT NULL,
                  requested_retention DOUBLE       NOT NULL DEFAULT 0.9,
                  repetitions         INT          NOT NULL DEFAULT 0,
                  lapses              INT          NOT NULL DEFAULT 0,
                  consecutive_correct INT          NOT NULL DEFAULT 0,
                  consecutive_wrong   INT          NOT NULL DEFAULT 0,
                  create_time         DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
                  update_time         DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                                      ON UPDATE CURRENT_TIMESTAMP(3),
                  PRIMARY KEY (id),
                  UNIQUE KEY uk_word_review_user_word (user_id, word_id),
                  KEY idx_word_review_next (user_id, next_review_time),
                  KEY fk_word_review_word (word_id),
                  CONSTRAINT fk_word_review_word FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE,
                  CONSTRAINT fk_word_review_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                """);
            addColumnIfMissing(connection, "word_review", "consecutive_correct", "INT NOT NULL DEFAULT 0");
            addColumnIfMissing(connection, "word_review", "consecutive_wrong", "INT NOT NULL DEFAULT 0");        } catch (Exception exception) {
            throw new IllegalStateException("数据库结构迁移失败", exception);
        }
    }

    private void addColumnIfMissing(Connection connection, String tableName, String columnName,
                                    String definition) throws Exception {
        DatabaseMetaData metadata = connection.getMetaData();
        try (ResultSet columns = metadata.getColumns(null, null, tableName, columnName)) {
            if (columns.next()) {
                return;
            }
        }

        try (Statement statement = connection.createStatement()) {
            statement.executeUpdate("ALTER TABLE " + tableName + " ADD COLUMN " + columnName + " " + definition);
        }
    }

    private void addUniqueIndexIfMissing(Connection connection, String tableName, String indexName,
                                         String columns) throws Exception {
        DatabaseMetaData metadata = connection.getMetaData();
        try (ResultSet indexes = metadata.getIndexInfo(null, null, tableName, true, false)) {
            while (indexes.next()) {
                if (indexName.equals(indexes.getString("INDEX_NAME"))) {
                    return;
                }
            }
        }

        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE " + tableName + " ADD UNIQUE KEY " + indexName + " (" + columns + ")")) {
            statement.executeUpdate();
        }
    }
}