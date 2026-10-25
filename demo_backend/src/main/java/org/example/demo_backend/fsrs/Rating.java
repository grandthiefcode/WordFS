package org.example.demo_backend.fsrs;

/**
 * FSRS 答题评分枚举。
 * 对应 Anki / FSRS 的四档评分：
 * <pre>
 *   1 = again（忘记/答错）   -> 遗忘，进入重新学习
 *   2 = hard（勉强答对）
 *   3 = good（正常答对）     -> 默认最优
 *   4 = easy（轻松答对）
 * </pre>
 */
public enum Rating {

    AGAIN(1),
    HARD(2),
    GOOD(3),
    EASY(4);

    private final int code;

    Rating(int code) {
        this.code = code;
    }

    /** 返回 1~4 的数值评分。 */
    public int getCode() {
        return code;
    }

    /**
     * 将 1~4 的整数映射为评分。
     *
     * @throws IllegalArgumentException 当 code 不在 1~4 之间时
     */
    public static Rating fromCode(int code) {
        for (Rating r : values()) {
            if (r.code == code) {
                return r;
            }
        }
        throw new IllegalArgumentException("Invalid FSRS rating code: " + code + " (must be 1~4)");
    }
}
