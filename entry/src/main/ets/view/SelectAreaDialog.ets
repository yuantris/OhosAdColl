import { Log, StrUtils } from '@zycore/common';
import city from '../../resources/rawfile/province.json';


@CustomDialog
@Component
export struct SelectAreaDialog {
  @Link textValue: string
  @Link textIndex: number | number[]
  controller?: CustomDialogController
  cancel: () => void = () => {
  }
  confirm: () => void = () => {
  }

  aboutToAppear(): void {
    Log.info('SelectAreaDialog aboutToAppear: ' + JSON.stringify(this.textIndex))
  }

  build() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button('取消')
          .onClick(() => {
            if (this.controller != undefined) {
              this.controller.close()
              this.textValue = ''
              this.cancel()
            }
          }).backgroundColor(0xffffff).fontColor(Color.Black)
        Text('选择地区').fontSize(14).margin({ top: 20, bottom: 20 })
        Button('确认')
          .onClick(() => {
            if (StrUtils.isBlank(this.textValue)) {
              this.textValue = '["北京市", "北京市", "东城区"]'
            }
            if (this.controller != undefined) {
              this.controller.close()
              this.confirm()
            }
          }).backgroundColor(0xffffff).fontColor(Color.Blue)
      }.margin({ bottom: 20, top: 20 })

      TextPicker({
        range: getCityList(),
        selected: this.textIndex,
      })
        .canLoop(false)
        .onChange((value: string | string[], index: number | number[]) => {
          this.textValue = JSON.stringify(value)
          this.textIndex = index
          Log.info(`TextPicker 多列联动:onChange
          ${JSON.stringify(value)},
          index: ${JSON.stringify(index)}`)
          if (typeof index !== 'number') {
            // index.forEach((item: number)=>{
            //   Log.info(`TextPicker 多列联动index: ${item}`)
            // })
          }
        })

    }.borderRadius(10)

    // 如果需要使用border属性或cornerRadius属性，请和borderRadius属性一起使用。
  }
}

function getCityList(): TextCascadePickerRangeContent[] {
  return city.map(province => ({
    text: province.name.endsWith('省') ? province.name.trim().substring(0, province.name.length - 1) :
    province.name.trim(),
    children: province.city.map(city => ({
      text: city.name.endsWith('市') ? city.name.trim().substring(0, city.name.length - 1) : city.name.trim(),
      children: city.area.map(area => ({ text: area.trim() }) as TextCascadePickerRangeContent)
    }) as TextCascadePickerRangeContent)
  }) as TextCascadePickerRangeContent)
}