import { AdComponent, advertising } from "@kit.AdsKit";

export class AdParams {
  ads: Array<advertising.Advertisement> = [{
    adType: -1
  } as advertising.Advertisement]
  options: advertising.AdDisplayOptions | undefined = undefined

  constructor(ads: Array<advertising.Advertisement>, options: advertising.AdDisplayOptions) {
    this.ads = ads;
    this.options = options;
  }
}

@Builder
export function buildHwAd(params: AdParams) {
  Column() {
    ForEach(params.ads, (ad: advertising.Advertisement) => {
      AdComponent({
        ads: [ad],
        displayOptions: params.options,
        interactionListener: {
          onStatusChanged: (status: string, ad: advertising.Advertisement, data: string) => {
            switch (status) {
              case 'onAdOpen':
                // Prompt.showToast({
                //   message: 'native ad open',
                //   duration: 1000
                // });
                break;
              case 'onAdClick':
                // Prompt.showToast({
                //   message: 'native ad click',
                //   duration: 1000
                // });
                break;
              case 'onAdClose':
                // Prompt.showToast({
                //   message: 'native ad close',
                //   duration: 1000
                // });
                // this.hwAdCallback()
                break;
            }
          }
        }
      })
        .width('100%')
    })

  }
}