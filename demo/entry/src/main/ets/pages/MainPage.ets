import {
  BookCard,
  LearningWord,
  userProfile
} from '../data/AppState';
import { ApiService } from '../api/ApiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { currentUser, resetCurrentUser } from '../data/CurrentUser';
import { showToast, pushUrl } from '../utils/UiFeedback';

interface ProfileResponseData {
  nickname: string;
  dailyTarget: number;
  signature: string;
  selectedBookId: number;
  totalLearnedWords: number;
  streakDays: number;
  accuracyRate: number;
  reviewDue: number;
  remainingLearnWords: number;
}

interface ProfileResponse {
  code: number;
  message: string;
  data: ProfileResponseData | null;
}

interface StatsResponseData {
  totalLearnedWords: number;
  streakDays: number;
  accuracyRate: number;
  reviewDue: number;
  todayFinishedWords: number;
  todayCorrectRate: number;
  remainingLearnWords: number;
}

interface StatsResponse {
  code: number;
  message: string;
  data: StatsResponseData | null;
}

interface BookProgressItem {
  id: number;
  title: string;
  levelTag: string;
  description: string;
  totalWords: number;
  learnedWords: number;
  todayNew: number;
  todayReview: number;
  progress: number;
  accentColor: string;
  softColor: string;
}

interface BookProgressResponse {
  code: number;
  message: string;
  data: BookProgressItem[] | null;
}

interface WordApiItem {
  id: number;
  bookId: number;
  word: string;
  phonetic: string;
  meaning: string;
  memoryTip: string;
  exampleText: string;
  translationText: string;
  answer: string;
  difficulty: string;
}

interface WordListResponse {
  code: number;
  message: string;
  data: WordApiItem[] | null;
}

/** 跳转词书单词列表页的路由参数 */
interface BookWordsRouteParams {
  bookId: number;
  bookTitle: string;
}

interface WordNextResponse {
  code: number;
  message: string;
  data: WordApiItem | null;
}

interface StudySubmitRequestBody {
  userId: number;
  bookTitle: string;
  wordId: number;
  word: string;
  meaning: string;
  isCorrect: boolean;
  selectedAnswer: string;
  correctAnswer: string;
  sentence: string;
  reason: string;
  practiceMode: string;
  rating: number;
}

interface NotebookWordAddRequestBody {
  userId: number;
  wordId: number;
  word: string;
  meaning: string;
  bookTitle: string;
  masteryLabel: string;
  nextReview: string;
  noteText: string;
}

interface UpdateBookRequestBody {
  userId: number;
  nickname: string;
  dailyTarget: number;
  signature: string;
  selectedBookId: number;
}

interface SimpleResultResponse {
  code: number;
  message: string;
  data: string | null;
}

interface EmptyRequestBody {
}

interface BooleanResultResponse {
  code: number;
  message: string;
  data: boolean | null;
}

interface CountItem {
  id: number;
}

interface CountListResponse {
  code: number;
  message: string;
  data: CountItem[] | null;
}

interface StudyRecordCountItem {
  id: number;
  studyDate: string;
}

interface StudyRecordCountResponse {
  code: number;
  message: string;
  data: StudyRecordCountItem[] | null;
}

function emptyBookCard(bookId: number): BookCard {
  return {
    id: bookId,
    title: '暂无词书',
    levelTag: '未选择',
    description: '请确认后端 books 表有数据，并且网络连接正常。',
    totalWords: 0,
    learnedWords: 0,
    todayNew: 0,
    todayReview: 0,
    streakDays: 0,
    progress: 0,
    accentColor: '#1E3A8A',
    softColor: '#EFF6FF'
  };
}

@Entry
@Component
struct MainPage {
  @State currentTabIndex: number = 0;
  @State selectedBookId: number = userProfile.selectedBookId;
  @State showPracticePage: boolean = false;
  @State practiceMode: string = 'learn';
  @State bookList: BookCard[] = [];
  @State notebookCount: number = 0;
  @State wrongCount: number = 0;
  @State studyRecordCount: number = 0;
  @State totalLearnedWords: number = userProfile.totalLearnedWords;

  aboutToAppear() {
    // MainPage 页面级生命周期必然触发,作为首屏 stats 权威加载点,
    // 不依赖子组件 onAppear 时序,也不做人为延迟
    ApiService.get('/api/stats/overview?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as StatsResponse;
          console.log('[MainPage.aboutToAppear] stats=' + result.substring(0, 200));
          if (response.code === 200 && response.data !== null) {
            this.totalLearnedWords = response.data.totalLearnedWords;
            this.streakDays = response.data.streakDays;
            this.accuracyRate = response.data.accuracyRate;
            this.reviewDue = response.data.reviewDue;
            this.todayFinishedWords = response.data.todayFinishedWords;
            this.todayCorrectRate = response.data.todayCorrectRate;
            const rl: number = response.data.remainingLearnWords as number;
            this.homeRemainingLearn = (rl !== null && rl !== undefined) ? rl : 0;
            console.log('[MainPage.aboutToAppear] todayFinished=' + this.todayFinishedWords
              + ' todayRate=' + this.todayCorrectRate + ' remain=' + this.homeRemainingLearn);
          }
        } catch (e) {
          console.error('[MainPage.aboutToAppear] parse failed: ' + (e as BusinessError<number>).message);
        }
      })
      .catch((e: BusinessError<number>) => {
        console.error('[MainPage.aboutToAppear] stats failed: ' + e.message);
      });
  }
  @State streakDays: number = userProfile.streakDays;
  @State accuracyRate: number = userProfile.accuracyRate;
  @State reviewDue: number = userProfile.reviewDue;
  // 今日概览:登录响应已携带初始值,首屏即正确显示;后续 stats 刷新实时更新
  @State todayFinishedWords: number = userProfile.todayFinishedWords;
  @State todayCorrectRate: number = userProfile.todayCorrectRate;
  // 首页未学词数:登录响应已携带初始值,后续 stats 刷新实时更新
  @State homeRemainingLearn: number = userProfile.remainingLearnWords;
  // 切回首页 tab 时自增，触发 StudyHomeTab 自动刷新
  @State homeRefreshTick: number = 0;

  loadMineCounts() {
    ApiService.get('/api/notebook-words?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as CountListResponse;
          if (response.code === 200 && response.data !== null) {
            this.notebookCount = response.data.length;
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('load notebook count parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('load notebook count failed: ' + error.message);
      });

    ApiService.get('/api/wrong-words?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as CountListResponse;
          if (response.code === 200 && response.data !== null) {
            this.wrongCount = response.data.length;
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('load wrong count parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('load wrong count failed: ' + error.message);
      });

    ApiService.get('/api/study-records?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as StudyRecordCountResponse;
          if (response.code === 200 && response.data !== null) {
            const studiedDays: string[] = [];
            for (let i = 0; i < response.data.length; i++) {
              const studyDate: string = response.data[i].studyDate;
              const dayText: string = studyDate.length >= 10 ? studyDate.slice(0, 10) : studyDate;
              if (studiedDays.indexOf(dayText) < 0) {
                studiedDays.push(dayText);
              }
            }
            this.studyRecordCount = studiedDays.length;
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('load study record count parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('load study record count failed: ' + error.message);
      });
  }

  build() {
    if (this.showPracticePage) {
      StudyPracticePage({
        selectedBookId: $selectedBookId,
        practiceMode: $practiceMode,
        showPracticePage: $showPracticePage,
        bookList: $bookList,
        totalLearnedWords: $totalLearnedWords,
        streakDays: $streakDays,
        accuracyRate: $accuracyRate,
        reviewDue: $reviewDue,
        todayFinishedWords: $todayFinishedWords,
        todayCorrectRate: $todayCorrectRate
      });

    } else {
      Tabs({ index: this.currentTabIndex }) {
        TabContent() {
          StudyHomeTab({
            currentTabIndex: $currentTabIndex,
            selectedBookId: $selectedBookId,
            practiceMode: $practiceMode,
            showPracticePage: $showPracticePage,
            bookList: $bookList,
            totalLearnedWords: $totalLearnedWords,
            streakDays: $streakDays,
            accuracyRate: $accuracyRate,
            reviewDue: $reviewDue,
            todayFinishedWords: $todayFinishedWords,
            todayCorrectRate: $todayCorrectRate,
            homeRemainingLearn: $homeRemainingLearn,
            homeRefreshTick: this.homeRefreshTick
          });

        }.tabBar(this.tabBarBuilder(0, '背词'))

        TabContent() {
          BookTab({
            currentTabIndex: $currentTabIndex,
            selectedBookId: $selectedBookId,
            bookList: $bookList,
            homeRefreshTick: $homeRefreshTick
          });

        }.tabBar(this.tabBarBuilder(1, '词书'))

        TabContent() {
          MineTab({
            selectedBookId: $selectedBookId,
            bookList: $bookList,
            notebookCount: $notebookCount,
            wrongCount: $wrongCount,
            studyRecordCount: $studyRecordCount
          });

        }.tabBar(this.tabBarBuilder(2, '我的'))
      }
      .barPosition(BarPosition.End)
      .backgroundColor('#F8FAFC')
      .onChange((index: number) => {
        this.currentTabIndex = index;
        if (index === 0) {
          // 切回首页时自动刷新一次，保证 Learn/Review 数字实时
          this.homeRefreshTick++;
        }
        if (index === 2) {
          this.loadMineCounts();
        }
      })

      .onAppear(() => {
        this.loadMineCounts();
      })


    }
  }

  @Builder
  tabBarBuilder(index: number, title: string) {
    Column({ space: 4 }) {
      Text(this.currentTabIndex === index ? '●' : '○')
        .fontSize(8)
        .fontColor(this.currentTabIndex === index ? '#1E3A8A' : '#94A3B8')
      Text(title)
        .fontSize(12)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.currentTabIndex === index ? '#0F172A' : '#64748B')
    }
    .padding({ top: 8, bottom: 8 })
    .width('100%')
  }
}

@Component
struct StudyHomeTab {
  @Link currentTabIndex: number;
  @Link selectedBookId: number;
  @Link practiceMode: string;
  @Link showPracticePage: boolean;
  @Link bookList: BookCard[];
  @Link totalLearnedWords: number;
  @Link streakDays: number;
  @Link accuracyRate: number;
  @Link reviewDue: number;
  @Link todayFinishedWords: number;
  @Link todayCorrectRate: number;
  @Link homeRemainingLearn: number;
  // 父组件自增触发自动刷新（切回首页 tab）
  @Prop @Watch('onHomeRefreshTick') homeRefreshTick: number = 0;
  // 下拉刷新状态：$$ 双向绑定仅支持组件自身 @State
  @State isRefreshing: boolean = false;
  private refreshInFlight: boolean = false;
  @State signedIn: boolean = false;

  onHomeRefreshTick() {
    this.refreshHomeData();
  }

  currentBook(): BookCard {
    for (let i = 0; i < this.bookList.length; i++) {
      if (this.bookList[i].id === this.selectedBookId) {
        return this.bookList[i];
      }
    }
    return this.bookList.length > 0 ? this.bookList[0] : emptyBookCard(this.selectedBookId);
  }

  dateText(): string {
    const date: Date = new Date();
    const weekdays: string[] = ['Sun.', 'Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.'];
    const month: string = date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : (date.getMonth() + 1).toString();
    const day: string = date.getDate() < 10 ? '0' + date.getDate() : date.getDate().toString();
    return month + '/' + day + ' ' + weekdays[date.getDay()];
  }

  openBooks() {
    this.currentTabIndex = 1;
  }

  openPractice(mode: string) {
    this.practiceMode = mode;
    this.showPracticePage = true;
  }

  /**
   * 首页统一刷新链路：下拉刷新、进入主页/登录完成、从练习页返回、切回 tab
   * 都走这里，保证 Learn/Review 数字与后端实时数据一致。
   */
  refreshHomeData() {
    if (this.refreshInFlight) {
      return;
    }
    this.refreshInFlight = true;

    const tasks: Promise<void>[] = [
      this.fetchProfile(),
      this.fetchStats(),
      this.fetchBookProgress(),
      this.fetchSignStatus()
    ];

    Promise.all(tasks)
      .then(() => {
        this.refreshInFlight = false;
        this.isRefreshing = false;
      })
      .catch(() => {
        this.refreshInFlight = false;
        this.isRefreshing = false;
      });
  }

  fetchProfile(): Promise<void> {
    return ApiService.get('/api/user/profile?userId=' + currentUser.id)
      .then((result: string) => {
        const response = JSON.parse(result) as ProfileResponse;

        if (response.code === 200 && response.data !== null) {
          userProfile.nickname = response.data.nickname;
          userProfile.dailyTarget = response.data.dailyTarget;
          userProfile.signature = response.data.signature;
          userProfile.selectedBookId = response.data.selectedBookId;
          userProfile.totalLearnedWords = response.data.totalLearnedWords;
          userProfile.streakDays = response.data.streakDays;
          userProfile.accuracyRate = response.data.accuracyRate;
          this.totalLearnedWords = response.data.totalLearnedWords;
          this.streakDays = response.data.streakDays;
          this.accuracyRate = response.data.accuracyRate;
          this.selectedBookId = response.data.selectedBookId;
        }
      })
      .catch((error: BusinessError<number>) => {
        showToast(this.getUIContext(), '用户资料加载失败');
        console.error('load profile failed: ' + error.message);
      });
  }

  fetchStats(): Promise<void> {
    return ApiService.get('/api/stats/overview?userId=' + currentUser.id)
      .then((result: string) => {
        const response = JSON.parse(result) as StatsResponse;
        console.log('[fetchStats] raw:', result);

        if (response.code === 200 && response.data !== null) {
          userProfile.totalLearnedWords = response.data.totalLearnedWords;
          userProfile.streakDays = response.data.streakDays;
          userProfile.accuracyRate = response.data.accuracyRate;
          userProfile.reviewDue = response.data.reviewDue;
          this.totalLearnedWords = response.data.totalLearnedWords;
          this.streakDays = response.data.streakDays;
          this.accuracyRate = response.data.accuracyRate;
          this.reviewDue = response.data.reviewDue;
          this.todayFinishedWords = response.data.todayFinishedWords;
          this.todayCorrectRate = response.data.todayCorrectRate;
          // 直接赋值,不再做 typeof 守卫(JSON.parse 后永远是 number 或 null/undefined)
          const rl: number = response.data.remainingLearnWords as number;
          this.homeRemainingLearn = (rl !== null && rl !== undefined) ? rl : 0;
          console.log('[fetchStats] homeRemainingLearn=', this.homeRemainingLearn);
        }
      })
      .catch((error: BusinessError<number>) => {
        showToast(this.getUIContext(), '统计数据加载失败');
        console.error('load stats failed: ' + error.message);
      });
  }

  fetchBookProgress(): Promise<void> {
    return ApiService.get('/api/books/progress?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as BookProgressResponse;

          if (response.code !== 200 || response.data === null) {
            return;
          }

          const mappedBooks: BookCard[] = response.data.map((item: BookProgressItem): BookCard => {
            return {
              id: item.id,
              title: item.title,
              levelTag: item.levelTag,
              description: item.description,
              totalWords: item.totalWords,
              learnedWords: item.learnedWords,
              todayNew: item.todayNew,
              todayReview: item.todayReview,
              streakDays: userProfile.streakDays,
              progress: item.progress,
              accentColor: item.accentColor,
              softColor: item.softColor
            };
          });

          this.bookList = mappedBooks;

          const exists: boolean = mappedBooks.some((item: BookCard) => item.id === this.selectedBookId);
          if (!exists && mappedBooks.length > 0) {
            this.selectedBookId = mappedBooks[0].id;
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          showToast(this.getUIContext(), '词书数据解析失败');
          console.error('load book progress parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        showToast(this.getUIContext(), '词书数据加载失败');
        console.error('load book progress failed: ' + error.message);
      });
  }

  fetchSignStatus(): Promise<void> {
    return ApiService.get('/api/sign/status?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as BooleanResultResponse;
          if (response.code === 200 && response.data !== null) {
            this.signedIn = response.data;
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('load sign status parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('load sign status failed: ' + error.message);
      });
  }

  signToday() {
    if (this.signedIn) {
      showToast(this.getUIContext(), '今天已经签到');
      return;
    }

    const requestBody: EmptyRequestBody = {};
    ApiService.post('/api/sign?userId=' + currentUser.id, requestBody)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as SimpleResultResponse;
          if (response.code !== 200) {
            showToast(this.getUIContext(), response.message);
            return;
          }

          this.signedIn = true;
          showToast(this.getUIContext(), '签到成功');
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('sign parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        showToast(this.getUIContext(), '签到失败');
        console.error('sign failed: ' + error.message);
      });
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column({ space: 14 }) {
        Stack() {

          Column()
            .width('100%')
            .height(508)
            .backgroundColor('#EFF6FF')
            .borderRadius(24)

          Column({ space: 14 }) {
            Column()
              .height(10)

            Column({ space: 8 }) {
              if (this.signedIn) {
                Text('✓')
                  .fontSize(34)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1E3A8A')
              } else {
                this.calendarIcon()
              }
              Text(this.dateText())
                .fontSize(17)
                .fontColor('#0F172A')
            }
            .width(182)
            .padding({ top: 28, bottom: 28 })
            .backgroundColor('#FFFFFF')
            .borderRadius(24)
            .border({ width: 0.5, color: '#E5E7EB' })
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.signToday();
            })

            Blank()

            Row({ space: 14 }) {
              this.focusCard('Learn', this.homeRemainingLearn.toString(), 'learn')
              this.focusCard('Review', this.reviewDue.toString(), 'review')
            }
            .width('100%')

            Button('打开词书列表')
              .width('100%')
              .height(46)
              .type(ButtonType.Normal)
              .backgroundColor('#1E3A8A')
              .fontColor(Color.White)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .borderRadius(12)
              .onClick(() => {
                this.openBooks();
              })
          }
          .width('100%')
          .height('100%')
          .padding({ left: 18, right: 18, top: 14, bottom: 18 })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height(508)

        Column({ space: 12 }) {
          Text('今日学习概览')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .width('100%')

          Row({ space: 12 }) {
            this.metricCard('今日已学', this.todayFinishedWords.toString())
            this.metricCard('今日正确率', this.todayCorrectRate.toString() + '%')
            this.metricCard('累计已学', this.totalLearnedWords.toString())
          }
          .width('100%')
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 20 })
    }
    }
    .backgroundColor('#F8FAFC')
    .onRefreshing(() => {
      this.refreshHomeData();
    })
    .onAppear(() => {
      this.refreshHomeData();
    })
  }

  @Builder
  calendarIcon() {
    Stack() {
      Column() {
        Row()
          .height(8)

        Row({ space: 6 }) {
          Column()
            .width(9)
            .height(2)
            .backgroundColor('#1E3A8A')
            .borderRadius(1)
          Column()
            .width(9)
            .height(2)
            .backgroundColor('#1E3A8A')
            .borderRadius(1)
        }
        .height(8)
        .justifyContent(FlexAlign.Center)

        Column()
          .width(14)
          .height(2)
          .backgroundColor('#1E3A8A')
          .borderRadius(1)
      }
      .width(38)
      .height(36)
      .padding({ top: 7, bottom: 7 })
      .border({ width: 3, color: '#1E3A8A' })
      .borderRadius(6)
      .alignItems(HorizontalAlign.Center)

      Row({ space: 14 }) {
        Column()
          .width(3)
          .height(9)
          .backgroundColor('#1E3A8A')
          .borderRadius(2)
        Column()
          .width(3)
          .height(9)
          .backgroundColor('#1E3A8A')
          .borderRadius(2)
      }
      .align(Alignment.Top)
      .offset({ y: -4 })
    }
    .width(46)
    .height(42)
  }

  @Builder
  focusCard(title: string, value: string, mode: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E3A8A')
    }
    .layoutWeight(1)
    .height(108)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({ width: 0.5, color: '#E5E7EB' })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.openPractice(mode);
    })
  }

  @Builder
  metricCard(title: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E3A8A')
      Text(title)
        .fontSize(11)
        .fontColor('#64748B')
    }
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 0.5, color: '#E5E7EB' })
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
struct StudyPracticePage {
  @Link selectedBookId: number;
  @Link practiceMode: string;
  @Link showPracticePage: boolean;
  @Link bookList: BookCard[];
  @Link totalLearnedWords: number;
  @Link streakDays: number;
  @Link accuracyRate: number;
  @Link reviewDue: number;
  @Link todayFinishedWords: number;
  @Link todayCorrectRate: number;

  @State currentIndex: number = 0;
  @State selectedOption: string = '';
  /** FSRS 四级评分:1=忘了(again) 2=模糊(hard) 3=记得(good) 4=超熟(easy);选完答案后必须评分才提交 */
  @State selectedRating: number = 0;
  @State wordBank: LearningWord[] = [];
  @State currentQuestion: LearningWord | null = null;
  @State loading: boolean = false;
  /** 当前题是否已成功提交计分（未成功时主按钮可重试提交） */
  @State answerSubmitted: boolean = false;
  /** 提交失败状态：网络异常或后端报错，主按钮显示"重试" */
  @State submitFailed: boolean = false;
  private submitInFlight: boolean = false;
  /** 主按钮文字,用 @State 显式管理,避免在 @Builder 里调方法导致的文字不刷新 */
  @State primaryLabel: string = '下一题';

  /** 根据当前题号与本轮总题数刷新按钮文字 */
  syncPrimaryLabel(): void {
    const total: number = this.wordBank.length;
    this.primaryLabel = (total > 0 && this.currentIndex >= total - 1) ? '完成本轮' : '下一题';
  }

  currentBook(): BookCard {
    for (let i = 0; i < this.bookList.length; i++) {
      if (this.bookList[i].id === this.selectedBookId) {
        return this.bookList[i];
      }
    }
    return this.bookList.length > 0 ? this.bookList[0] : emptyBookCard(this.selectedBookId);
  }

  refreshStatsAfterSubmit() {
    ApiService.get('/api/stats/overview?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as StatsResponse;
          if (response.code === 200 && response.data !== null) {
            userProfile.totalLearnedWords = response.data.totalLearnedWords;
            userProfile.streakDays = response.data.streakDays;
            userProfile.accuracyRate = response.data.accuracyRate;
            userProfile.reviewDue = response.data.reviewDue;
            this.totalLearnedWords = response.data.totalLearnedWords;
            this.streakDays = response.data.streakDays;
            this.accuracyRate = response.data.accuracyRate;
            this.reviewDue = response.data.reviewDue;
            this.todayFinishedWords = response.data.todayFinishedWords;
            this.todayCorrectRate = response.data.todayCorrectRate;
            // homeRemainingLearn 在 MainPage 持有,这里不能直接赋值;
            // 退出练习回到主页后 StudyHomeTab 的 onHomeRefreshTick 会重新拉
          }
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('refresh stats parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('refresh stats failed: ' + error.message);
      });
  }

  refreshBookProgressAfterSubmit() {
    ApiService.get('/api/books/progress?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as BookProgressResponse;
          if (response.code !== 200 || response.data === null) {
            return;
          }

          this.bookList = response.data.map((item: BookProgressItem): BookCard => {
            return {
              id: item.id,
              title: item.title,
              levelTag: item.levelTag,
              description: item.description,
              totalWords: item.totalWords,
              learnedWords: item.learnedWords,
              todayNew: item.todayNew,
              todayReview: item.todayReview,
              streakDays: this.streakDays,
              progress: item.progress,
              accentColor: item.accentColor,
              softColor: item.softColor
            };
          });
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('refresh book progress parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        console.error('refresh book progress failed: ' + error.message);
      });
  }

  currentQueue(): LearningWord[] {
    return this.wordBank;
  }

  buildPracticeGroup(allWords: LearningWord[]): LearningWord[] {
    const groupSize: number = 10;
    if (allWords.length <= groupSize) {
      return allWords;
    }

    const startIndex: number = this.currentBook().learnedWords % allWords.length;
    const group: LearningWord[] = [];
    for (let i = 0; i < groupSize; i++) {
      const index: number = (startIndex + i) % allWords.length;
      group.push(allWords[index]);
    }
    return group;
  }

  emptyWord(): LearningWord {
    const isReview: boolean = this.practiceMode === 'review';
    return {
      id: 0,
      bookId: this.selectedBookId,
      bookTitle: this.currentBook().title,
      word: '',
      phonetic: '',
      meaning: isReview ? '暂无到期复习词' : '暂无可学习单词',
      memoryTip: isReview
        ? '今天的复习任务已完成，已学单词会按记忆曲线在到期后自动出现在这里。'
        : '请先确认后端 words 表里有当前词书的单词数据，且后端服务已启动。',
      example: '',
      translation: '',
      answer: '',
      options: [],
      difficulty: ''
    };
  }

  currentWord(): LearningWord {
    if (this.currentQuestion !== null) {
      return this.currentQuestion;
    }

    const queue: LearningWord[] = this.currentQueue();
    if (queue.length === 0) {
      return this.emptyWord();
    }

    const safeIndex: number = this.currentIndex >= queue.length ? Math.max(queue.length - 1, 0) : this.currentIndex;
    return queue[safeIndex];
  }

  shuffleOptions(options: string[]): string[] {
    const copied: string[] = [];
    for (let i = 0; i < options.length; i++) {
      copied.push(options[i]);
    }

    for (let i = copied.length - 1; i > 0; i--) {
      const randomIndex: number = Math.floor(Math.random() * (i + 1));
      const temp: string = copied[i];
      copied[i] = copied[randomIndex];
      copied[randomIndex] = temp;
    }

    return copied;
  }

  buildOptions(correctAnswer: string, sourceWords: LearningWord[]): string[] {
    const collected: string[] = [correctAnswer];

    for (let i = 0; i < sourceWords.length; i++) {
      const option: string = sourceWords[i].meaning;
      if (option !== correctAnswer && collected.indexOf(option) < 0) {
        collected.push(option);
      }
      if (collected.length >= 4) {
        break;
      }
    }

    return this.shuffleOptions(collected);
  }

  attachOptions(item: LearningWord, sourceWords: LearningWord[]): LearningWord {
    return {
      id: item.id,
      bookId: item.bookId,
      bookTitle: item.bookTitle,
      word: item.word,
      phonetic: item.phonetic,
      meaning: item.meaning,
      memoryTip: item.memoryTip,
      example: item.example,
      translation: item.translation,
      answer: item.answer,
      options: this.buildOptions(item.answer, sourceWords),
      difficulty: item.difficulty
    };
  }

  mapWordItem(item: WordApiItem): LearningWord {
    return {
      id: item.id,
      bookId: item.bookId,
      bookTitle: this.currentBook().title,
      word: item.word,
      phonetic: item.phonetic,
      meaning: item.meaning,
      memoryTip: item.memoryTip,
      example: item.exampleText,
      translation: item.translationText,
      answer: item.answer,
      options: [],
      difficulty: item.difficulty
    };
  }

  applyWordQueue(groupWords: LearningWord[], optionPool: LearningWord[]) {
    const wordsWithOptions: LearningWord[] =
      groupWords.map((item: LearningWord): LearningWord => this.attachOptions(item, optionPool));

    this.wordBank = wordsWithOptions;
    this.currentIndex = 0;
    this.currentQuestion = wordsWithOptions.length > 0 ? wordsWithOptions[0] : null;
    this.selectedOption = '';
    this.selectedRating = 0;
    this.submitFailed = false;
    this.loading = false;
    this.syncPrimaryLabel();
  }

  loadWordBank() {
    this.loading = true;

    // learn 拉取未学词池，review 拉取 FSRS 加权的到期复习池
    const requestUrl: string = this.practiceMode === 'review'
      ? '/api/study/review-list?userId=' + currentUser.id + '&bookId=' + this.selectedBookId + '&limit=20'
      : '/api/words/unlearned?userId=' + currentUser.id + '&bookId=' + this.selectedBookId + '&limit=50';

    ApiService.get(requestUrl)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as WordListResponse;

          if (response.code !== 200 || response.data === null) {
            this.loading = false;
            showToast(this.getUIContext(), response.message);
            return;
          }

          const mapped: LearningWord[] = response.data.map((item: WordApiItem): LearningWord => this.mapWordItem(item));

          if (this.practiceMode === 'review') {
            // review 列表已按遗忘概率排序，整列直接用
            if (mapped.length === 0) {
              this.applyWordQueue([], []);
              return;
            }
            // 到期词可能不足 4 个，从全书随机词补充干扰项来源
            ApiService.get('/api/words/options?bookId=' + this.selectedBookId + '&limit=60')
              .then((optionResult: string) => {
                try {
                  const optionResponse = JSON.parse(optionResult) as WordListResponse;
                  const pool: LearningWord[] = mapped.slice();
                  if (optionResponse.code === 200 && optionResponse.data !== null) {
                    for (let i = 0; i < optionResponse.data.length; i++) {
                      const candidate: LearningWord = this.mapWordItem(optionResponse.data[i]);
                      let duplicated: boolean = false;
                      for (let j = 0; j < pool.length; j++) {
                        if (pool[j].id === candidate.id) {
                          duplicated = true;
                          break;
                        }
                      }
                      if (!duplicated) {
                        pool.push(candidate);
                      }
                    }
                  }
                  this.applyWordQueue(mapped, pool);
                } catch (error) {
                  const err = error as BusinessError<number>;
                  // 干扰项拉取失败时降级，用复习词自身作为选项来源
                  this.applyWordQueue(mapped, mapped);
                  console.error('load option pool parse failed: ' + err.message);
                }
              })
              .catch((error: BusinessError<number>) => {
                this.applyWordQueue(mapped, mapped);
                console.error('load option pool failed: ' + error.message);
              });
            return;
          }

          // learn 取 10 词一组，50 个未学词作为选项池
          this.applyWordQueue(this.buildPracticeGroup(mapped), mapped);
        } catch (error) {
          const err = error as BusinessError<number>;
          this.loading = false;
          showToast(this.getUIContext(), '单词列表解析失败');
          console.error('load word bank parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        this.loading = false;
        showToast(this.getUIContext(), '单词列表加载失败');
        console.error('load word bank failed: ' + error.message);
      });
  }

  loadNextWord() {
    const queue: LearningWord[] = this.currentQueue();
    if (queue.length === 0) {
      this.currentQuestion = null;
      this.selectedOption = '';
      this.selectedRating = 0;
      this.answerSubmitted = false;
      this.submitFailed = false;
      this.syncPrimaryLabel();
      return;
    }

    const safeIndex: number = this.currentIndex >= queue.length ? queue.length - 1 : this.currentIndex;
    this.currentQuestion = queue[safeIndex];
    this.selectedOption = '';
    this.selectedRating = 0;
    this.answerSubmitted = false;
    this.submitFailed = false;
    this.syncPrimaryLabel();
  }

  tomorrowText(): string {
    const date: Date = new Date();
    date.setDate(date.getDate() + 1);

    const year: string = date.getFullYear().toString();
    const month: string = date.getMonth() + 1 < 10 ? '0' + (date.getMonth() + 1) : (date.getMonth() + 1).toString();
    const day: string = date.getDate() < 10 ? '0' + date.getDate() : date.getDate().toString();
    return year + '-' + month + '-' + day;
  }

  addToNotebook() {
    const word: LearningWord = this.currentWord();
    if (word.id <= 0) {
      showToast(this.getUIContext(), '暂无可加入的单词');
      return;
    }

    const requestBody: NotebookWordAddRequestBody = {
      userId: currentUser.id,
      wordId: word.id,
      word: word.word,
      meaning: word.meaning,
      bookTitle: this.currentBook().title,
      masteryLabel: '待复习',
      nextReview: this.tomorrowText(),
      noteText: word.memoryTip
    };

    ApiService.post('/api/notebook-words', requestBody)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as SimpleResultResponse;
          if (response.code !== 200) {
            showToast(this.getUIContext(), response.message);
            return;
          }

          showToast(this.getUIContext(), response.data === 'notebook word already exists' ? '生词本已存在' : '已加入生词本');
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('add notebook parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        showToast(this.getUIContext(), '加入生词本失败');
        console.error('add notebook failed: ' + error.message);
      });
  }

  modeTitle(): string {
    return this.practiceMode === 'review' ? '复习模式' : '背词练习';
  }

  progressText(): string {
    const total: number = this.currentQueue().length;
    const current: number = total > 0 ? this.currentIndex + 1 : 0;
    return current.toString() + '/' + total.toString();
  }


  optionBackground(option: string): string {
    if (this.selectedOption.length === 0) {
      return '#FFFFFF';
    }
    if (option === this.currentWord().answer) {
      return '#DBEAFE';
    }
    if (option === this.selectedOption) {
      return '#FEE2E2';
    }
    return '#FFFFFF';
  }

  optionBorder(option: string): string {
    if (this.selectedOption.length === 0) {
      return '#E5E7EB';
    }
    if (option === this.currentWord().answer) {
      return '#1E3A8A';
    }
    if (option === this.selectedOption) {
      return '#DC2626';
    }
    return '#E5E7EB';
  }

  chooseOption(option: string) {
    if (this.selectedOption.length > 0 || this.submitInFlight) {
      return;
    }
    this.selectedOption = option;
    this.selectedRating = 0;
    this.submitFailed = false;
    // 重选后按钮恢复"下一题/完成本轮"
    this.syncPrimaryLabel();
    // 选完答案后显示解析与 FSRS 四级评分,用户评分后才提交计分
  }

  submitAnswer() {
    if (this.currentWord().id <= 0) {
      showToast(this.getUIContext(), '暂无可提交的单词');
      return;
    }

    if (this.selectedOption.length === 0) {
      showToast(this.getUIContext(), '请先选择答案');
      return;
    }

    if (this.submitInFlight || this.answerSubmitted) {
      return;
    }
    this.submitInFlight = true;

    const word: LearningWord = this.currentWord();
    const isCorrect: boolean = this.selectedOption === word.answer;

    const requestBody: StudySubmitRequestBody = {
      userId: currentUser.id,
      bookTitle: this.currentBook().title,
      wordId: word.id,
      word: word.word,
      meaning: word.meaning,
      isCorrect: isCorrect,
      selectedAnswer: this.selectedOption,
      correctAnswer: word.answer,
      sentence: word.example,
      reason: isCorrect ? '' : '选择了错误释义',
      practiceMode: this.practiceMode,
      rating: this.selectedRating
    };

    ApiService.post('/api/study/submit', requestBody)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as SimpleResultResponse;

          if (response.code !== 200) {
            this.submitInFlight = false;
            this.submitFailed = true;
            this.primaryLabel = '重新提交';
            showToast(this.getUIContext(), response.message);
            return;
          }

          this.submitInFlight = false;
          this.submitFailed = false;
          this.answerSubmitted = true;
          this.syncPrimaryLabel();
          this.refreshStatsAfterSubmit();
          this.refreshBookProgressAfterSubmit();
        } catch (error) {
          const err = error as BusinessError<number>;
          this.submitInFlight = false;
          this.submitFailed = true;
          this.primaryLabel = '重新提交';
          console.error('submit study parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        this.submitInFlight = false;
        this.submitFailed = true;
        this.primaryLabel = '重新提交';
        showToast(this.getUIContext(), '学习提交失败，可点按钮重试');
        console.error('submit study failed: ' + error.message);
      });
  }

  /** 手动进入下一题：最后一题时结束本轮 */
  goToNext() {
    if (this.submitInFlight) {
      showToast(this.getUIContext(), '正在提交，请稍候');
      return;
    }
    if (!this.answerSubmitted) {
      return;
    }

    if (this.currentIndex < this.currentQueue().length - 1) {
      this.currentIndex += 1;
      this.loadNextWord();
      return;
    }

    showToast(this.getUIContext(), '本轮练习完成');
    this.exitPractice();
  }

  primaryButtonLabel(): string {
    // 直接返回 @State,由 syncPrimaryLabel/提交失败处显式维护
    return this.primaryLabel;
  }

  /** 按钮是否处于激活态（选中即可点击、主色高亮） */
  primaryButtonActive(): boolean {
    return this.selectedOption.length > 0;
  }

  onPrimaryButton() {
    if (this.submitInFlight) {
      showToast(this.getUIContext(), '正在提交,请稍候…');
      return;
    }
    if (this.selectedOption.length === 0) {
      showToast(this.getUIContext(), '请先选择答案');
      return;
    }
    if (!this.answerSubmitted) {
      this.submitAnswer();
      return;
    }
    this.goToNext();
  }


  exitPractice() {
    this.currentIndex = 0;
    this.selectedOption = '';
    this.selectedRating = 0;
    this.answerSubmitted = false;
    this.submitFailed = false;
    this.submitInFlight = false;
    this.currentQuestion = null;
    this.wordBank = [];
    this.loading = false;
    this.showPracticePage = false;
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Row() {
          Text('返回')
            .fontSize(14)
            .fontColor('#1E3A8A')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .border({ width: 1, color: '#1E3A8A' })
            .onClick(() => {
              this.exitPractice();
            })

          Blank()

          Text(this.modeTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Blank()

          Text(this.progressText())
            .fontSize(13)
            .fontColor('#64748B')
        }
        .width('100%')

        Column({ space: 8 }) {
          Text(this.currentWord().word)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E3A8A')
            .width('100%')

          Text(this.currentWord().phonetic)
            .fontSize(14)
            .fontColor('#94A3B8')
            .width('100%')

          Divider()
            .color('#F1F5F9')
            .strokeWidth(0.5)

          Text(this.currentWord().example)
            .fontSize(12)
            .lineHeight(18)
            .fontColor('#334155')
            .width('100%')

          if (this.selectedOption.length === 0) {
            Text('先根据单词和例句选择正确释义。学习模式选完即提交计分，复习模式可再选择记忆程度（可选）。')
              .fontSize(12)
              .lineHeight(17)
              .fontColor('#64748B')
              .width('100%')
          } else {
            Text('正确释义：' + this.currentWord().answer)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F172A')
              .width('100%')

            Text(this.currentWord().memoryTip)
              .fontSize(12)
              .lineHeight(17)
              .fontColor('#64748B')
              .width('100%')

            Text(this.currentWord().translation)
              .fontSize(12)
              .lineHeight(17)
              .fontColor('#64748B')
              .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 0.5, color: '#E5E7EB' })
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('选择正确释义')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .width('100%')

          ForEach(this.currentWord().options, (option: string) => {
            this.optionRow(option);
          }, (option: string) => option)
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 0.5, color: '#E5E7EB' })

        if (this.practiceMode === 'review' && this.selectedOption.length > 0 && !this.answerSubmitted) {
          Column({ space: 8 }) {
            Row() {
              Text('这次记得怎么样？')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
              Blank()
              Text('FSRS 记忆算法会根据评分安排下次复习')
                .fontSize(10)
                .fontColor('#94A3B8')
            }
            .width('100%')

            Row({ space: 8 }) {
              this.ratingRow(1, '忘了')
              this.ratingRow(2, '模糊')
              this.ratingRow(3, '记得')
              this.ratingRow(4, '超熟')
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({ width: 0.5, color: '#E5E7EB' })
        }

        Row({ space: 10 }) {
          this.actionButton('加入生词本', '#FFFFFF', '#1E3A8A', () => {
            this.addToNotebook();
          })
          this.actionButton('退出练习', '#FFFFFF', '#1E3A8A', () => {
            this.exitPractice();
          })
          this.actionButton(
            this.primaryButtonLabel(),
            '#1E3A8A',
            '#FFFFFF',
            () => {
              this.onPrimaryButton();
            }
          )
        }

        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
    }
    .backgroundColor('#F8FAFC')
    .onAppear(() => {
      this.currentIndex = 0;
      this.selectedOption = '';
      this.selectedRating = 0;
      this.answerSubmitted = false;
      this.submitFailed = false;
      this.currentQuestion = null;
      this.wordBank = [];
      this.loadWordBank();
    })

  }

  /** FSRS 四级评分按钮:1=忘了 2=模糊 3=记得 4=超熟 */
  @Builder
  ratingRow(rating: number, label: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedRating === rating ? '#FFFFFF' : '#1E3A8A')
      Text(rating.toString())
        .fontSize(10)
        .fontColor(this.selectedRating === rating ? '#DBEAFE' : '#94A3B8')
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(this.selectedRating === rating ? '#1E3A8A' : '#FFFFFF')
    .borderRadius(10)
    .border({ width: 1, color: this.selectedRating === rating ? '#1E3A8A' : '#E5E7EB' })
    .onClick(() => {
      this.selectRating(rating);
    })
  }

  /** 选中评分后立即提交计分 */
  selectRating(rating: number) {
    if (this.selectedOption.length === 0 || this.answerSubmitted || this.submitInFlight) {
      return;
    }
    this.selectedRating = rating;
    this.submitAnswer();
  }

  @Builder
  optionRow(option: string) {
    Row({ space: 12 }) {
      Text(option)
        .fontSize(13)
        .lineHeight(20)
        .fontColor('#0F172A')
        .layoutWeight(1)

      if (this.selectedOption.length > 0 && option === this.currentWord().answer) {
        Text('正确')
          .fontSize(11)
          .fontColor('#1E3A8A')
      } else if (option === this.selectedOption && option !== this.currentWord().answer) {
        Text('再记')
          .fontSize(11)
          .fontColor('#DC2626')
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.optionBackground(option))
    .borderRadius(12)
    .border({
      width: 1,
      color: this.optionBorder(option)
    })
    .onClick(() => {
      this.chooseOption(option);
    })
  }

  @Builder
  actionButton(label: string, backgroundColor: string, fontColor: string, handler: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(42)
      .type(ButtonType.Normal)
      .backgroundColor(backgroundColor)
      .fontColor(fontColor)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .borderRadius(12)
      .border({
        width: 1,
        color: backgroundColor === '#FFFFFF' ? fontColor : '#00000000'
      })
      .onClick(() => {
        handler();
      })
  }

}

@Component
struct BookTab {
  @Link currentTabIndex: number;
  @Link selectedBookId: number;
  @Link bookList: BookCard[];
  @Link homeRefreshTick: number;

  isCurrentBook(bookId: number): boolean {
    return this.selectedBookId === bookId;
  }

  /** 点击"查看单词":进入该词书的完整单词列表 */
  openBookWords(item: BookCard) {
    const params: BookWordsRouteParams = { bookId: item.id, bookTitle: item.title };
    pushUrl(this.getUIContext(), 'pages/BookWordsPage', params);
  }

  switchBook(bookId: number) {
    if (this.selectedBookId === bookId) {
      return;
    }
    const previousBookId: number = this.selectedBookId;
    // 乐观更新：先切 UI，再持久化；失败必须回滚，否则主页统计（按后端词书）与练习页（按前端词书）会不一致
    this.selectedBookId = bookId;

    const requestBody: UpdateBookRequestBody = {
      userId: currentUser.id,
      nickname: userProfile.nickname,
      dailyTarget: userProfile.dailyTarget,
      signature: userProfile.signature,
      selectedBookId: bookId
    };

    ApiService.put('/api/user/profile', requestBody)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as ProfileResponse;
          if (response.code !== 200 || response.data === null) {
            this.selectedBookId = previousBookId;
            showToast(this.getUIContext(), response.message);
            return;
          }
          // 持久化成功：同步全局缓存，主页 Review/Learn 数字下次刷新即按新词书统计
          userProfile.selectedBookId = bookId;
          this.homeRefreshTick++;
          showToast(this.getUIContext(), '已切换词书');
        } catch (error) {
          const err = error as BusinessError<number>;
          this.selectedBookId = previousBookId;
          showToast(this.getUIContext(), '切换词书失败');
          console.error('switch book parse failed: ' + err.message);
        }
      })
      .catch((error: BusinessError<number>) => {
        this.selectedBookId = previousBookId;
        showToast(this.getUIContext(), '切换词书失败，请确认后端已启动');
        console.error('switch book failed: ' + error.message);
      });
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 12 }) {
          Swiper() {
            this.motivationSlide('别等状态来了再开始，开始之后状态才会来。', '今天也向前一点点。', '#1E3A8A')
            this.motivationSlide('你背下的每一个词，都会在未来替你说话。', '把重复变成底气。', '#1E3A8A')
            this.motivationSlide('真正拉开差距的，不是天赋，是稳定重复。', '继续保持今天的节奏。', '#1E3A8A')
          }
          .autoPlay(true)
          .interval(3200)
          .loop(true)
          .indicator(Indicator.dot()
            .color('#E5E7EB')
            .selectedColor('#1E3A8A'))
          .height(160)
        }
        .width('100%')

        Column({ space: 12 }) {
          if (this.bookList.length === 0) {
            this.emptyBooks()
          } else {
            ForEach(this.bookList, (item: BookCard) => {
              this.bookCard(item);
            }, (item: BookCard) => item.id.toString())
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .backgroundColor('#F8FAFC')
  }

  @Builder
  emptyBooks() {
    Column({ space: 10 }) {
      Text('词书加载中')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')

      Text('如果一直没有词书，请确认后端服务已启动，并且 /api/books/progress 能返回数据。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor('#64748B')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({ width: 0.5, color: '#E5E7EB' })
  }

  @Builder
  motivationSlide(title: string, subtitle: string, tintColor: string) {
    Stack() {
      Image($r('app.media.1'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(tintColor + 'CC')

      Column({ space: 8 }) {
        Text(title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .lineHeight(28)
          .width('100%')

        Text(subtitle)
          .fontSize(13)
          .fontColor('#DBEAFE')
          .width('100%')
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  smallMetric(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E3A8A')
      Text(label)
        .fontSize(11)
        .fontColor('#64748B')
    }
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 0.5, color: '#E5E7EB' })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  bookTag(item: BookCard) {
    Text(item.levelTag)
      .fontSize(11)
      .fontColor('#1E3A8A')
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor('#DBEAFE')
      .borderRadius(6)
  }

  @Builder
  bookCard(item: BookCard) {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .width('100%')

        Row() {
          this.bookTag(item)
          Blank()
        }
        .width('100%')

        Text(item.description)
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#64748B')
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        this.smallMetric('总词数', item.totalWords.toString())
        this.smallMetric('已学', item.learnedWords.toString())
        this.smallMetric('待复习', item.todayReview.toString())
      }
      .width('100%')

      Progress({ value: item.progress, total: 100, type: ProgressType.Linear })
        .color('#1E3A8A')
        .backgroundColor('#EFF6FF')
        .height(6)
        .borderRadius(3)

      Row({ space: 10 }) {
        Button('查看单词')
          .layoutWeight(1)
          .height(40)
          .type(ButtonType.Normal)
          .backgroundColor('#FFFFFF')
          .fontColor('#1E3A8A')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .borderRadius(10)
          .border({ width: 1, color: '#1E3A8A' })
          .onClick(() => {
            this.openBookWords(item);
          })

        Button(this.isCurrentBook(item.id) ? '当前词书' : '设为当前')
          .layoutWeight(1)
          .height(40)
          .type(ButtonType.Normal)
          .backgroundColor(this.isCurrentBook(item.id) ? '#EFF6FF' : '#1E3A8A')
          .fontColor(this.isCurrentBook(item.id) ? '#1E3A8A' : Color.White)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .borderRadius(10)
          .onClick(() => {
            this.switchBook(item.id);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({ width: 0.5, color: '#E5E7EB' })
  }
}

@Component
struct MineTab {
  @Link selectedBookId: number;
  @Link bookList: BookCard[];
  @Link notebookCount: number;
  @Link wrongCount: number;
  @Link studyRecordCount: number;

  currentBook(): BookCard {
    for (let i = 0; i < this.bookList.length; i++) {
      if (this.bookList[i].id === this.selectedBookId) {
        return this.bookList[i];
      }
    }
    return this.bookList.length > 0 ? this.bookList[0] : emptyBookCard(this.selectedBookId);
  }

  avatarText(): string {
    const name: string = userProfile.nickname;
    if (name.length === 0) {
      return '晨';
    }
    return name.substring(0, 1);
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        // 紧凑头部信息栏:小圆头像 + 昵称/词书 + 箭头,整行可点击进资料页
        Row({ space: 12 }) {
          Column() {
            Text(this.avatarText())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor('#1E3A8A')
          .justifyContent(FlexAlign.Center)

          Column({ space: 3 }) {
            Text(userProfile.nickname.length > 0 ? userProfile.nickname : 'WordFS用户')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text(this.currentBook().title)
              .fontSize(12)
              .fontColor('#64748B')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(20)
            .fontColor('#1E3A8A')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 0.5, color: '#E5E7EB' })
        .onClick(() => {
          pushUrl(this.getUIContext(), 'pages/ProfilePage');
        })

        // 统一白色圆角列表卡片
        Column({ space: 0 }) {
          this.menuRow('我的生词本', this.notebookCount.toString() + ' 个词', 'pages/CollectionPage')
          Divider().color('#F1F5F9').strokeWidth(0.5)
          this.menuRow('错题本', this.wrongCount.toString() + ' 条待复盘', 'pages/WrongBookPage')
          Divider().color('#F1F5F9').strokeWidth(0.5)
          this.menuRow('学习记录', this.studyRecordCount.toString() + ' 天记录', 'pages/StudyRecordPage')
          Divider().color('#F1F5F9').strokeWidth(0.5)
          this.menuRow('个人资料', this.currentBook().levelTag + ' 默认词书', 'pages/ProfilePage')
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 0.5, color: '#E5E7EB' })

        Button('退出登录')
          .width('100%')
          .height(46)
          .type(ButtonType.Normal)
          .backgroundColor('#FFFFFF')
          .fontColor('#DC2626')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .borderRadius(12)
          .border({ width: 1, color: '#FEE2E2' })
          .onClick(() => {
            resetCurrentUser();
            pushUrl(this.getUIContext(), 'pages/LoginPage');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .backgroundColor('#F8FAFC')
  }

  @Builder
  menuRow(title: string, value: string, url: string) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0F172A')

      Blank()

      Row({ space: 8 }) {
        Text(value)
          .fontSize(13)
          .fontColor('#64748B')
        Text('›')
          .fontSize(18)
          .fontColor('#1E3A8A')
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .onClick(() => {
      pushUrl(this.getUIContext(), url);
    })
  }
}

@Preview
@Component
struct MainPagePreview {
  build() {
    MainPage();
  }
}

@Preview
@Component
struct StudyHomeTabPreview {
  @State previewTabIndex: number = 0;
  @State previewBookId: number = userProfile.selectedBookId;
  @State previewPracticeMode: string = 'learn';
  @State previewShowPracticePage: boolean = false;
  @State previewBookList: BookCard[] = [];
  @State previewTotalLearnedWords: number = 0;
  @State previewStreakDays: number = 0;
  @State previewAccuracyRate: number = 0;
  @State previewReviewDue: number = 0;
  @State previewTodayFinishedWords: number = 0;
  @State previewTodayCorrectRate: number = 0;
  @State previewHomeRemainingLearn: number = 0;

  build() {
    StudyHomeTab({
      currentTabIndex: $previewTabIndex,
      selectedBookId: $previewBookId,
      practiceMode: $previewPracticeMode,
      showPracticePage: $previewShowPracticePage,
      bookList: $previewBookList,
      totalLearnedWords: $previewTotalLearnedWords,
      streakDays: $previewStreakDays,
      accuracyRate: $previewAccuracyRate,
      reviewDue: $previewReviewDue,
      todayFinishedWords: $previewTodayFinishedWords,
      todayCorrectRate: $previewTodayCorrectRate,
      homeRemainingLearn: $previewHomeRemainingLearn
    });

  }
}

@Preview
@Component
struct StudyPracticePagePreview {
  @State previewBookId: number = userProfile.selectedBookId;
  @State previewPracticeMode: string = 'learn';
  @State previewShowPracticePage: boolean = true;
  @State previewBookList: BookCard[] = [];
  @State previewTotalLearnedWords: number = 0;
  @State previewStreakDays: number = 0;
  @State previewAccuracyRate: number = 0;
  @State previewReviewDue: number = 0;
  @State previewTodayFinishedWords: number = 0;
  @State previewTodayCorrectRate: number = 0;

  build() {
    StudyPracticePage({
      selectedBookId: $previewBookId,
      practiceMode: $previewPracticeMode,
      showPracticePage: $previewShowPracticePage,
      bookList: $previewBookList,
      totalLearnedWords: $previewTotalLearnedWords,
      streakDays: $previewStreakDays,
      accuracyRate: $previewAccuracyRate,
      reviewDue: $previewReviewDue,
      todayFinishedWords: $previewTodayFinishedWords,
      todayCorrectRate: $previewTodayCorrectRate
    });

  }
}

@Preview
@Component
struct BookTabPreview {
  @State previewTabIndex: number = 1;
  @State previewBookId: number = userProfile.selectedBookId;
  @State previewBookList: BookCard[] = [];
  @State previewHomeRefreshTick: number = 0;

  build() {
    BookTab({
      currentTabIndex: $previewTabIndex,
      selectedBookId: $previewBookId,
      bookList: $previewBookList,
      homeRefreshTick: $previewHomeRefreshTick
    });

  }
}

@Preview
@Component
struct MineTabPreview {
  @State previewBookId: number = userProfile.selectedBookId;
  @State previewBookList: BookCard[] = [];
  @State previewNotebookCount: number = 0;
  @State previewWrongCount: number = 0;
  @State previewStudyRecordCount: number = 0;

  build() {
    MineTab({
      selectedBookId: $previewBookId,
      bookList: $previewBookList,
      notebookCount: $previewNotebookCount,
      wrongCount: $previewWrongCount,
      studyRecordCount: $previewStudyRecordCount
    });

  }
}
