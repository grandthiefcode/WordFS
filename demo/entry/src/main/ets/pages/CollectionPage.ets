import { ApiService } from '../api/ApiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { currentUser } from '../data/CurrentUser';
import { showToast, routerBack } from '../utils/UiFeedback';

interface NotebookWord {
  id: number;
  word: string;
  meaning: string;
  bookTitle: string;
  masteryLabel: string;
  nextReview: string;
  addedAt: string;
  note: string;
}

interface NotebookWordApiItem {
  id: number;
  userId: number;
  wordId: number;
  word: string;
  meaning: string;
  bookTitle: string;
  masteryLabel: string;
  nextReview: string;
  addedAt: string;
  noteText: string;
}

interface NotebookWordApiResponse {
  code: number;
  message: string;
  data: NotebookWordApiItem[] | null;
}

interface SimpleResultResponse {
  code: number;
  message: string;
  data: string | null;
}

@Entry
@Component
struct CollectionPage {
  @State records: NotebookWord[] = [];
  @State isLoading: boolean = false;
  @State deletingId: number = 0;
  @State isBatchMode: boolean = false;
  @State selectedIds: number[] = [];
  @State batchDeleting: boolean = false;

  loadNotebookWords() {
    this.isLoading = true;
    ApiService.get('/api/notebook-words?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as NotebookWordApiResponse;

          if (response.code !== 200 || response.data === null) {
            showToast(this.getUIContext(), response.message);
            this.isLoading = false;
            return;
          }

          const mappedRecords: NotebookWord[] = response.data.map((item: NotebookWordApiItem): NotebookWord => {
            const addedAtText: string = item.addedAt.length >= 10 ? item.addedAt.slice(5, 10) : item.addedAt;
            return {
              id: item.id,
              word: item.word,
              meaning: item.meaning,
              bookTitle: item.bookTitle,
              masteryLabel: item.masteryLabel,
              nextReview: item.nextReview,
              addedAt: addedAtText,
              note: item.noteText
            };
          });

          this.records = mappedRecords;
        } catch (error) {
          const err = error as BusinessError<number>;
          showToast(this.getUIContext(), '生词本数据解析失败');
          console.error('load notebook words parse failed: ' + err.message);
        } finally {
          this.isLoading = false;
        }
      })
      .catch((error: BusinessError<number>) => {
        this.isLoading = false;
        showToast(this.getUIContext(), '生词本加载失败');
        console.error('load notebook words failed: ' + error.message);
      });
  }

  confirmDeleteNotebookWord(item: NotebookWord) {
    try {
      this.getUIContext().showAlertDialog({
        title: '删除生词',
        message: '确定要从生词本删除 "' + item.word + '" 吗？',
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '删除',
          fontColor: '#DC2626',
          action: () => {
            this.deleteNotebookWord(item.id);
          }
        }
      });
    } catch (error) {
      const err = error as BusinessError<number>;
      console.error('show delete notebook dialog failed: ' + err.message);
    }
  }

  deleteNotebookWord(id: number) {
    if (this.deletingId !== 0) {
      return;
    }

    this.deletingId = id;
    ApiService.delete('/api/notebook-words/' + id + '?userId=' + currentUser.id)
      .then((result: string) => {
        try {
          const response = JSON.parse(result) as SimpleResultResponse;
          if (response.code !== 200) {
            showToast(this.getUIContext(), response.message);
            return;
          }

          showToast(this.getUIContext(), '删除成功');
          this.loadNotebookWords();
        } catch (error) {
          const err = error as BusinessError<number>;
          console.error('delete notebook word parse failed: ' + err.message);
        } finally {
          this.deletingId = 0;
        }
      })
      .catch((error: BusinessError<number>) => {
        this.deletingId = 0;
        showToast(this.getUIContext(), '删除失败');
        console.error('delete notebook word failed: ' + error.message);
      });
  }

  enterBatchMode() {
    this.isBatchMode = true;
    this.selectedIds = [];
  }

  exitBatchMode() {
    this.isBatchMode = false;
    this.selectedIds = [];
  }

  toggleSelect(id: number) {
    const index: number = this.selectedIds.indexOf(id);
    if (index >= 0) {
      this.selectedIds.splice(index, 1);
    } else {
      this.selectedIds.push(id);
    }
  }

  toggleSelectAll() {
    if (this.selectedIds.length === this.records.length) {
      this.selectedIds = [];
    } else {
      const allIds: number[] = [];
      for (let i = 0; i < this.records.length; i++) {
        allIds.push(this.records[i].id);
      }
      this.selectedIds = allIds;
    }
  }

  confirmBatchDelete() {
    if (this.selectedIds.length === 0) {
      showToast(this.getUIContext(), '请先选择要删除的单词');
      return;
    }
    try {
      this.getUIContext().showAlertDialog({
        title: '批量删除',
        message: '确定要删除选中的 ' + this.selectedIds.length.toString() + ' 个生词吗？此操作不可恢复。',
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '删除',
          fontColor: '#DC2626',
          action: () => {
            this.batchDelete();
          }
        }
      });
    } catch (error) {
      const err = error as BusinessError<number>;
      console.error('show batch delete dialog failed: ' + err.message);
    }
  }

  batchDelete() {
    if (this.batchDeleting) {
      return;
    }
    this.batchDeleting = true;
    let successCount: number = 0;
    const totalCount: number = this.selectedIds.length;

    const deleteNext = (index: number) => {
      if (index >= totalCount) {
        this.batchDeleting = false;
        showToast(this.getUIContext(), '成功删除 ' + successCount.toString() + ' 个生词');
        this.exitBatchMode();
        this.loadNotebookWords();
        return;
      }
      const id: number = this.selectedIds[index];
      ApiService.delete('/api/notebook-words/' + id + '?userId=' + currentUser.id)
        .then((result: string) => {
          try {
            const response = JSON.parse(result) as SimpleResultResponse;
            if (response.code === 200) {
              successCount++;
            }
          } catch (error) {
            const err = error as BusinessError<number>;
            console.error('batch delete parse failed: ' + err.message);
          }
          deleteNext(index + 1);
        })
        .catch((error: BusinessError<number>) => {
          console.error('batch delete item failed: ' + error.message);
          deleteNext(index + 1);
        });
    };
    deleteNext(0);
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.pageHeader('我的生词本')

        Scroll() {
          Column({ space: 12 }) {
            // 顶部统计行
            Row() {
              Text('共 ' + this.records.length.toString() + ' 个生词')
                .fontSize(13)
                .fontColor('#64748B')
              Blank()
              Text('按加入时间排序')
                .fontSize(12)
                .fontColor('#94A3B8')
            }
            .width('100%')
            .padding({ left: 4, right: 4, bottom: 2 })

            if (this.isLoading) {
              this.loadingState('正在加载生词本...');
            } else if (this.records.length === 0) {
              this.emptyState('暂无生词', '背词时点击“加入生词本”，这里会显示需要重点复习的单词。');
            } else {
              ForEach(this.records, (item: NotebookWord) => {
                Row({ space: 12 }) {
                  // 多选模式下显示选择框
                  if (this.isBatchMode) {
                    this.checkbox(item.id);
                  }

                  Column({ space: 10 }) {
                    // 标题行：单词加粗深蓝 + 右上角浅灰删除图标
                    Row() {
                      Text(item.word)
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#1E3A8A')
                        .layoutWeight(1)
                      if (!this.isBatchMode) {
                        Text('✕')
                          .fontSize(14)
                          .fontColor('#94A3B8')
                          .width(28)
                          .height(28)
                          .textAlign(TextAlign.Center)
                          .onClick(() => {
                            this.confirmDeleteNotebookWord(item);
                          })
                      }
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

                  // 元信息分层：来源 | 加入时间 | 下次复习
                  Row({ space: 6 }) {
                    this.metaTag('来源 ' + item.bookTitle)
                    this.metaTag('加入 ' + item.addedAt)
                    this.metaTag('复习 ' + item.nextReview)
                  }
                  .width('100%')

                  // 备注
                  if (item.note.length > 0) {
                    Text('备注：' + item.note)
                      .width('100%')
                      .fontSize(12)
                      .lineHeight(18)
                      .fontColor('#64748B')
                  }

                    // 状态标签（待复习/已掌握）
                    Row() {
                      Text(item.masteryLabel)
                        .fontSize(11)
                        .fontColor('#1E3A8A')
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor('#DBEAFE')
                        .borderRadius(6)
                      Blank()
                    }
                    .width('100%')
                  }
                }
                .width('100%')
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .border({ width: 1, color: this.isBatchMode && this.selectedIds.indexOf(item.id) >= 0 ? '#1E3A8A' : '#E5E7EB' })
                .onClick(() => {
                  if (this.isBatchMode) {
                    this.toggleSelect(item.id);
                  }
                })
              }, (item: NotebookWord) => item.id.toString())
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 88 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')

      // 底部按钮区域
      if (this.isBatchMode) {
        Row({ space: 12 }) {
          // 退出批量模式
          Button('退出')
            .type(ButtonType.Normal)
            .height(44)
            .backgroundColor('#FFFFFF')
            .fontColor('#64748B')
            .fontSize(14)
            .borderRadius(12)
            .border({ width: 1, color: '#CBD5E1' })
            .layoutWeight(1)
            .onClick(() => {
              this.exitBatchMode();
            })

          // 全选/取消全选
          Button(this.selectedIds.length === this.records.length ? '取消全选' : '全选')
            .type(ButtonType.Normal)
            .height(44)
            .backgroundColor('#FFFFFF')
            .fontColor('#1E3A8A')
            .fontSize(14)
            .borderRadius(12)
            .border({ width: 1, color: '#1E3A8A' })
            .layoutWeight(1)
            .onClick(() => {
              this.toggleSelectAll();
            })

          // 删除选中
          Button('删除(' + this.selectedIds.length.toString() + ')')
            .type(ButtonType.Normal)
            .height(44)
            .backgroundColor(this.selectedIds.length === 0 ? '#94A3B8' : '#DC2626')
            .fontColor(Color.White)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .borderRadius(12)
            .layoutWeight(1.5)
            .enabled(!this.batchDeleting && this.selectedIds.length > 0)
            .onClick(() => {
              this.confirmBatchDelete();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      } else {
        Button('批量管理')
          .type(ButtonType.Normal)
          .height(46)
          .backgroundColor('#1E3A8A')
          .fontColor(Color.White)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .borderRadius(12)
          .padding({ left: 24, right: 24 })
          .margin({ right: 16, bottom: 20 })
          .onClick(() => {
            this.enterBatchMode();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
    .onAppear(() => {
      this.loadNotebookWords();
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
  checkbox(id: number) {
    Row() {
      if (this.selectedIds.indexOf(id) >= 0) {
        Text('✓')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
    }
    .width(24)
    .height(24)
    .borderRadius(12)
    .backgroundColor(this.selectedIds.indexOf(id) >= 0 ? '#1E3A8A' : '#FFFFFF')
    .border({ width: 1.5, color: this.selectedIds.indexOf(id) >= 0 ? '#1E3A8A' : '#CBD5E1' })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .margin({ top: 4 })
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
struct CollectionPagePreview {
  build() {
    CollectionPage();
  }
}
