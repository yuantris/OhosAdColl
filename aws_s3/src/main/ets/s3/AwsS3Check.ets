/**
 * bucket/key 校验（逐行对齐 Java AwsHelper.checkBucketName / checkKey / isNotFondFileMetadata）
 */
import { AwsBucketNameException, AwsKeyException } from './AwsS3Types';

/** 对齐 Java PATTERN_BUCKET：^[a-z]$|^[a-z][a-z0-9-]*[a-z0-9]$ */
const PATTERN_BUCKET = /^[a-z]$|^[a-z][a-z0-9-]*[a-z0-9]$/;

/** key 最大长度（对齐 Java 512） */
const MAX_KEY_LENGTH = 512;

/**
 * 校验并规范化 bucket 名：去除首尾 '/'，需满足小写字母开头、仅含小写/数字/'-'、不以 '-' 结尾
 * @throws AwsBucketNameException
 */
export function checkBucketName(bucketName: string): string {
  let name = bucketName;
  if (name === null || name === undefined || name.length === 0) {
    throw new AwsBucketNameException('bucket name is null.');
  }
  while (true) {
    if (name.startsWith('/')) {
      name = name.substring(1);
      continue;
    } else if (name.endsWith('/')) {
      name = name.substring(0, name.length - 1);
      continue;
    }
    break;
  }
  if (PATTERN_BUCKET.test(name)) {
    return name;
  }
  throw new AwsBucketNameException('bucket name is unuseful.');
}

/**
 * 校验并规范化 key：去除首尾 '/'，长度 1-512
 * @throws AwsKeyException
 */
export function checkKey(key: string): string {
  let k = key;
  if (k === null || k === undefined) {
    throw new AwsKeyException('key is null.');
  }
  while (true) {
    if (k.startsWith('/')) {
      k = k.substring(1);
      continue;
    } else if (k.endsWith('/')) {
      k = k.substring(0, k.length - 1);
      continue;
    }
    break;
  }
  if (k.length > 0 && k.length <= MAX_KEY_LENGTH) {
    return k;
  }
  throw new AwsKeyException('key is unuseful.');
}

/**
 * 判断异常是否为"文件不存在"（对齐 Java isNotFondFileMetadata：AmazonS3Exception 且 statusCode == 404）
 * 鸿蒙 SDK 对应 S3ServiceException.$metadata.httpStatusCode
 */
export function isNotFoundFileMetadata(err: object | undefined | null): boolean {
  if (err === null || err === undefined) {
    return false;
  }
  const status = (err as Record<string, Object>)['$metadata'] as Record<string, Object> | undefined;
  if (status !== undefined && status !== null) {
    const code = status['httpStatusCode'];
    if (typeof code === 'number' && code === 404) {
      return true;
    }
  }
  return false;
}
