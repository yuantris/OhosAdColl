import LoadingDialog from './LoadingDialog';
import { promptAction, router } from '@kit.ArkUI';
import { expCompany, expInfo } from '../entity/ExpBeans';
import { getBarCode, getCompanys, getExpInfo } from '../service/default';
import Constants from '../common/Constants';
import { SFExpressDialog } from './SFExpressDialog';
import Preference from '../common/util/Preference';
import { ExpressInfo } from '../common/entity/ExpressInfo';
import { pinyin4js } from '@ohos/pinyin4js';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { dataModel, listModel } from '../common/entity/BarCodeBean';
import { ObservedArray } from '../common/util/ObservedArray';
import { Dialog, JsonParser, Log } from '@zycore/common';
import { AdSwitchManager, ADHelper, BannerAdComponent, FeedAdComponent, GlobalAdLoadLogComponent } from '@zysdk/ad-core-hm';
import { LogManager } from '@zysdk/ad-core-hm/src/main/ets/ohos/helper/logger/LogManager';

class ExpressIcon {
  icon: Resource;
  company: expCompany

  constructor(icon: Resource, company: expCompany) {
    this.icon = icon;
    this.company = company
  }
}

function extractComValue(jsonStr: string): string | null {
  const regex = /"com"\s*:\s*"([^"]*)"/; // 匹配 "com": "value" 的格式
  const match = jsonStr.match(regex);
  return match ? match[1] : null;
}

function goExpressResult(value: string, json: string, loadingDialog: CustomDialogController, info: expInfo | null) {
  let companyList: Array<expCompany> = JsonParser.jsonToArray<expCompany>(value);
  const extractedCom = extractComValue(json);

  if (extractedCom) {
    const selectedCompany = companyList.find((item) => item.ccode === extractedCom);

    if (selectedCompany) {
      loadingDialog.close();
      router.pushUrl({
        url: 'pages/ExpressResult',
        params: {
          company: selectedCompany,
          info: info
        }
      });
    } else {
      Log.warn('No matching company found');
      loadingDialog.close();
      router.pushUrl({
        url: 'pages/ExpressResult',
        params: {
          company: new expCompany('未知快递', extractedCom, null),
          info: info
        }
      });
    }
  } else {
    Log.warn('Failed to extract company code from expressInfo');
  }
}

function getAd(oid: string, phone: string | null,
  loadingDialog: CustomDialogController): void {
  try {
    promptAction.showDialog({
      title: '提示',
      message: AdSwitchManager.isAdOpen ? '是否观看视频解锁查询单号' : "是否解锁查询单号",
      buttons: [
        {
          text: '取消',
          color: '#000000'
        },
        {
          text: '解锁',
          color: '#000000'
        }
      ]
    }, (err, data) => {
      if (err) {
        console.info('showDialog err: ' + err);
        return;
      }
      console.info('showDialog success callback, click button: ' + data.index);
      if (data.index == 0) {

      } else {
        ADHelper.getInstance().loadVideoAd('video', {
          onVideoComplete() {
            search(oid, phone, loadingDialog)
          },
          onVideoError(c, m) {
            setTimeout(() => {
              Dialog.showToast(m)
            }, 1000)
          },
          onVideoClick() {
            console.info('video click')
          },
          onVideoShow() {
            console.info('video show')
          },
        })
      }

    });
  } catch (error) {
    let message = (error as BusinessError).message
    let code = (error as BusinessError).code
    console.error(`showDialog args error code is ${code}, message is ${message}`);
  }
  ;

}

function search(oid: string, phone: string | null,
  loadingDialog: CustomDialogController): void {
  loadingDialog.open()

  getExpInfo(phone == null ? { oid: oid } : { oid: oid, tel: phone }).then(info => {
    let abc = JSON.stringify(info)

    Preference.getData(Constants.COMPANY).then((value) => {
      if (value) {
        goExpressResult(value, abc, loadingDialog, info)
      } else {
        getCompanys()
          .then(coms => {
            if (coms) {
              Log.debug(`companyList: ${JSON.stringify(coms)}`)

              const list = coms as expCompany[];

              // 排序公司列表，按拼音首字母排序
              list.sort((a, b) => {
                const a_pin = getFirstLetter(a.cname);
                const b_pin = getFirstLetter(b.cname);
                return a_pin.localeCompare(b_pin); // 使用 localeCompare 比较拼音首字母
              });

              const json = JSON.stringify(list);
              Preference.writeData(Constants.COMPANY, json);
              goExpressResult(json, abc, loadingDialog, info)
            }
          })
          .catch((error: object) => {
            Log.error(`Error: ${JSON.stringify(error)}`);
          });
      }
    });
  }).catch((err: string | Resource) => {
    loadingDialog.close()
  })
}

//条码查询后弹窗
@CustomDialog
struct goods_listDialog {
  @ObjectLink dataInfo: dataModel
  @ObjectLink goodsList: ObservedArray<listModel>
  dialogController?: CustomDialogController
  ToQuestion: () => void = () => {
  }

  build() {
    Column() {
      Text('商品详情')
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({
          top: 30
        })
      Row() {
        Row() {
          Column() {
            Image(this.dataInfo.img)
              .width(120)
              .borderRadius(20)
          }

          Column() {
            Text(this.dataInfo.goodsName)
            Text('¥' + this.dataInfo.price)
              .fontSize(20)
          }
          .height(120)
          .justifyContent(FlexAlign.SpaceAround)
          .margin({
            left: 15
          })
        }
      }
      .height(160)
      .width('100%')
      .margin({
        left: 30
      })

      List({
        space: 10
      }) {
        ForEach(this.goodsList, (item: listModel) => {
          ListItem() {
            Row() {
              Image(item.pictUrl)
                .width(100)
                .borderRadius(16)
                .margin({
                  left: 20
                })
              Column() {
                Text(item.title)
                  .width('60%')
                  .fontColor('#ff1c26e0')
                  .fontSize(12)
                Row() {
                  Text('¥' + item.zkFinalPrice)
                  Blank()
                    .layoutWeight(1)
                  Hyperlink('https:' + item.clickUrl, '  ' + '跳转链接' + '  ')
                    .color(Color.White)
                    .height(20)
                    .borderRadius(6)
                    .backgroundColor(Color.Orange)
                    .padding(4)
                }
                .width('50%')
              }
              .height(106)
              .justifyContent(FlexAlign.SpaceAround)
              .margin({
                left: 15
              })
            }.width('100%')
          }
          .backgroundColor('#e2f8f4f4')
          .borderRadius(10)
          .width('100%')
          .height(120)
        })
      }
      .contentEndOffset(50)
      .height('80%')
      .lanes(1)
    }
    .backgroundImage($r('app.media.express_bg'))
    .backgroundImageSize(ImageSize.Cover)
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.END])
  }
}

@Component
export default struct ExpressCheck {
  private typeList: Array<object> = [
    new ExpressInfo(Constants.TYPE_WAIT, $r('app.media.express_check_home_icon0')),
    new ExpressInfo(Constants.TYPE_ALL, $r('app.media.express_check_home_icon1')),
    new ExpressInfo(Constants.TYPE_HISTORY, $r('app.media.express_check_home_icon2')),
    new ExpressInfo(Constants.TYPE_PRICE, $r('app.media.index_pic_price')),
    new ExpressInfo(Constants.TYPE_AREA, $r('app.media.index_pic_search_branch')),
    new ExpressInfo(Constants.TYPE_TIME, $r('app.media.index_pic_search_time'))
  ]
  loadingDialog: CustomDialogController = new CustomDialogController({
    builder: LoadingDialog({ msg: '加载中...' }),
    alignment: DialogAlignment.Center,
    // offset: { dx: 0, dy: CommonConstants.DIALOG_CONTROLLER_DY_OFFSET },
    customStyle: true,
    autoCancel: false
  });
  @State textValue: string = ''
  sfDialog: CustomDialogController = new CustomDialogController({
    builder: SFExpressDialog({
      cancel: () => {
      },
      confirm: (phone: string) => {
        // 存入数据库
        Preference.writeData(this.oid, phone)
        //search(this.oid, phone, this.loadingDialog)
        getAd(this.oid, phone, this.loadingDialog)
      },
      textValue: $textValue,
    }),
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: -20 },
    gridCount: 4,
    customStyle: false,
    cornerRadius: 10
  });
  @Prop company: expCompany | null = null
  @State oid: string = ''
  private sPattern: RegExp = /^(?!^0)(?!^[a-zA-Z]+$)(?!^[0-9a-zA-Z]*?[0-9]+[a-zA-Z]+[0-9a-zA-Z]*$)[0-9a-zA-Z]{8,18}$/;
  //条码查询
  @State code: string = ''
  @State pageNum: number = 1
  @State pageSize: number = 30
  @State dataInfo: dataModel | undefined = undefined
  @State goodsList: ObservedArray<listModel> = new ObservedArray<listModel>([])
  listdialogController: CustomDialogController | null = new CustomDialogController({
    builder: goods_listDialog({
      dataInfo: this.dataInfo,
      goodsList: this.goodsList,
      ToQuestion: () => {
      }
    }),
    // cancel: this.existApp,
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    isModal: true,
    offset: { dx: 0, dy: 26 },
    // maskColor: '#da242323', //蒙层颜色
    customStyle: false,
    // cornerRadius: 20,
    width: '100%',
    height: '98%',
    backgroundColor: Color.White,
  })
  @State isRemove: boolean = false

  async get_code() {
    let options: scanBarcode.ScanOptions =
      { scanTypes: [scanCore.ScanType.ONE_D_CODE], enableMultiMode: false, enableAlbum: true };
    try {
      //等待查询完毕后弹出弹窗
      await scanBarcode.startScanForResult(getContext(this), options).then((result: scanBarcode.ScanResult) => {
        this.code = result.originalValue
        console.log('result', result.originalValue)
        this.loadingDialog.open()
        // hilog.info(0x0001, '[Scan Sample]',
        //   `Succeeded in getting ScanResult by promise with options, result is ${JSON.stringify(result)}`);
        getBarCode({
          code: this.code,
          pageNum: this.pageNum,
          pageSize: this.pageSize
        }).then((res) => {
          this.dataInfo = res?.data
          this.goodsList = res?.list as Array<listModel>
          console.log('data', this.dataInfo?.img)
          console.log('list', this.goodsList)
          this.listdialogController?.open()
          this.loadingDialog.close()
        })
      }).catch((error: BusinessError) => {
        hilog.error(0x0001, '[Scan Sample]',
          `Failed to get ScanResult by promise with options. Code: ${error.code}, message: ${error.message}`);
      });
    } catch (error) {
      hilog.error(0x0001, '[Scan Sample]',
        `Failed to startScanForResult. Code: ${error.code}, message: ${error.message}`);
    }

  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Row() {
            Blank()
            TextInput({ placeholder: '请输入快递单号' })
              .width('68%')
              .placeholderFont({ size: 13 })
              .height(px2vp(120))
              .onChange((value: string) => {
                this.oid = value
              })
              .onFocus(() => {
                console.info('获取焦点');
              })
              .backgroundColor(Color.White)
              .borderRadius(56)

            Image($r('app.media.express_check_express_check_bt')).fitOriginalSize(true)
              .onClick(() => {
                // if (Util.isEmpty(this.oid)) {
                //   Util.toast('请先输入快递单号')
                //   return
                // }
                this.oid = this.oid.replace(/[^0-9a-zA-Z]/g, '');
                // if (!this.sPattern.test(this.oid)) {
                //   Util.toast("快递单号格式有误，请检查确认后再次查询！");
                //   return;
                // }
                if (this.oid.toUpperCase().startsWith('SF')) {
                  // 顺丰
                  this.sfDialog.open()
                } else {
                  //search(this.oid, null, this.loadingDialog)
                  getAd(this.oid, null, this.loadingDialog)
                }
              })

          }
          .width('90%')
          .height(54)
          .backgroundImage($r('app.media.express_input_bg'))
          .backgroundImageSize(ImageSize.FILL)
          .padding({ right: 10 })
          .margin({ top: 50 })

          Row() {

            Image($r('app.media.index_pic_price'))
              .width('50%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .onClick(() => {
                router.pushUrl({ url: "pages/ExpressInfoSearch", params: { type: Constants.TYPE_PRICE } })
              })

            Column() {

              Image($r('app.media.express_check_home_icon1'))
                .width('100%')
                .height('50%')
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  router.pushUrl({ url: "pages/InfoPage", params: { type: Constants.TYPE_ALL } })
                })

              Image($r('app.media.express_check_home_tran'))
                .width('100%')
                .height('50%')
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  router.pushUrl({ url: "pages/InfoPage", params: { type: Constants.TYPE_TRAN } })
                })

            }.width('50%')
            .height('100%')

          }.width('90%')
          .margin({
            top: 15,
            bottom: 15
          })
          .layoutWeight(1)

        }.width('100%')
        .height(280)

        GlobalAdLoadLogComponent()

        // 横幅广告演示（华为AutoAdComponent，360*57）
        FeedAdComponent({
          adId: 'ban',
          uniqueId: 'express_banner',
          bgColor: Color.White,
          radius: 12
        })

        Column() {
          // 广告
          // AdLayout({
          //   adId: AD.CSJ_INFO_ID,
          //   adName: 'express_check',
          //   adType: AdType.INFO,
          //   bgColor: '#ff00ff',
          //   adWidth: '100%',
          // })
          FeedAdComponent({
            adId: 'info',
            uniqueId: "express_home",
            bgColor: Color.White,
            radius: 16,
            adWidth: '90%'
          })
          // .width('90%')
          // .backgroundColor(Color.Blue)


          Image($r('app.media.barcode_title'))
            .fitOriginalSize(true)
            .margin({ top: 15, left: 16 })
            .objectFit(ImageFit.Contain)

          Image($r('app.media.barcodescan'))
            .fitOriginalSize(true)
            .objectFit(ImageFit.Contain)
            .margin({ top: 15, left: '5%' })
            .width('90%')
            .onClick(() => {
              ADHelper.getInstance().loadVideoAd("video", {
                onVideoComplete: () => {
                  this.get_code()
                  LogManager.warn("激励视频", "onVideoComplete")
                },
                onVideoError: (code: number, msg: string) => {
                  LogManager.error("激励视频", `onVideoError: ${code}, ${msg}`)
                },
                onVideoClick: () => {
                  LogManager.warn("激励视频", "onVideoClick")
                },
                onVideoShow: () => {
                  LogManager.warn("激励视频", "onVideoShow")
                }
              })
            })

          Image($r('app.media.express_tool'))
            .fitOriginalSize(true)
            .margin({ top: 15, left: 16 })
            .objectFit(ImageFit.Contain)

          Row() {

            Column() {

              Image($r('app.media.express_check_home_psz'))
                .width('100%')
                .fitOriginalSize(true)
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  router.pushUrl({ url: "pages/InfoPage", params: { type: Constants.TYPE_SENDING } })
                })

              Image($r('app.media.express_check_home_yqs'))
                .width('100%')
                .fitOriginalSize(true)
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  router.pushUrl({ url: "pages/InfoPage", params: { type: Constants.TYPE_SIGN } })
                })

            }.width('50%')

            Column() {

              Image($r('app.media.express_check_home_wait'))
                .width('100%')
                .fitOriginalSize(true)
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  router.pushUrl({ url: "pages/InfoPage", params: { type: Constants.TYPE_WAIT } })
                })

              Image($r('app.media.express_check_home_back'))
                .width('100%')
                .fitOriginalSize(true)
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  router.pushUrl({ url: "pages/InfoPage", params: { type: Constants.TYPE_BACK } })
                })

            }.width('50%')
          }.width('100%')
          .padding({ top: 15, left: 16, right: 16 })

        }.width('100%')
        .padding({ top: 24 })
        .alignItems(HorizontalAlign.Center)

      }.width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundImage($r('app.media.express_bg'))
    .backgroundImageSize(ImageSize.FILL)
    .scrollBar(BarState.Off)

  }
}

function getFirstLetter(str: string | null): string {
  const validStr = str ?? ''; // 处理 null 情况
  if (!validStr.trim()) {
    return '';
  }

  return pinyin4js
    .convertToPinyinString(validStr, '', pinyin4js.FIRST_LETTER)
    .toUpperCase()
    .charAt(0);
}