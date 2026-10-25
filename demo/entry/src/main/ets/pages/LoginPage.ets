import { ApiService } from '../api/ApiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { userProfile } from '../data/AppState';
import { setCurrentUser } from '../data/CurrentUser';
import { showToast, pushUrl } from '../utils/UiFeedback';
import { getApiBaseUrl, setApiBaseUrl, isAutoDiscover, setAutoDiscover } from '../api/ApiConfig';

interface LoginResponseData {
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
  remainingLearnWords: number;
  todayFinishedWords: number;
  todayCorrectRate: number;
}

interface LoginResponse {
  code: number;
  message: string;
  data: LoginResponseData | null;
}

interface LoginRequestBody {
  account: string;
  password: string;
}

@Entry
@Component
struct LoginPage {
  @State apiBaseUrl: string = getApiBaseUrl();
  @State autoDiscover: boolean = isAutoDiscover();
  @State account: string = '';
  @State password: string = '';

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F8FAFC')

      Column() {
        Blank();
        Column({ space: 18 }) {
          Column({ space: 12 }) {
            Image($r('app.media.appth'))
              .width(96)
              .height(96)
              .borderRadius(48)
              .objectFit(ImageFit.Cover);

            Text('WordFS')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A');
            Text('基于FSRS算法和Spring Boot的智能间隔重复记忆背单词APP')
              .fontSize(13)
              .fontColor('#64748B')
              .textAlign(TextAlign.Center)
              .width('80%');
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center);

          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Toggle({ type: ToggleType.Switch, isOn: this.autoDiscover })
                .onChange((isOn: boolean) => {
                  this.autoDiscover = isOn;
                  setAutoDiscover(isOn);
                  if (isOn) {
                    this.apiBaseUrl = getApiBaseUrl();
                  }
                })
                .selectedColor('#1E3A8A');
              Text('自动发现服务器')
                .fontSize(13)
                .fontColor('#64748B');
            }
            .width('100%')
            .justifyContent(FlexAlign.Start);

            if (!this.autoDiscover) {
              Text('后端服务地址')
                .width('100%')
                .fontSize(13)
                .fontColor('#64748B');
              TextInput({ text: this.apiBaseUrl, placeholder: '例如 http://192.168.1.20:8080' })
                .height(46)
                .backgroundColor('#F8FAFC')
                .borderRadius(10)
                .border({ width: 1, color: '#E5E7EB' })
                .padding({ left: 14, right: 14 })
                .fontSize(14)
                .fontColor('#0F172A')
                .onChange((value: string) => {
                  this.apiBaseUrl = value;
                });
            } else {
              Text('当前地址: ' + this.apiBaseUrl)
                .width('100%')
                .fontSize(12)
                .fontColor('#94A3B8');
            }

            Text('账号')
              .width('100%')
              .fontSize(13)
              .fontColor('#64748B');
            TextInput({ text: this.account, placeholder: '请输入账号' })
              .height(46)
              .backgroundColor('#F8FAFC')
              .borderRadius(10)
              .border({ width: 1, color: '#E5E7EB' })
              .padding({ left: 14, right: 14 })
              .fontSize(15)
              .fontColor('#0F172A')
              .onChange((value: string) => {
                this.account = value;
              });

            Text('密码')
              .width('100%')
              .fontSize(13)
              .fontColor('#64748B');
            TextInput({ text: this.password, placeholder: '请输入密码' })
              .height(46)
              .backgroundColor('#F8FAFC')
              .borderRadius(10)
              .border({ width: 1, color: '#E5E7EB' })
              .padding({ left: 14, right: 14 })
              .fontSize(15)
              .fontColor('#0F172A')
              .type(InputType.Password)
              .onChange((value: string) => {
                this.password = value;
              });

            Row() {
              Text('每次启动需重新登录')
                .fontSize(12)
                .fontColor('#94A3B8');
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 });

            Button('登录')
              .width('100%')
              .height(48)
              .type(ButtonType.Normal)
              .backgroundColor('#1E3A8A')
              .fontColor(Color.White)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(12)
              .onClick(() => {
                if (!this.account.trim() || !this.password.trim()) {
                  showToast(this.getUIContext(), '请输入账号和密码');
                  return;
                }
                if (!this.autoDiscover) {
                  if (!this.apiBaseUrl.trim().startsWith('http://') && !this.apiBaseUrl.trim().startsWith('https://')) {
                    showToast(this.getUIContext(), '后端地址必须以 http:// 或 https:// 开头');
                    return;
                  }
                  setApiBaseUrl(this.apiBaseUrl);
                }
                const requestBody: LoginRequestBody = {
                  account: this.account.trim(),
                  password: this.password.trim()
                };
                ApiService.post('/api/auth/login', requestBody)
                  .then((result: string) => {
                    try {
                      const response = JSON.parse(result) as LoginResponse;
                      if (response.code !== 200 || response.data === null) {
                        showToast(this.getUIContext(), response.message);
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
                      userProfile.remainingLearnWords = response.data.remainingLearnWords;
                      userProfile.todayFinishedWords = response.data.todayFinishedWords;
                      userProfile.todayCorrectRate = response.data.todayCorrectRate;
                      setCurrentUser(response.data.id, response.data.account, response.data.nickname);
                      showToast(this.getUIContext(), '登录成功');
                      pushUrl(this.getUIContext(), 'pages/MainPage');
                    } catch (error) {
                      const err = error as BusinessError;
                      showToast(this.getUIContext(), '登录响应解析失败');
                      console.error('parse failed: ' + err.message);
                    }
                  })
                  .catch((error: BusinessError) => {
                    showToast(this.getUIContext(), '登录失败，请检查网络或后端服务');
                    console.error('login failed: ' + error.message);
                  });
              });

            Row({ space: 6 }) {
              Text('还没有账号？')
                .fontSize(13)
                .fontColor('#94A3B8');
              Text('去注册')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E3A8A')
                .onClick(() => {
                  pushUrl(this.getUIContext(), 'pages/RegisterPage');
                });
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 4 });
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({ width: 0.5, color: '#E5E7EB' });
        }
        .width('100%')
        .padding({ left: 20, right: 20 });
        Blank();
      }
      .width('100%')
      .height('100%');
    }
    .width('100%')
    .height('100%');
  }
}

@Preview
@Component
struct LoginPagePreview {
  build() {
    LoginPage();
  }
}
