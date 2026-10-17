import { TitleBar } from '../common/view/TitleBar';
import { SelectAreaDialog } from '../view/SelectAreaDialog';
import { router } from '@kit.ArkUI';
import { ExpressInfoSearchProps } from './ExpressInfoSearch';
import { ExpressInfo } from '../common/entity/ExpressInfo';
import Constants from '../common/Constants';
import { getExpNetwork } from '../service/default';
import { Log, StrUtils } from '@zycore/common';


@Entry
@Component
struct AreaSelect {
  @State from: ExpressInfo = new ExpressInfo(100, '')
  @State defaultColor: string = '#666666'
  @State valueKg: number = 1
  @State textValue: string = ''
  @State textIndex: number | number[] = 0
  @State input: string = ''
  sfDialog: CustomDialogController = new CustomDialogController({
    builder: SelectAreaDialog({
      textValue: $textValue,
      textIndex: $textIndex,
      cancel: () => {
      },
      confirm: () => {
      }
    }),
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 },
    gridCount: 4,
    customStyle: false,
    cornerRadius: 10
  })

  aboutToAppear(): void {

    let params = router.getParams();
    if ((params as ExpressInfoSearchProps).from) {
      this.textValue = (params as ExpressInfoSearchProps).from
      this.textIndex = (params as ExpressInfoSearchProps).from_area_index
    } else if ((params as ExpressInfoSearchProps).to) {
      this.textValue = (params as ExpressInfoSearchProps).to
      this.textIndex = (params as ExpressInfoSearchProps).to_area_index
    } else {
      this.from = router.getParams() as ExpressInfo
    }

    Log.info('AreaSelect aboutToAppear: '+JSON.stringify(this.textIndex))
  }

  build() {
    RelativeContainer() {

      Column({ space: '10vp' }) {
        TitleBar({ title: this.from.type === Constants.TYPE_AREA ? '快递网点查询' : '地址选择' })

        Column() {
          Row() {
            Text('省 市 区：')
              .fontSize(15)
              .fontColor('#333333')
              .margin({
                left: 5
              })

            Text(StrUtils.isNotBlank(this.textValue) ? this.textValue : '请选择省市区')
              .fontSize(15)
              .fontColor(StrUtils.isNotBlank(this.textValue) ? '#333333' : '#aaa')
              .margin({
                left: 10
              })

            Blank()

            Image($r('app.media.arrow_down_1'))
              .fitOriginalSize(true)

          }
          .width('100%')
          .padding(20)
          .onClick(() => {
            this.sfDialog.open()
          })
          .alignItems(VerticalAlign.Center)

        }.width('93%')
        .backgroundColor(Color.White)
        .borderRadius(15)

        Column() {
          Row() {

            Text('详细地址：')
              .fontSize(15)
              .fontColor('#333333')
              .margin({
                left: 5
              })

            TextInput({ placeholder: '请输入详细地址' })
              .placeholderColor('#aaa')
              .layoutWeight(1)
              .onChange((value: string) => {
                this.input = value
              })
              .height(70)
              .id('input')

          }
          .width('100%')
          .padding(20)
          .alignItems(VerticalAlign.Top)

        }.width('93%')
        .backgroundColor(Color.White)
        .borderRadius(15)

      }

      Button('确定', { type: ButtonType.Normal, stateEffect: true })
        .borderRadius(8)
        .backgroundColor(0x317aff)
        .alignRules({
          bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
          middle: { anchor: '__container__', align: HorizontalAlign.Center }
        })
        .margin({
          bottom: 40
        })
        .width('93%')
        .height(50)
        .onClick(() => {
          if (this.from.type != Constants.TYPE_AREA) {
            // 地址选择
            let b = router.getParams() as ExpressInfoSearchProps
            if (b.index == 0) {
              b.from = this.textValue
              b.from_area_index = this.textIndex as number[]
            } else {
              b.to = this.textValue
              b.to_area_index = this.textIndex as number[]
            }
            router.back({ url: 'pages/ExpressInfoSearch', params: b })
          } else {
            // 网点查询
            const regex = /[\[\]",]/g
            // 去除 '[', ']', '"', ','
            let cleanedString = this.textValue.replace(regex, '');
            // 将空格替换为 '-'
            cleanedString = cleanedString.replace(/\s+/g, '-');

            Log.debug('正在查询网点：' + cleanedString + this.input)
            getExpNetwork({
              area: cleanedString,
              address: this.input,
              offset: 0
            }).then((result) => {
              Log.debug(`数据 ：${JSON.stringify(result)}`)
              router.pushUrl({
                url: 'pages/AreaListPage',
                params: result?.netList
              })
            })
          }


        })
    }.width('100%')
    .height('100%')
    .backgroundColor('#f6f4f5')
  }
}