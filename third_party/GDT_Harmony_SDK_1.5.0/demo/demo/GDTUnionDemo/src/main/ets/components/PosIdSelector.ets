class PosIdMenuItemContentModifier implements ContentModifier<MenuItemConfiguration> {
  private readonly _posIdArr: Array<[string, string]> = [];

  public get posIdArr(): Array<[string, string]> {
    return this._posIdArr;
  }

  public constructor(posIdArr: Array<[string, string]>) {
    this._posIdArr = posIdArr;
  }

  public applyContent(): WrappedBuilder<[MenuItemConfiguration]> {
    return wrapBuilder(MenuItemBuilder);
  }
}

@Builder
function MenuItemBuilder(configuration: MenuItemConfiguration) {
  Row() {
    Text((configuration.contentModifier as PosIdMenuItemContentModifier).posIdArr[configuration.index][0])
      .fontWeight(configuration.selected ? FontWeight.Bold : FontWeight.Normal)
    Blank(20)
    Text((configuration.contentModifier as PosIdMenuItemContentModifier).posIdArr[configuration.index][1])
      .fontWeight(configuration.selected ? FontWeight.Bold : FontWeight.Normal)
  }
  .height(56)
  .margin({ left: 20, right: 20 })
  .onClick(() => {
    configuration.triggerSelect(configuration.index, configuration.value.valueOf().toString());
  })
}

@ComponentV2
export struct PosIdSelector {
  @Param posIdArr: Array<[string, string]> = [];
  @Param posId: string = '';
  @Event $posId: (val: string) => void = (val: string) => {};
  @Local selectText: string = this.getSelectText(this.posIdArr, this.posId);
  @Local index: number = this.getIndex(this.posIdArr, this.posId);

  private getSelectOptions(posIdArr: Array<[string, string]>): Array<SelectOption> {
    const selectOptions: Array<SelectOption> = [];
    for (let i = 0; i < posIdArr.length; i++) {
      selectOptions.push({ value: posIdArr[i][1] });
    }
    return selectOptions;
  }

  private getIndex(posIdArr: Array<[string, string]>, posId: string): number {
    for (let i = 0; i < posIdArr.length; i++) {
      if (posIdArr[i][0] === posId) {
        return i;
      }
    }
    return -1;
  }

  private getSelectText(posIdArr: Array<[string, string]>, posId: string): string {
    for (let i = 0; i < posIdArr.length; i++) {
      if (posIdArr[i][0] === posId) {
        return posIdArr[i][1];
      }
    }
    return '自定义';
  }

  build() {
    Column() {
      TextInput({ placeholder: '广告位ID', text: this.posId })
        .showUnderline(true)
        .onChange((value) => {
          this.$posId(value);
          this.index = this.getIndex(this.posIdArr, value);
          this.selectText = this.getSelectText(this.posIdArr, value);
        })
      Select(this.getSelectOptions(this.posIdArr))
        .value(this.selectText)
        .selected(this.index)
        .onSelect((index: number, text?: string | undefined) => {
          this.index = index;
          this.$posId(this.posIdArr[index][0]);
          this.selectText = this.getSelectText(this.posIdArr, this.posIdArr[index][0]);
        })
        .menuItemContentModifier(new PosIdMenuItemContentModifier(this.posIdArr))
        .width('100%')
        .margin({ bottom: 10 })
        .borderRadius(0)
        .backgroundColor('#FFFFFFFF')
    }
    .width('100%')
  }
}
