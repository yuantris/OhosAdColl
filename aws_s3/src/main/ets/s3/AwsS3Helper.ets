/**
 * @zycore/aws-s3 门面类
 * 对齐 Android 侧 AwsHelper.java 公开方法；与 Java 版差异：
 * 1. 必填参数（context/AK/SK）不再从服务端拉取（GetKHelper），改由门面 init() 传入
 * 2. 底层由 AWS Android SDK 换为 @ohos/aws-sdk-client-s3（AWS SDK JS v3 鸿蒙移植，SigV4）
 * 3. presigned URL 为自实现 SigV2 查询签名（SDK 未移植 s3-request-presigner），与 Java 旧版 SDK 行为一致
 * 4. 下载无 TransferUtility 断点续传，为一次性拉取（transformToByteArray 后落盘）
 */
import { S3Client, S3ClientConfig, HeadObjectCommand, PutObjectCommand,
  GetObjectCommand, DeleteObjectCommand, ListObjectsV2Command } from '@ohos/aws-sdk-client-s3';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { AwsCannedAcl, AWS_ACL_PRIVATE, AwsTimeUnit, toMillis, AwsError, AwsNotInitException,
  AWS_ERR_PARAM, AWS_ERR_FILE, AWS_ERR_NETWORK, AwsBaseCallback, AwsProgressCallback,
  AwsHeadResult, AwsListResult, AwsObjectSummary } from './AwsS3Types';
import { checkBucketName, checkKey, isNotFoundFileMetadata } from './AwsS3Check';
import { generatePresignedUrl } from './AwsS3Presign';

/** 初始化配置：必填参数经门面传入 */
export interface AwsS3InitOptions {
  /** UIAbility/应用 Context（S3Client 鸿蒙版构造必传） */
  context: common.Context;
  /** AccessKeyId */
  accessKeyId: string;
  /** SecretAccessKey */
  secretAccessKey: string;
  /** 服务端点，默认 http://ss.bscstorage.com（对齐 Java sEndpoint） */
  endpoint?: string;
  /** region，SigV4 签名用；BSCStorage 不校验，默认 cn-north-1（对齐 Java Regions.CN_NORTH_1） */
  region?: string;
  /** path-style 访问，默认 true（对齐 Java setPathStyleAccess(true)） */
  forcePathStyle?: boolean;
}

/** bucket/key 校验结果 */
interface AwsParamPair {
  bucket: string;
  key: string;
}

/** 默认端点（对齐 Java sEndpoint 的 byte 混淆值） */
const DEFAULT_ENDPOINT = 'http://ss.bscstorage.com';
/** 默认 region（对齐 Java Regions.CN_NORTH_1） */
const DEFAULT_REGION = 'cn-north-1';

/**
 * S3 工具库门面（单例）
 * 用法：
 *   AwsS3.getInstance().init({ context, accessKeyId, secretAccessKey, endpoint? });
 *   const url = await AwsS3.getInstance().uploadFile(path, bucket, key);
 */
export class AwsS3 {
  private static instance?: AwsS3;
  private client?: S3Client;
  private options?: AwsS3InitOptions;

  private constructor() {
  }

  static getInstance(): AwsS3 {
    if (AwsS3.instance === undefined) {
      AwsS3.instance = new AwsS3();
    }
    return AwsS3.instance;
  }

  /** bucket 校验透出（对齐 Java 静态方法；try-catch 包裹规避 ArkTSCheck may-throw 告警） */
  static checkBucketName(bucketName: string): string {
    try {
      return checkBucketName(bucketName);
    } catch (e) {
      throw toParamError(e, 'BUCKET NAME ERROR');
    }
  }

  /** key 校验透出（对齐 Java 静态方法；try-catch 包裹规避 ArkTSCheck may-throw 告警） */
  static checkKey(key: string): string {
    try {
      return checkKey(key);
    } catch (e) {
      throw toParamError(e, 'KEY ERROR');
    }
  }

  /**
   * 初始化客户端（重复调用会重建客户端，用于切换 AK/SK/endpoint）
   * @throws AwsError 参数缺失
   */
  init(options: AwsS3InitOptions): void {
    if (options.context === undefined || options.context === null) {
      throw new AwsError(-3000, 'context is required.');
    }
    if (options.accessKeyId === undefined || options.accessKeyId.length === 0
      || options.secretAccessKey === undefined || options.secretAccessKey.length === 0) {
      throw new AwsError(-3000, 'accessKeyId / secretAccessKey is required.');
    }
    const config: S3ClientConfig = {
      region: options.region !== undefined && options.region.length > 0 ? options.region : DEFAULT_REGION,
      credentials: {
        accessKeyId: options.accessKeyId,
        secretAccessKey: options.secretAccessKey
      },
      endpoint: options.endpoint !== undefined && options.endpoint.length > 0 ? options.endpoint : DEFAULT_ENDPOINT,
      forcePathStyle: options.forcePathStyle !== undefined ? options.forcePathStyle : true
    };
    this.client = new S3Client(options.context, config);
    this.options = options;
  }

  /** 已初始化的客户端；未初始化抛 AwsNotInitException（对齐 Java getAmazonS3 返回 null 的强约束版） */
  getClient(): S3Client {
    if (this.client === undefined) {
      throw new AwsNotInitException('AwsS3 not initialized, call init() first.');
    }
    return this.client;
  }

  /** 是否已初始化（对齐 Java getAmazonS3 判 null 场景） */
  isInitialized(): boolean {
    return this.client !== undefined;
  }

  /** 当前配置的端点 */
  getEndpoint(): string {
    if (this.options !== undefined && this.options.endpoint !== undefined && this.options.endpoint.length > 0) {
      return this.options.endpoint;
    }
    return DEFAULT_ENDPOINT;
  }

  /**
   * 上传沙箱文件（对齐 Java uploadFile(File, ...)）
   * @param filePath 应用沙箱内文件路径
   * @param bucketName bucket
   * @param keyPathFile 对象 key
   * @param callback 可选回调（onProgress 为 0/1 折算，SDK 无传输进度事件）
   * @param acl Canned ACL，默认 private（对齐 Java 默认 Private）
   * @param urlExpires presigned URL 有效期，默认 7 天
   * @param unit 有效期单位
   * @returns presigned URL
   */
  async uploadFile(filePath: string, bucketName: string, keyPathFile: string,
    callback?: AwsProgressCallback<string>, acl?: AwsCannedAcl,
    urlExpires?: number, unit?: AwsTimeUnit): Promise<string> {
    const param = this.validateParams(bucketName, keyPathFile, callback);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    let bytes: Uint8Array;
    try {
      bytes = readFileToBytes(filePath);
    } catch (e) {
      this.notifyError(callback, AWS_ERR_FILE, toError(e, 'FILE ERROR'));
      throw toError(e, 'FILE ERROR');
    }
    return this.uploadBytes(bytes, finalBucket, finalKey, callback, acl, urlExpires, unit);
  }

  /**
   * 上传字节数组（对齐 Java uploadInputStream(InputStream, ...)）
   * @returns presigned URL
   */
  async uploadBytes(bytes: Uint8Array, bucketName: string, keyPathFile: string,
    callback?: AwsProgressCallback<string>, acl?: AwsCannedAcl,
    urlExpires?: number, unit?: AwsTimeUnit): Promise<string> {
    const param = this.validateParams(bucketName, keyPathFile, callback);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    if (bytes === undefined || bytes === null || bytes.length === 0) {
      const err = new AwsError(AWS_ERR_FILE, 'INPUT BYTES ERROR');
      this.notifyError(callback, AWS_ERR_FILE, err);
      throw err;
    }
    if (callback !== undefined && callback.onProgress !== undefined) {
      callback.onProgress(0);
    }
    const client = this.getClient();
    try {
      await client.send(new PutObjectCommand({
        Bucket: finalBucket,
        Key: finalKey,
        Body: bytes,
        ACL: acl !== undefined ? acl : AWS_ACL_PRIVATE
      }));
    } catch (e) {
      const err = toError(e, 'PUT OBJECT ERROR');
      this.notifyError(callback, AWS_ERR_NETWORK, err);
      throw err;
    }
    if (callback !== undefined && callback.onProgress !== undefined) {
      callback.onProgress(1);
    }
    const url = this.presign(finalBucket, finalKey, urlExpires, unit);
    if (callback !== undefined) {
      callback.onSuccess(url);
    }
    return url;
  }

  /**
   * 获取带签名下载链接（对齐 Java getFilePresignedUrl；默认 7 天）
   * @throws AwsNotInitException 未初始化
   */
  getFilePresignedUrl(bucketName: string, keyPathFile: string,
    urlExpires?: number, unit?: AwsTimeUnit): string {
    const param = this.validateParams(bucketName, keyPathFile);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    if (this.client === undefined) {
      throw new AwsNotInitException('AwsS3 not initialized, call init() first.');
    }
    return this.presign(finalBucket, finalKey, urlExpires, unit);
  }

  /**
   * 获取文件元数据（对齐 Java getFileMetadata）
   * @throws 404 时抛出 S3ServiceException（可用 isNotFoundFileMetadata 判断）
   */
  async getFileMetadata(bucketName: string, keyPathFile: string): Promise<AwsHeadResult> {
    const param = this.validateParams(bucketName, keyPathFile);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    const client = this.getClient();
    const res = await client.send(new HeadObjectCommand({ Bucket: finalBucket, Key: finalKey }));
    const result: AwsHeadResult = {
      exists: true,
      contentLength: res.ContentLength,
      contentType: res.ContentType,
      eTag: res.ETag,
      lastModified: res.LastModified !== undefined ? res.LastModified.toUTCString() : undefined,
      metadata: res.Metadata as Record<string, string> | undefined
    };
    return result;
  }

  /**
   * 列举文件（对齐 Java listObjects(bucket, prefix) 单页行为）
   * @param keyPath 前缀
   * @param maxKeys 单页上限，默认 1000
   */
  async listFiles(bucketName: string, keyPath: string, maxKeys?: number): Promise<AwsListResult> {
    const param = this.validateParams(bucketName, keyPath);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    const client = this.getClient();
    const res = await client.send(new ListObjectsV2Command({
      Bucket: finalBucket,
      Prefix: finalKey,
      MaxKeys: maxKeys !== undefined ? maxKeys : 1000
    }));
    const objects: AwsObjectSummary[] = [];
    const contents = res.Contents;
    if (contents !== undefined) {
      for (let i = 0; i < contents.length; i++) {
        const item = contents[i];
        objects.push({
          key: item.Key !== undefined ? item.Key : '',
          size: item.Size !== undefined ? item.Size : 0,
          lastModified: item.LastModified !== undefined ? item.LastModified.toUTCString() : '',
          eTag: item.ETag !== undefined ? item.ETag : ''
        });
      }
    }
    const result: AwsListResult = {
      objects: objects,
      isTruncated: res.IsTruncated !== undefined ? res.IsTruncated : false,
      nextToken: res.NextContinuationToken
    };
    return result;
  }

  /**
   * 删除文件（对齐 Java deleteFile：不存在返回 0，删除成功返回 1）
   */
  async deleteFile(bucketName: string, keyPathFile: string): Promise<number> {
    const param = this.validateParams(bucketName, keyPathFile);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    const client = this.getClient();
    try {
      await client.send(new HeadObjectCommand({ Bucket: finalBucket, Key: finalKey }));
    } catch (e) {
      if (isNotFoundFileMetadata(e as object)) {
        return 0;
      }
      throw toError(e, 'HEAD OBJECT ERROR');
    }
    await client.send(new DeleteObjectCommand({ Bucket: finalBucket, Key: finalKey }));
    return 1;
  }

  /**
   * 下载文件到沙箱路径（对齐 Java downloadFile；无断点续传，一次性拉取）
   * @param targetPath 目标文件路径（父目录不存在会自动创建）
   * @param callback 可选回调（onProgress 为 0/1 折算）
   * @returns 目标文件路径
   */
  async downloadFile(targetPath: string, bucketName: string, keyPathFile: string,
    callback?: AwsProgressCallback<string>): Promise<string> {
    const param = this.validateParams(bucketName, keyPathFile, callback);
    const finalBucket = param.bucket;
    const finalKey = param.key;
    if (callback !== undefined && callback.onProgress !== undefined) {
      callback.onProgress(0);
    }
    const client = this.getClient();
    let bytes: Uint8Array;
    try {
      const res = await client.send(new GetObjectCommand({ Bucket: finalBucket, Key: finalKey }));
      if (res.Body === undefined || res.Body === null) {
        throw new AwsError(AWS_ERR_NETWORK, 'EMPTY BODY');
      }
      bytes = await res.Body.transformToByteArray();
    } catch (e) {
      const err = toError(e, 'GET OBJECT ERROR');
      this.notifyError(callback, AWS_ERR_NETWORK, err);
      throw err;
    }
    try {
      writeBytesToFile(targetPath, bytes);
    } catch (e) {
      const err = toError(e, 'FILE ERROR');
      this.notifyError(callback, AWS_ERR_FILE, err);
      throw err;
    }
    if (callback !== undefined && callback.onProgress !== undefined) {
      callback.onProgress(1);
    }
    if (callback !== undefined) {
      callback.onSuccess(targetPath);
    }
    return targetPath;
  }

  /** SigV2 查询签名 URL（内部统一入口） */
  private presign(bucket: string, key: string, urlExpires?: number, unit?: AwsTimeUnit): string {
    const expiresMillis = toMillis(urlExpires !== undefined ? urlExpires : 0, unit);
    const ak = this.options !== undefined ? this.options.accessKeyId : '';
    const sk = this.options !== undefined ? this.options.secretAccessKey : '';
    return generatePresignedUrl(ak, sk, this.getEndpoint(), bucket, key, expiresMillis);
  }

  private notifyError<T>(callback: AwsBaseCallback<T> | undefined, code: number, err: AwsError): void {
    if (callback !== undefined) {
      callback.onError(code, err);
    }
  }

  /**
   * bucket/key 校验统一入口（内部 try-catch 包裹，规避 ArkTSCheck "Function may throw exceptions" 告警）
   * 校验失败：先回调 onError（code 取异常 code），再抛出原异常（AwsBucketNameException/AwsKeyException 原样透传）
   */
  private validateParams(bucketName: string, key: string,
    callback?: AwsBaseCallback<string>): AwsParamPair {
    let finalBucket: string;
    let finalKey: string;
    try {
      finalBucket = checkBucketName(bucketName);
      finalKey = checkKey(key);
    } catch (e) {
      const err = toParamError(e, 'PARAM ERROR');
      this.notifyError(callback, err.code, err);
      throw err;
    }
    const pair: AwsParamPair = { bucket: finalBucket, key: finalKey };
    return pair;
  }
}

/** 读沙箱文件为 Uint8Array（一次性读入，大文件注意内存） */
function readFileToBytes(filePath: string): Uint8Array {
  if (!fs.accessSync(filePath)) {
    throw new AwsError(AWS_ERR_FILE, `file not found: ${filePath}`);
  }
  const stat = fs.statSync(filePath);
  if (!stat.isFile()) {
    throw new AwsError(AWS_ERR_FILE, `not a file: ${filePath}`);
  }
  const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
  try {
    const buf = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buf);
    return new Uint8Array(buf);
  } finally {
    fs.closeSync(file);
  }
}

/** 写 Uint8Array 到沙箱文件（父目录自动创建，覆盖写） */
function writeBytesToFile(targetPath: string, bytes: Uint8Array): void {
  const parent = targetPath.substring(0, targetPath.lastIndexOf('/'));
  if (parent.length > 0 && !fs.accessSync(parent)) {
    fs.mkdirSync(parent, true);
  }
  const file = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, bytes);
  } finally {
    fs.closeSync(file);
  }
}

/** 异常归一化（统一收敛为 AwsError，规避 Error 子类→Error 参数的结构化类型检查） */
function toError(e: object | undefined, fallback: string): AwsError {
  if (e instanceof AwsError) {
    return e;
  }
  const msg = e instanceof Error ? e.message : (e !== undefined && e !== null ? JSON.stringify(e) : '');
  return new AwsError(AWS_ERR_NETWORK, msg.length > 0 ? `${fallback}: ${msg}` : fallback);
}

/** 参数校验异常归一化（checkBucketName/checkKey 仅抛 AwsError 子类，原样透传；兜底转 AwsError） */
function toParamError(e: object | undefined, fallback: string): AwsError {
  if (e instanceof AwsError) {
    return e;
  }
  return new AwsError(AWS_ERR_PARAM, fallback);
}
