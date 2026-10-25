import { ApiService } from '../api/ApiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { currentUser } from '../data/CurrentUser';
import { showToast, routerBack } from '../utils/UiFeedback';

interface WrongWord {
  id: number;
  word: string;
  meaning: string;
  bookTitle: string;
  wrongCount: number;
  lastWrongAt: string;
  sentence: string;
  reason: string;
}

interface WrongWordApiItem {
  id: number;
  userId: number;
  wordId: number;
  word: string;
  meaning: string;
  bookTitle: string;
  wrongCount: number;
  lastWrongAt: string;
  sentenceText: string;
  reasonText: string;
}

interface WrongWordApiResponse {
  code: number;
  message: string;
  data: WrongWordApiItem[] | null;
}

interface SimpleResultResponse {
  code: number;
  message: string;
  data: string | null;
}

type WrongCountFilter = 'all' | 'once' | 'few' | 'many';

@Entry
@Component
struct WrongBookPage {
  @State records: WrongWord[] = [];
  @State filteredRecords: WrongWord[] = [];
  @State isLoading: boolean = false;
  @State deletingId: number = 0;
  @State currentFilter: WrongCountFilter = 'all';
  @State showFilterPanel: boolean = false;

  loadWrongWords() {
    this.isLoading = true;
    ApiService.get('/api/wrong-words?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as WrongWordApiResponse;

          if (response.code !== 200 || response.data === null) {
            showToast(this.getUIContext(), response.message);
            this.isLoading = false;
            return;
          }

          const mappedRecords: WrongWord[] = response.data.map((item: WrongWordApiItem): WrongWord => {
            const rawLastWrongAt: string = item.lastWrongAt ?? '';
            const lastWrongAtText: string = rawLastWrongAt.length >= 16
              ? rawLastWrongAt.slice(0, 16).replace('T', ' ')
              : rawLastWrongAt;

            return {
              id: item.id,
              word: item.word,
              meaning: item.meaning,
              bookTitle: item.bookTitle,
              wrongCount: item.wrongCount,
              lastWrongAt: lastWrongAtText,
              sentence: item.sentenceText ?? '',
              reason: item.reasonText ?? ''
            };
          });

          this.records = mappedRecords;
          this.applyFilter();
        } catch (error) {
          const err = error as BusinessError<number>;
          showToast(this.getUIContext(), '错题本数据解析失败');
          console.error('load wrong words parse failed: ' + err.message);
        } finally {
          this.isLoading = false;
        }
      })
      .catch((error: BusinessError<number>) => {
        this.isLoading = false;
        showToast(this.getUIContext(), '错题本加载失败');
        console.error('load wrong words failed: ' + error.message);
      });
  }

  confirmDeleteWrongWord(item: WrongWord) {
    try {
      this.getUIContext().showAlertDialog({
        title: '删除错题',
        message: '确定要从错题本删除 "' + item.word + '" 吗？',
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '删除',
          fontColor: '#DC2626',
          action: () => {
            this.deleteWrongWord(item.id);
          }
        }
      });
    } catch (error) {
      const err = error as BusinessError<number>;
      console.error('show delete wrong word dialog failed: ' + err.message);
    }
  }

  deleteWrongWord(id: number) {
    if (this.deletingId !== 0) {
      return;
    }

    this.deletingId = id;
    ApiService.delete('/api/wrong-words/' + id + '?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as SimpleResultResponse;
          if (response.code !== 200) {
            showToast(this.getUIContext(), response.message);
            return;
          }

          showToast(this.getUIContext(), '删除成功');
          this.loadWrongWords();
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('delete wrong word parse failed: ' + err.message);
        } finally {
          this.deletingId = 0;
        }
      })
      .catch((error: BusinessError<number>) => {
        this.deletingId = 0;
        showToast(this.getUIContext(), '删除失败');
        console.error('delete wrong word failed: ' + error.message);
      });
  }

  applyFilter() {
    if (this.currentFilter === 'all') {
      this.filteredRecords = this.records;
      return;
    }
    const result: WrongWord[] = [];
    for (let i = 0; i < this.records.length; i++) {
      const item: WrongWord = this.records[i];
      if (this.currentFilter === 'once' && item.wrongCount === 1) {
        result.push(item);
      } else if (this.currentFilter === 'few' && item.wrongCount >= 2 && item.wrongCount <= 3) {
        result.push(item);
      } else if (this.currentFilter === 'many' && item.wrongCount >= 4) {
        result.push(item);
      }
    }
    this.filteredRecords = result;
  }

  setFilter(filter: WrongCountFilter) {
    this.currentFilter = filter;
    this.showFilterPanel = false;
    this.applyFilter();
  }

  getFilterLabel(): string {
    if (this.currentFilter === 'all') return '筛选';
    if (this.currentFilter === 'once') return '错误1次';
    if (this.currentFilter === 'few') return '错误2-3次';
    return '错误4次+';
  }

  build() {
    Column() {
      this.pageHeader('错题本')

      Scroll() {
        Column({ space: 12 }) {
          // 顶部统计行
          Row() {
            Text('共 ' + this.filteredRecords.length.toString() + ' 条错题')
              .fontSize(13)
              .fontColor('#64748B')
            Blank()
            Text('按错误时间排序')
              .fontSize(12)
              .fontColor('#94A3B8')
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 2 })

          // 筛选面板
          if (this.showFilterPanel) {
            Row({ space: 8 }) {
              Text('全部')
                .fontSize(12)
                .fontColor(this.currentFilter === 'all' ? '#FFFFFF' : '#1E3A8A')
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .backgroundColor(this.currentFilter === 'all' ? '#1E3A8A' : '#FFFFFF')
                .borderRadius(16)
                .border({ width: 1, color: '#1E3A8A' })
                .onClick(() => { this.setFilter('all'); })

              Text('错误1次')
                .fontSize(12)
                .fontColor(this.currentFilter === 'once' ? '#FFFFFF' : '#1E3A8A')
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .backgroundColor(this.currentFilter === 'once' ? '#1E3A8A' : '#FFFFFF')
                .borderRadius(16)
                .border({ width: 1, color: '#1E3A8A' })
                .onClick(() => { this.setFilter('once'); })

              Text('错误2-3次')
                .fontSize(12)
                .fontColor(this.currentFilter === 'few' ? '#FFFFFF' : '#1E3A8A')
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .backgroundColor(this.currentFilter === 'few' ? '#1E3A8A' : '#FFFFFF')
                .borderRadius(16)
                .border({ width: 1, color: '#1E3A8A' })
                .onClick(() => { this.setFilter('few'); })

              Text('错误4次+')
                .fontSize(12)
                .fontColor(this.currentFilter === 'many' ? '#FFFFFF' : '#1E3A8A')
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .backgroundColor(this.currentFilter === 'many' ? '#1E3A8A' : '#FFFFFF')
                .borderRadius(16)
                .border({ width: 1, color: '#1E3A8A' })
                .onClick(() => { this.setFilter('many'); })
            }
            .width('100%')
            .padding({ left: 4, right: 4, bottom: 8 })
          }

          if (this.isLoading) {
            this.loadingState('正在加载错题本...');
          } else if (this.filteredRecords.length === 0) {
            this.emptyState('暂无错题', this.currentFilter === 'all' ? '答题错误的单词会自动进入这里，方便你集中复盘。' : '该筛选条件下暂无错题。');
          } else {
            ForEach(this.filteredRecords, (item: WrongWord) => {
              Column({ space: 10 }) {
                // 标题行：单词加粗深蓝 + 右侧小操作图标深蓝
                Row() {
                  Text(item.word)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1E3A8A')
                    .layoutWeight(1)
                  Text('›')
                    .fontSize(20)
                    .fontColor('#1E3A8A')
                    .width(28)
                    .height(28)
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                // 释义（深灰，可换行）
                Text(item.meaning)
                  .width('100%')
                  .fontSize(14)
                  .lineHeight(22)
                  .fontColor('#334155')

                Divider().color('#F1F5F9').strokeWidth(0.5)

                // 标签：来源词书 + 最近错误时间（淡蓝胶囊）
                Row({ space: 6 }) {
                  this.metaTag('来源 ' + item.bookTitle)
                  this.metaTag('最近错误 ' + item.lastWrongAt)
                }
                .width('100%')

                // 错误例句（深灰小字）
                if (item.sentence.length > 0) {
                  Text(item.sentence)
                    .width('100%')
                    .fontSize(13)
                    .lineHeight(20)
                    .fontColor('#475569')
                }

                // 错误原因（深灰小字）
                if (item.reason.length > 0) {
                  Text('错误原因：' + item.reason)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor('#64748B')
                }

                // 错误次数红色提示 + 删除按钮浅灰
                Row() {
                  Text('错误 ' + item.wrongCount.toString() + ' 次')
                    .fontSize(11)
                    .fontColor('#DC2626')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor('#FEE2E2')
                    .borderRadius(6)
                  Blank()
                  Text('删除')
                    .fontSize(12)
                    .fontColor('#64748B')
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor('#F1F5F9')
                    .borderRadius(10)
                    .onClick(() => {
                      this.confirmDeleteWrongWord(item);
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .border({ width: 0.5, color: '#E5E7EB' })
            }, (item: WrongWord) => item.id.toString())
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
    .onAppear(() => {
      this.loadWrongWords();
    })
  }

  @Builder
  metaTag(value: string) {
    Text(value)
      .fontSize(11)
      .fontColor('#1E3A8A')
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor('#EFF6FF')
      .borderRadius(6)
  }

  @Builder
  loadingState(message: string) {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color('#1E3A8A');
      Text(message)
        .fontSize(14)
        .fontColor('#64748B');
    }
    .width('100%')
    .padding({ top: 42, bottom: 42 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({ width: 0.5, color: '#E5E7EB' })
  }

  @Builder
  emptyState(title: string, description: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A');
      Text(description)
        .fontSize(13)
        .lineHeight(20)
        .fontColor('#64748B')
        .textAlign(TextAlign.Center);
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 42, bottom: 42 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .border({ width: 0.5, color: '#E5E7EB' })
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
      // 右上角【筛选】浅蓝边框按钮
      Text(this.getFilterLabel())
        .fontSize(13)
        .fontColor('#1E3A8A')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(this.currentFilter === 'all' ? '#FFFFFF' : '#EFF6FF')
        .borderRadius(10)
        .border({ width: 1, color: '#1E3A8A' })
        .onClick(() => {
          this.showFilterPanel = !this.showFilterPanel;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }
}

@Preview
@Component
struct WrongBookPagePreview {
  build() {
    WrongBookPage();
  }
}
