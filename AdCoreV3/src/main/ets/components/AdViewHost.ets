import { AdNativeMaterial, AdViewHandle } from '../core/AdViewTypes';

/**
 * Public rendering modes for the unified ArkUI ad host.
 * ProviderView means the vendor's own component/node is supplied by providerContent.
 * SelfRender means the host lays out the returned material.
 */
export enum AdViewKind {
  Banner = 'banner',
  Feed = 'feed',
  SelfRender = 'self_render'
}

/**
 * One ArkUI host for Banner, provider-rendered Feed, and self-rendered native ads.
 *
 * Lifecycle is intentionally format-aware:
 * - Banner: the provider component owns load/refresh/close behavior. The host only
 *   forwards appearance callbacks and does not call handle.mount()/destroy().
 * - Feed: the host mounts the already-loaded view handle and destroys it when detached.
 * - SelfRender: material is rendered by this component; handle is optional and follows
 *   the same host-owned cleanup policy as Feed.
 *
 * Vendor-specific ArkUI nodes are injected through providerContent, keeping SDK types
 * out of the public V3 API.
 */
@ComponentV2
export struct AdViewHost {
  @Require @Param kind: AdViewKind;
  @Param material: AdNativeMaterial | null = null;
  @Param handle: AdViewHandle | null = null;
  @Param width: Length = '100%';
  @Param height: Length = 'auto';
  @Param radius: Length = 0;
  @Param backgroundColor: ResourceColor = Color.Transparent;
  @Param showAdLabel: boolean = true;
  @Param onBannerAppear: (() => void) | undefined = undefined;
  @Param onBannerDisappear: (() => void) | undefined = undefined;
  @Param onHostError: ((message: string) => void) | undefined = undefined;

  @BuilderParam providerContent: () => void = this.emptyProviderContent;

  @Builder
  private emptyProviderContent(): void {
    Column() {}
      .width('100%')
      .height(0)
  }

  aboutToAppear(): void {
    if (this.kind === AdViewKind.Banner) {
      // Banner SDK components own their load/refresh lifecycle.
      this.onBannerAppear?.();
      return;
    }
    if (this.kind === AdViewKind.Feed && this.handle !== null) {
      this.handle.mount().catch((error: Error) => {
        this.onHostError?.(error.message);
      });
    }
  }

  aboutToDisappear(): void {
    if (this.kind === AdViewKind.Banner) {
      this.onBannerDisappear?.();
      return;
    }
    // Feed/native views are owned by the host slot and must release when detached.
    this.handle?.destroy();
  }

  build(): void {
    Column() {
      if (this.kind === AdViewKind.SelfRender) {
        this.buildSelfRenderedMaterial();
      } else if (this.kind === AdViewKind.Feed && this.handle?.nodeController !== null && this.handle?.nodeController !== undefined) {
        NodeContainer(this.handle.nodeController)
          .width('100%')
          .borderRadius(this.radius)
          .backgroundColor(this.backgroundColor);
      } else {
        this.providerContent();
      }
    }
    .width(this.width)
    .height(this.height)
    .backgroundColor(this.backgroundColor)
    .borderRadius(this.radius)
    .clip(true)
  }

  @Builder
  private buildSelfRenderedMaterial(): void {
    if (this.material !== null) {
      Column({ space: 8 }) {
        if (this.material.iconUrl.length > 0 || this.material.title.length > 0) {
          Row({ space: 8 }) {
            if (this.material.iconUrl.length > 0) {
              Image(this.material.iconUrl)
                .width(44)
                .height(44)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
            }
            Column({ space: 3 }) {
              if (this.material.title.length > 0) {
                Text(this.material.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              if (this.material.description.length > 0) {
                Text(this.material.description)
                  .fontSize(13)
                  .fontColor('#777777')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }

        if (this.material.imageUrls.length > 0) {
          Image(this.material.imageUrls[0])
            .width('100%')
            .constraintSize({ minHeight: 120, maxHeight: 260 })
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
        }

        Row() {
          if (this.showAdLabel) {
            Text('广告')
              .fontSize(10)
              .fontColor('#777777')
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .border({ width: 1, color: '#BBBBBB', radius: 3 })
          }
          Blank()
          if (this.material.callToAction.length > 0) {
            Text(this.material.callToAction)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#2878FF')
              .borderRadius(6)
          }
        }
        .width('100%')
      }
      .padding(12)
      .width('100%')
    } else {
      Column() {
        Text('广告素材暂不可用')
          .fontSize(13)
          .fontColor('#888888')
      }
      .width('100%')
      .padding(16)
    }
  }
}
