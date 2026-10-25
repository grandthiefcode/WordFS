package org.example.demo_backend.service;

import org.example.demo_backend.common.Result;
import org.example.demo_backend.dto.LoginRequest;
import org.example.demo_backend.dto.RegisterRequest;
import org.example.demo_backend.dto.UserResponse;
import org.example.demo_backend.entity.User;
import org.example.demo_backend.mapper.UserMapper;
import org.example.demo_backend.mapper.StatsMapper;
import org.example.demo_backend.util.PasswordUtil;
import org.springframework.stereotype.Service;
import org.example.demo_backend.dto.UpdateProfileRequest;


@Service
public class UserService {
    private final UserMapper userMapper;
    private final StatsMapper statsMapper;

    public UserService(UserMapper userMapper, StatsMapper statsMapper) {
        this.userMapper = userMapper;
        this.statsMapper = statsMapper;
    }

    /** 用 userId 补齐 UserResponse 上的 3 个统计字段（今日已学/今日正确率/未学词数） */
    private UserResponse fillStats(UserResponse response, Long userId) {
        response.setTodayFinishedWords(statsMapper.findTodayFinishedWords(userId));
        response.setTodayCorrectRate(statsMapper.findTodayCorrectRate(userId));
        response.setRemainingLearnWords(statsMapper.findRemainingLearnWords(userId));
        return response;
    }

    public Result<UserResponse> register(RegisterRequest request) {
        String account = request.getAccount().trim();

        if (userMapper.findByAccount(account) != null) {
            return Result.error("账号已存在");
        }

        User user = new User();
        user.setAccount(account);
        user.setPasswordHash(PasswordUtil.hash(request.getPassword()));
        user.setNickname(request.getNickname() == null || request.getNickname().isBlank() ? account : request.getNickname());
        user.setDailyTarget(30);
        user.setSignature("");
        user.setSelectedBookId(1L);

        userMapper.insert(user);
        return Result.success(fillStats(UserResponse.from(user), user.getId()));
    }

    public Result<UserResponse> login(LoginRequest request) {
        User user = userMapper.findByAccount(request.getAccount().trim());

        if (user == null) {
            return Result.error("账号或密码错误");
        }

        String passwordHash = PasswordUtil.hash(request.getPassword());
        if (!passwordHash.equals(user.getPasswordHash())) {
            return Result.error("账号或密码错误");
        }

        return Result.success(fillStats(UserResponse.from(user), user.getId()));
    }

    public Result<UserResponse> getProfile(Long userId) {
        User user = userMapper.findById(userId);

        if (user == null) {
            return Result.error("user not found");
        }

        return Result.success(fillStats(UserResponse.from(user), user.getId()));
    }

    public Result<UserResponse> updateProfile(UpdateProfileRequest request) {
        User user = userMapper.findById(request.getUserId());

        if (user == null) {
            return Result.error("user not found");
        }

        user.setNickname(request.getNickname());
        user.setDailyTarget(request.getDailyTarget());
        user.setSignature(request.getSignature() == null ? "" : request.getSignature());
        user.setSelectedBookId(request.getSelectedBookId());

        userMapper.updateProfile(user);

        User updatedUser = userMapper.findById(request.getUserId());
        return Result.success(fillStats(UserResponse.from(updatedUser), updatedUser.getId()));
    }

}
