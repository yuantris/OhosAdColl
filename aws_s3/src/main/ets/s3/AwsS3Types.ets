/**
 * @zycore/aws-s3 类型与常量定义
 * 对齐 Android 侧 AwsHelper.java（com.by.zhangying.adhelper.helper）公开 API 语义
 */

/** Canned ACL（对齐 Java CannedAccessControlList 常用项，BSCStorage 兼容） */
export type AwsCannedAcl = 'private' | 'public-read' | 'public-read-write' | 'authenticated-read';

export const AWS_ACL_PRIVATE: AwsCannedAcl = 'private';
export const AWS_ACL_PUBLIC_READ: AwsCannedAcl = 'public-read';
export const AWS_ACL_PUBLIC_READ_WRITE: AwsCannedAcl = 'public-read-write';
export const AWS_ACL_AUTHENTICATED_READ: AwsCannedAcl = 'authenticated-read';

/** 有效期时间单位（对齐 Java TimeUnit 用法） */
export enum AwsTimeUnit {
  MS = 0,
  SECONDS = 1,
  MINUTES = 2,
  HOURS = 3,
  DAYS = 4
}

/** 有效期换算毫秒；unit 缺省或 expires <= 0 时返回默认 7 天（对齐 Java 侧默认值） */
export function toMillis(expires: number, unit?: AwsTimeUnit): number {
  const DEFAULT_SEVEN_DAYS = 7 * 24 * 60 * 60 * 1000;
  if (unit === undefined || expires <= 0) {
    return DEFAULT_SEVEN_DAYS;
  }
  switch (unit) {
    case AwsTimeUnit.SECONDS:
      return expires * 1000;
    case AwsTimeUnit.MINUTES:
      return expires * 60 * 1000;
    case AwsTimeUnit.HOURS:
      return expires * 60 * 60 * 1000;
    case AwsTimeUnit.DAYS:
      return expires * 24 * 60 * 60 * 1000;
    case AwsTimeUnit.MS:
    default:
      return expires;
  }
}

/** 错误码（对齐 Java 侧 -1 语义，细分便于定位） */
export const AWS_ERR_PARAM = -3000;
export const AWS_ERR_FILE = -3001;
export const AWS_ERR_INIT = -3002;
export const AWS_ERR_NETWORK = -3003;

/** 基础异常（对齐 Java AwsException） */
export class AwsError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(message);
    this.name = 'AwsError';
    this.code = code;
  }
}

/** bucket 名不合法（对齐 Java BucketNameException） */
export class AwsBucketNameException extends AwsError {
  constructor(message: string) {
    super(AWS_ERR_PARAM, message);
    this.name = 'AwsBucketNameException';
  }
}

/** key 不合法（对齐 Java KeyException） */
export class AwsKeyException extends AwsError {
  constructor(message: string) {
    super(AWS_ERR_PARAM, message);
    this.name = 'AwsKeyException';
  }
}

/** 客户端未初始化 */
export class AwsNotInitException extends AwsError {
  constructor(message: string) {
    super(AWS_ERR_INIT, message);
    this.name = 'AwsNotInitException';
  }
}

/** 基础回调（对齐 Java OnBaseCallback<T>） */
export interface AwsBaseCallback<T> {
  onSuccess: (bean: T) => void;
  onError: (code: number, err: AwsError) => void;
}

/** 带进度回调（对齐 Java OnProgressCallback<T>；SDK 无传输进度事件，进度为 0/1 折算） */
export interface AwsProgressCallback<T> extends AwsBaseCallback<T> {
  onProgress?: (percent: number) => void;
}

/** HeadObject 结果（对齐 Java ObjectMetadata 常用字段） */
export interface AwsHeadResult {
  exists: boolean;
  contentLength?: number;
  contentType?: string;
  eTag?: string;
  lastModified?: string;
  metadata?: Record<string, string>;
}

/** 列举对象条目 */
export interface AwsObjectSummary {
  key: string;
  size: number;
  lastModified: string;
  eTag: string;
}

/** 列举结果（对齐 Java ObjectListing 常用字段） */
export interface AwsListResult {
  objects: AwsObjectSummary[];
  isTruncated: boolean;
  nextToken?: string;
}
