import { IDataSourcePrefetching } from '@kit.ArkUI';

export abstract class AbstractDataSourcePrefetching<T> implements IDataSourcePrefetching {
  private readonly items: Array<T> = [];
  private readonly listeners: DataChangeListener[] = [];

  public abstract prefetch(index: number): void | Promise<void>;

  public totalCount(): number {
    return this.items.length;
  }

  public getData(index: number): T {
    return this.items[index];
  }

  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  public addData(index: number, data: T): void {
    this.items.splice(index, 0, data);
    this.notifyDataAdd(index);
  }

  public pushData(data: T): void {
    this.items.push(data);
    this.notifyDataAdd(this.items.length - 1);
  }

  public removeData(data: T): void {
    const index = this.items.indexOf(data);
    if (index >= 0) {
      this.items.splice(index, 1); // 从 items 数组中移除数据
      this.notifyDataDelete(index);
    }
  }

  public notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  public notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  public notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  public notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  public notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    });
  }

  public notifyDatasetChange(operations: DataOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operations);
    });
  }
}
