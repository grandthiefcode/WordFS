import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiService } from '../api/ApiService';
import { showToast, routerBack } from '../utils/UiFeedback';

interface BookWordItem {
  id: number;
  word: string;
  phonetic: string;
  meaning: string;
}

interface WordListApiResponse {
  code: number;
  message: string;
  data: BookWordItem[] | null;
}

interface BookWordsRouteParams {
  bookId: number;
  bookTitle: string;
}

/** LazyForEach 数据源,承载整本词书数千单词的虚拟滚动 */
class WordDataSource implements IDataSource {
  private list: BookWordItem[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.list.length;
  }

  getData(index: number): BookWordItem {
    return this.list[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  setData(list: BookWordItem[]): void {
    this.list = list;
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }
}

@Entry
@Component
struct BookWordsPage {
  @State bookTitle: string = '词书单词';
  @State keyword: string = '';
  @State isLoading: boolean = false;
  @State totalCount: number = 0;

  private bookId: number = 0;
  private allWords: BookWordItem[] = [];
  private dataSource: WordDataSource = new WordDataSource();

  aboutToAppear() {
    const params = router.getParams() as BookWordsRouteParams;
    if (params !== null && params !== undefined) {
      this.bookId = params.bookId;
      if (params.bookTitle.length > 0) {
        this.bookTitle = params.bookTitle;
      }
    }
    this.loadWords();
  }

  loadWords() {
    if (this.bookId <= 0) {
      showToast(this.getUIContext(), '缺少词书信息');
      return;
    }

    this.isLoading = true;
    ApiService.get('/api/words?bookId=' + this.bookId)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as WordListApiResponse;
          if (response.code !== 200 || response.data === null) {
            showToast(this.getUIContext(), response.message);
            this.isLoading = false;
            return;
          }

          this.allWords = response.data;
          this.totalCount = this.allWords.length;
          this.applyFilter();
        } catch (error) {
          const err = error as BusinessError<number>;
          showToast(this.getUIContext(), '单词数据解析失败');
          console.error('load book words parse failed: ' + err.message);
        } finally {
          this.isLoading = false;
        }
      })
      .catch((error: BusinessError<number>) => {
        this.isLoading = false;
        showToast(this.getUIContext(), '单词列表加载失败');
        console.error('load book words failed: ' + error.message);
      });
  }

  applyFilter() {
    const key: string = this.keyword.trim().toLowerCase();
    if (key.length === 0) {
      this.dataSource.setData(this.allWords);
      return;
    }

    const matched: BookWordItem[] = [];
    for (let i = 0; i < this.allWords.length; i++) {
      const item: BookWordItem = this.allWords[i];
      if (item.word.toLowerCase().indexOf(key) >= 0 || item.meaning.toLowerCase().indexOf(key) >= 0) {
        matched.push(item);
      }
    }
    this.dataSource.setData(matched);
  }

  clearKeyword() {
    this.keyword = '';
    this.applyFilter();
  }

  startPractice() {
    // 词书单词页是从主页 BookTab 跳入，直接返回主页即可让用户点击 Learn/Review 卡片开始学习
    showToast(this.getUIContext(), '返回首页点击 Learn / Review 卡片开始学习');
    routerBack(this.getUIContext());
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.pageHeader()

        // 搜索栏：浅蓝边框搜索框 + 词书标题/数量
        Column({ space: 10 }) {
          Row() {
            Text(this.bookTitle)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
              .layoutWeight(1)

            Text('共 ' + this.totalCount.toString() + ' 词')
              .fontSize(13)
              .fontColor('#64748B')
          }
          .width('100%')

          Row({ space: 8 }) {
            TextInput({ text: this.keyword, placeholder: '搜索单词或中文释义' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#FFFFFF')
              .borderRadius(10)
              .border({ width: 1, color: '#1E3A8A' })
              .fontSize(14)
              .fontColor('#0F172A')
              .padding({ left: 14, right: 14 })
              .onChange((value: string) => {
                this.keyword = value;
                this.applyFilter();
              })

            if (this.keyword.length > 0) {
              Text('清除')
                .fontSize(13)
                .fontColor('#1E3A8A')
                .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
                .border({ width: 1, color: '#1E3A8A' })
                .onClick(() => {
                  this.clearKeyword();
                })
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 10 })
        .alignItems(HorizontalAlign.Start)

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(36)
              .height(36)
              .color('#1E3A8A')
            Text('正在加载单词列表...')
              .fontSize(14)
              .fontColor('#64748B')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            LazyForEach(this.dataSource, (item: BookWordItem, index: number) => {
              ListItem() {
                this.wordRow(item, index);
              }
            }, (item: BookWordItem) => item.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: 88 })
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')

      // 右下角固定悬浮深蓝色圆角【开始学习】主按钮
      Button('开始学习')
        .type(ButtonType.Normal)
        .height(48)
        .backgroundColor('#1E3A8A')
        .fontColor(Color.White)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .borderRadius(24)
        .padding({ left: 24, right: 24 })
        .margin({ right: 16, bottom: 20 })
        .shadow({ radius: 8, color: '#1E3A8A33', offsetX: 0, offsetY: 4 })
        .onClick(() => {
          this.startPractice();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }

  @Builder
  wordRow(item: BookWordItem, index: number) {
    Row({ space: 12 }) {
      Text((index + 1).toString())
        .fontSize(12)
        .fontColor('#94A3B8')
        .width(32)
        .textAlign(TextAlign.Center)

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.word)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          if (item.phonetic.length > 0) {
            Text(item.phonetic)
              .fontSize(12)
              .fontColor('#94A3B8')
          }
        }
        .width('100%')

        Text(item.meaning)
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#64748B')
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 0.5, color: '#E5E7EB' })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  pageHeader() {
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
      Text('词书单词')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Blank()
      Text('    ')
        .fontSize(15)
        .opacity(0)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 4 })
  }
}

@Preview
@Component
struct BookWordsPagePreview {
  build() {
    BookWordsPage();
  }
}
