import { TitleBar } from '../common/view/TitleBar'
import router from '@ohos.router'
import { ExpressBean } from '../common/entity/ExpressBean'
import RdbManager from '../common/zyhttp/RdbManager'
import Constants from '../common/Constants'
import { ExpressInfo } from '../common/entity/ExpressInfo'
import View from '../common/View'
import { DisplayUtils, Log } from '@zycore/common'

@Entry
@Component
struct InfoPage {
  @State info: ExpressInfo = router.getParams() as ExpressInfo
  @State private datas: Array<ExpressBean> | null = null

  onPageShow(): void {
    Log.debug(`当前type :${this.info.type}`)
    RdbManager.queryExpressBeans(this.info.type).then(result => {
      this.datas = result
    }).catch((error: object) => {
    })
  }

  build() {
    Column({ space: 10 }) {
      TitleBar({
        title: Constants.getTypeTitle(this.info.type)
      })

      RelativeContainer() {
        Image($r('app.media.express_check_express_empty'))
          .fitOriginalSize(true)
          .alignRules({
            middle: { anchor: View.container, align: HorizontalAlign.Center },
            center: { anchor: View.container, align: VerticalAlign.Center },
          })
          .visibility(this.datas == null || this.datas.length == 0 ? Visibility.Visible : Visibility.None)

        List() {
          ForEach(this.datas, (item: ExpressBean) => {
            ListItem() {
              Row() {
                Image(item.company.logo)
                  .width(60)
                  .borderRadius(12)
                  .objectFit(ImageFit.Contain)

                Column() {
                  Text(item.info.data[0].context + '')
                    .width('95%')
                    .textOverflow({ overflow: TextOverflow.Clip })
                    .maxLines(1)
                    .backgroundColor('#f2f2f2')
                    .borderRadius(12)
                    .padding({
                      top: 10,
                      bottom: 10,
                      left: 5,
                      right: 5
                    })

                  Text(item.company.cname)
                    .width('95%')
                    .margin({
                      top: 5
                    })
                }
                .width(px2vp(DisplayUtils.getWidth()) - 70)
                .layoutWeight(1)

              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({
                left: 16,
                right: 16
              })
              .margin({
                top: 10,
                bottom: 10
              })
            }
            .backgroundColor(Color.White)
            .margin('3%')
            .width('94%')
            .borderRadius(12)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ExpressResult',
                params: {
                  company: item.company,
                  info: item.info,
                  id: item.id
                }
              })
            })
          })
        }
        .width('100%')
        .height('100%')
        .visibility(this.datas == null || this.datas.length == 0 ? Visibility.None : Visibility.Visible)
      }

    }.backgroundColor('#f2f2f2')
    .width('100%')
    .height('100%')
  }
}