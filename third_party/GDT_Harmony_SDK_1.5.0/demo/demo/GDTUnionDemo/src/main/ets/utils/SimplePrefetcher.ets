import { IDataSourcePrefetching, IPrefetcher } from '@kit.ArkUI';

export class SimplePrefetcher implements IPrefetcher {
  private dataSource: IDataSourcePrefetching;
  private readonly prefetchSize: number;

  public constructor(dataSource: IDataSourcePrefetching, prefetchSize: number) {
    this.dataSource = dataSource;
    this.prefetchSize = prefetchSize;
    this.dataSource.prefetch(prefetchSize);
  }

  public setDataSource(dataSource: IDataSourcePrefetching): void {
    this.dataSource = dataSource;
  }

  public visibleAreaChanged(minVisible: number, maxVisible: number): void {
    this.dataSource.prefetch(maxVisible + this.prefetchSize);
  }
}
