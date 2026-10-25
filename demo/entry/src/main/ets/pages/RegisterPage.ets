import { ApiService } from '../api/ApiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { userProfile } from '../data/AppState';
import { setCurrentUser } from '../data/CurrentUser';
import { showToast, pushUrl, routerBack } from '../utils/UiFeedback';

interface RegisterResponseData {
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

interface RegisterResponse {
  code: number;
  message: string;
  data: RegisterResponseData | null;
}

interface RegisterRequestBody {
  account: string;
  password: string;
  nickname: string;
}

@Entry
@Component
struct RegisterPage {
  @State account: string = '';
  @State nickname: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';

  register() {
    try {
      const accountText: string = this.account.trim();
      const nicknameText: string = this.nickname.trim();
      const passwordText: string = this.password.trim();
      const confirmPasswordText: string = this.confirmPassword.trim();

      if (!accountText || !passwordText || !confirmPasswordText) {
        showToast(this.getUIContext(), '请输入账号和密码');
        return;
      }

      if (passwordText.length < 6) {
        showToast(this.getUIContext(), '密码至少 6 位');
        return;
      }

      if (passwordText !== confirmPasswordText) {
        showToast(this.getUIContext(), '两次输入的密码不一致');
        return;
      }

      const requestBody: RegisterRequestBody = {
        account: accountText,
        password: passwordText,
        nickname: nicknameText
      };

      ApiService.post('/api/auth/register', requestBody)
        .then((result: string) => {
          try {
            const response = JSON.parse(result) as RegisterResponse;

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

            showToast(this.getUIContext(), '注册成功');
            pushUrl(this.getUIContext(), 'pages/MainPage');
          } catch (error) {
            const err = error as BusinessError<number>;
            showToast(this.getUIContext(), '注册响应解析失败');
            console.error('register parse failed: ' + err.message);
          }
        })
        .catch((error: BusinessError<number>) => {
          showToast(this.getUIContext(), '注册失败，请检查网络或后端服务');
          console.error('register failed: ' + error.message);
        });
    } catch (error) {
      const err = error as BusinessError<number>;
      console.error('register click failed: ' + err.message);
    }
  }

  build() {
    Column() {
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
          });

        Blank();
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 });

      Blank();

      Column({ space: 18 }) {
        Column({ space: 12 }) {
          Image($r('app.media.appth'))
            .width(96)
            .height(96)
            .borderRadius(48)
            .objectFit(ImageFit.Cover);

          Text('创建账号')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A');

          Text('注册后直接进入WordFS')
            .fontSize(13)
            .fontColor('#64748B');
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center);

        Column({ space: 12 }) {
          this.inputLabel('账号');
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

          this.inputLabel('昵称');
          TextInput({ text: this.nickname, placeholder: '请输入昵称，可不填' })
            .height(46)
            .backgroundColor('#F8FAFC')
            .borderRadius(10)
            .border({ width: 1, color: '#E5E7EB' })
            .padding({ left: 14, right: 14 })
            .fontSize(15)
            .fontColor('#0F172A')
            .onChange((value: string) => {
              this.nickname = value;
            });

          this.inputLabel('密码');
          TextInput({ text: this.password, placeholder: '请输入至少 6 位密码' })
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

          this.inputLabel('确认密码');
          TextInput({ text: this.confirmPassword, placeholder: '请再次输入密码' })
            .height(46)
            .backgroundColor('#F8FAFC')
            .borderRadius(10)
            .border({ width: 1, color: '#E5E7EB' })
            .padding({ left: 14, right: 14 })
            .fontSize(15)
            .fontColor('#0F172A')
            .type(InputType.Password)
            .onChange((value: string) => {
              this.confirmPassword = value;
            });

          Button('注册并登录')
            .width('100%')
            .height(48)
            .type(ButtonType.Normal)
            .backgroundColor('#1E3A8A')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .borderRadius(12)
            .margin({ top: 8 })
            .onClick(() => {
              this.register();
            });
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .border({ width: 0.5, color: '#E5E7EB' });

        Row({ space: 6 }) {
          Text('已有账号？')
            .fontSize(13)
            .fontColor('#94A3B8');
          Text('返回登录')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E3A8A')
            .onClick(() => {
              routerBack(this.getUIContext());
            });
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20 });

      Blank();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC');
  }

  @Builder
  inputLabel(text: string) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .fontColor('#64748B');
  }
}

@Preview
@Component
struct RegisterPagePreview {
  build() {
    RegisterPage();
  }
}
