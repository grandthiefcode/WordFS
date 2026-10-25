import { BusinessError } from '@kit.BasicServicesKit';
import { ApiService } from '../api/ApiService';
import { UserProfile, userProfile } from '../data/AppState';
import { currentUser } from '../data/CurrentUser';
import { showToast, routerBack } from '../utils/UiFeedback';

interface ProfileResponseData {
  id: number;
  account: string;
  nickname: string;
  dailyTarget: number;
  signature: string;
  selectedBookId: number;
  totalLearnedWords: number;
  streakDays: number;
  accuracyRate: number;
  reviewDue: number;
}

interface ProfileResponse {
  code: number;
  message: string;
  data: ProfileResponseData | null;
}

interface UpdateProfileRequestBody {
  userId: number;
  nickname: string;
  dailyTarget: number;
  signature: string;
  selectedBookId: number;
}

interface BookOption {
  id: number;
  title: string;
}

interface BookListResponse {
  code: number;
  message: string;
  data: BookOption[] | null;
}

@Entry
@Component
struct ProfilePage {
  @State nickname: string = userProfile.nickname;
  @State goal: string = userProfile.dailyTarget.toString();
  @State signature: string = userProfile.signature;
  @State selectedBookId: number = userProfile.selectedBookId;
  @State errorMessage: string = '';
  @State userId: number = currentUser.id;
  @State bookList: BookOption[] = [];


  applyProfile(profile: UserProfile) {
    this.nickname = profile.nickname;
    this.goal = profile.dailyTarget.toString();
    this.signature = profile.signature;
    this.selectedBookId = profile.selectedBookId;
  }

  loadProfile() {
    ApiService.get('/api/user/profile?userId=' + this.userId)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as ProfileResponse;

          if (response.code !== 200 || response.data === null) {
            this.errorMessage = response.message;
            return;
          }

          userProfile.nickname = response.data.nickname;
          userProfile.dailyTarget = response.data.dailyTarget;
          userProfile.signature = response.data.signature;
          userProfile.selectedBookId = response.data.selectedBookId;
          userProfile.totalLearnedWords = response.data.totalLearnedWords;
          userProfile.streakDays = response.data.streakDays;
          userProfile.accuracyRate = response.data.accuracyRate;
          userProfile.reviewDue = response.data.reviewDue;

          this.applyProfile(userProfile);
          this.errorMessage = '';
        } catch (error) {
          const err = error as BusinessError<number>;
          this.errorMessage = '资料解析失败';
          console.error('load profile parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        this.errorMessage = '资料加载失败';
        console.error('load profile failed: ' + error.message);
      });
  }

  loadBooks() {
    ApiService.get('/api/books')
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as BookListResponse;
          if (response.code === 200 && response.data !== null) {
            this.bookList = response.data;
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('load profile books parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('load profile books failed: ' + error.message);
      });
  }

  displayAvatarText(): string {
    if (this.nickname.length === 0) {
      return '晨';
    }
    return this.nickname.substring(0, 1);
  }

  selectedBookTitle(): string {
    for (let i = 0; i < this.bookList.length; i++) {
      if (this.bookList[i].id === this.selectedBookId) {
        return this.bookList[i].title;
      }
    }
    return this.selectedBookId.toString();
  }

  parsedGoal(): number {
    const parsed: number = parseInt(this.goal, 10);
    if (isNaN(parsed)) {
      return 0;
    }
    return parsed;
  }

  saveProfile() {
    if (this.nickname.trim().length === 0) {
      this.errorMessage = '昵称不能为空';
      return;
    }

    const dailyTarget: number = this.parsedGoal();
    if (dailyTarget <= 0) {
      this.errorMessage = '每日目标必须大于 0';
      return;
    }

    const requestBody: UpdateProfileRequestBody = {
      userId: this.userId,
      nickname: this.nickname.trim(),
      dailyTarget: dailyTarget,
      signature: this.signature.trim(),
      selectedBookId: this.selectedBookId
    };

    ApiService.put('/api/user/profile', requestBody)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as ProfileResponse;

          if (response.code !== 200 || response.data === null) {
            this.errorMessage = response.message;
            return;
          }

          userProfile.nickname = response.data.nickname;
          userProfile.dailyTarget = response.data.dailyTarget;
          userProfile.signature = response.data.signature;
          userProfile.selectedBookId = response.data.selectedBookId;
          userProfile.totalLearnedWords = response.data.totalLearnedWords;
          userProfile.streakDays = response.data.streakDays;
          userProfile.accuracyRate = response.data.accuracyRate;
          userProfile.reviewDue = response.data.reviewDue;

          this.applyProfile(userProfile);
          this.errorMessage = '';
          showToast(this.getUIContext(), '保存成功');
          routerBack(this.getUIContext());
        } catch (error) {
          const err = error as BusinessError<number>;
          this.errorMessage = '保存响应解析失败';
          console.error('save profile parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        this.errorMessage = '保存失败，请检查网络或后端服务';
        console.error('save profile failed: ' + error.message);
      });
  }


  build() {
    Column() {
      this.pageHeader('个人资料');

      Scroll() {
        Column({ space: 14 }) {
          // 顶部用户信息卡片（紧凑）
          Column({ space: 8 }) {
            Column() {
              Text(this.displayAvatarText())
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor('#1E3A8A')
            .justifyContent(FlexAlign.Center)

            Text(this.nickname.length > 0 ? this.nickname : 'WordFS用户')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')

            Text('默认词书：' + this.selectedBookTitle())
              .fontSize(12)
              .fontColor('#64748B')
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({ width: 0.5, color: '#E5E7EB' })
          .alignItems(HorizontalAlign.Center)

          if (this.errorMessage.length > 0) {
            Column({ space: 8 }) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor('#DC2626');
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FEE2E2')
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start);
          }

          // 表单卡片
          Column({ space: 14 }) {
            this.formField('昵称', this.nickname, '请输入昵称', (value: string) => {
              this.nickname = value;
            })
            this.formField('每日学习目标', this.goal, '请输入每日学习词数', (value: string) => {
              this.goal = value;
            })
            this.formField('学习签名', this.signature, '写一句鼓励自己的话', (value: string) => {
              this.signature = value;
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({ width: 0.5, color: '#E5E7EB' })
          .alignItems(HorizontalAlign.Start)

          // 底部留白避免被按钮遮挡
          Column().height(16)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 88 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)

      // 底部固定操作栏：取消浅灰文字 + 保存深蓝主按钮（大尺寸醒目）
      Row({ space: 12 }) {
        Text('取消')
          .fontSize(14)
          .fontColor('#64748B')
          .width(80)
          .height(48)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            routerBack(this.getUIContext());
          })

        Button('保存')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .backgroundColor('#1E3A8A')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .borderRadius(12)
          .onClick(() => {
            this.saveProfile();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 0.5 }, color: { top: '#E5E7EB' } })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
    .onAppear(() => {
      this.loadProfile();
      this.loadBooks();
    });
  }

  @Builder
  formField(label: string, value: string, placeholder: string, onChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .width('100%')
        .fontSize(13)
        .fontColor('#64748B')
      TextInput({ text: value, placeholder: placeholder })
        .height(46)
        .backgroundColor('#F8FAFC')
        .borderRadius(10)
        .border({ width: 1, color: '#E5E7EB' })
        .fontSize(15)
        .fontColor('#0F172A')
        .padding({ left: 14, right: 14 })
        .onChange(onChange);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  pageHeader(title: string) {
    Row() {
      Text('返回')
        .fontSize(14)
        .fontColor('#1E3A8A')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .border({ width: 1, color: '#1E3A8A' })
        .onClick(() => {
          routerBack(this.getUIContext());
        })
      Blank()
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Blank()
      Text('    ')
        .fontSize(15)
        .opacity(0)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }
}

@Preview
@Component
struct ProfilePagePreview {
  build() {
    ProfilePage();
  }
}
