package org.example.demo_backend.service;

import org.example.demo_backend.entity.Word;
import org.example.demo_backend.mapper.WordMapper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.stereotype.Service;
import org.example.demo_backend.common.Result;
import org.example.demo_backend.dto.WordSearchResponse;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

@Service
@EnableAsync
public class WordService {
    private final WordMapper wordMapper;
    private final ExternalDictionaryService externalDictionaryService;
    private final ExternalWordListService externalWordListService;
    private final ConcurrentHashMap<Long, Boolean> fillingBooks = new ConcurrentHashMap<>();

    public WordService(WordMapper wordMapper,
                       ExternalDictionaryService externalDictionaryService,
                       ExternalWordListService externalWordListService) {
        this.wordMapper = wordMapper;
        this.externalDictionaryService = externalDictionaryService;
        this.externalWordListService = externalWordListService;
    }

    public List<Word> findByBookId(Long bookId) {
        int current = wordMapper.countOfficialByBookId(bookId);
        if (current == 0 && fillingBooks.putIfAbsent(bookId, Boolean.TRUE) == null) {
            tryFillAsync(bookId);
        }
        return wordMapper.findByBookId(bookId);
    }

    @Async
    public void tryFillAsync(Long bookId) {
        try {
            externalWordListService.ensureWordsForBook(bookId, 10000);
        } catch (Exception e) {
            // 后台异步补齐失败不影响列表返回，下次列表请求会重试
        } finally {
            fillingBooks.remove(bookId);
        }
    }

    public Result<Integer> importExternalWords(Long bookId, Integer targetCount) {
        return Result.success(externalWordListService.ensureWordsForBook(bookId, targetCount));
    }

    public Result<Word> findNextByBookId(Long bookId) {
        Word word = wordMapper.findRandomByBookId(bookId);

        if (word == null) {
            return Result.error("word not found");
        }

        return Result.success(word);
    }

    public Result<WordSearchResponse> search(String keyword) {
        String cleanKeyword = keyword.trim().toLowerCase();

        WordSearchResponse cached = wordMapper.findSearchCache(cleanKeyword);
        if (cached != null) {
            return Result.success(cached);
        }

        WordSearchResponse response = externalDictionaryService.search(cleanKeyword);
        if (response == null) {
            return Result.error("word not found");
        }

        return Result.success(response);
    }

    /** 学习模式:返回词书前 limit 个词(按 id 顺序),前端根据已学进度过滤 */
    public List<Word> findForLearn(Long bookId, Integer limit) {
        return wordMapper.findForLearn(bookId, limit);
    }

    /** 选择题选项池:从词书随机取 limit 个词 */
    public List<Word> findOptionsByBookId(Long bookId, Integer limit) {
        return wordMapper.findOptionsByBookId(bookId, limit);
    }

}
