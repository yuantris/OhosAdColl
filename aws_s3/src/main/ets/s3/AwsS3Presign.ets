/**
 * AWS Signature V2 查询串签名（presigned URL）
 * 对齐 Java 侧 AmazonS3.generatePresignedUrl（旧版 SDK 走 SigV2 查询签名）：
 *   stringToSign = "GET\n\n\n{ExpiresEpoch}\n/{bucket}/{encodedKey}"
 *   Signature = Base64(HMAC-SHA1(secretKey, stringToSign))
 *   URL = {endpoint}/{bucket}/{encodedKey}?Expires={epoch}&AWSAccessKeyId={ak}&Signature={sig}
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

/** RFC3986 保留字符集之外的字符不转义 */
const RFC3986_UNRESERVED = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/**
 * key 路径编码（RFC3986 严格集，逐字节处理，'/' 保留）
 * 对齐任务A OhosRcp.ets bscEncodeKeyPath 语义
 */
export function encodeKeyPath(key: string): string {
  const encoder = new util.TextEncoder();
  const bytes = encoder.encodeInto(key);
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i];
    const ch = String.fromCharCode(b);
    if (b < 0x80 && RFC3986_UNRESERVED.indexOf(ch) >= 0) {
      out += ch;
    } else if (ch === '/') {
      out += '/';
    } else {
      out += '%' + b.toString(16).toUpperCase().padStart(2, '0');
    }
  }
  return out;
}

/** HMAC-SHA1 签名后 Base64（cryptoFramework 同步 API） */
export function hmacSha1Base64(secretKey: string, stringToSign: string): string {
  const mac = cryptoFramework.createMac('SHA1');
  const generator = cryptoFramework.createSymKeyGenerator('HMAC');
  const keyBlob: cryptoFramework.DataBlob = { data: new util.TextEncoder().encodeInto(secretKey) };
  const symKey = generator.convertKeySync(keyBlob);
  mac.initSync(symKey);
  mac.updateSync({ data: new util.TextEncoder().encodeInto(stringToSign) });
  const out: cryptoFramework.DataBlob = mac.doFinalSync();
  return new util.Base64Helper().encodeToStringSync(out.data);
}

/**
 * 生成带签名的下载 URL（SigV2 查询签名）
 * @param accessKeyId AK
 * @param secretAccessKey SK
 * @param endpoint 服务端点（如 http://ss.bscstorage.com，末尾 '/' 会被去除）
 * @param bucketName 已校验的 bucket
 * @param keyPathFile 已校验的 key
 * @param expiresMillis 有效期毫秒数（从现在起）
 */
export function generatePresignedUrl(accessKeyId: string, secretAccessKey: string,
  endpoint: string, bucketName: string, keyPathFile: string, expiresMillis: number): string {
  let ep = endpoint;
  while (ep.endsWith('/')) {
    ep = ep.substring(0, ep.length - 1);
  }
  const encodedKey = encodeKeyPath(keyPathFile);
  const expiresEpoch = Math.floor((Date.now() + expiresMillis) / 1000);
  const stringToSign = `GET\n\n\n${expiresEpoch}\n/${bucketName}/${encodedKey}`;
  const signature = hmacSha1Base64(secretAccessKey, stringToSign);
  return `${ep}/${bucketName}/${encodedKey}` +
    `?Expires=${expiresEpoch}&AWSAccessKeyId=${encodeURIComponent(accessKeyId)}` +
    `&Signature=${encodeURIComponent(signature)}`;
}
