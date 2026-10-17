import { rcp } from '@kit.RemoteCommunicationKit';

/**
 * 请求耗时派生指标(由官方 rcp.TimeInfo 计算而来)
 * 官方 TimeInfo 语义: 首包耗时 = startTransferTimeMs - preTransferTimeMs;
 * TLS 耗时 = tlsHandshakeTimeMs - connectTimeMs(TLS 握手计时包含 TCP 建连)
 */
export interface ZyTimeMetrics {
  /** DNS 解析耗时(ms) */
  dnsMs: number;
  /** TCP 建连耗时(ms) */
  connectMs: number;
  /** TLS 握手耗时(ms, 已扣除 TCP 建连部分) */
  tlsMs: number;
  /** 首包耗时(ms, 官方口径 startTransfer - preTransfer) */
  firstByteMs: number;
  /** 剩余接收耗时(ms, total - startTransfer) */
  recvRemainMs: number;
  /** 总耗时(ms) */
  totalMs: number;
}

/**
 * 自定义 DNS 服务器(官方 rcp.IpAndPort: ip + 可选 port)
 */
export interface ZyDnsServer {
  ip: string;
  port?: number;
}

/**
 * 静态 DNS 规则(官方 StaticDnsRule: hostname 匹配则优先使用指定地址)
 */
export interface ZyStaticDnsRule {
  host: string;
  port: number;
  ipAddresses: string[];
}

/**
 * DNS 配置(映射官方 rcp.DnsConfiguration.dnsRules 三选一联合类型)
 * 官方 dnsRules 为 DnsServers | StaticDnsRules | DynamicDnsRule 三选一,
 * 本层用 mode 显式声明采用的规则形态, 避免隐式联合推断歧义:
 * - 'servers': 自定义 DNS 服务器解析(对应 DnsServers)
 * - 'static': 静态规则 hostname 匹配直连(对应 StaticDnsRules)
 * - 'dynamic': 动态函数返回地址(对应 DynamicDnsRule, 官方签名 (host, port) => IpAddress[])
 */
export interface ZyDnsConfig {
  mode: 'servers' | 'static' | 'dynamic';
  /** mode='servers' 时生效 */
  servers?: ZyDnsServer[];
  /** mode='static' 时生效 */
  staticRules?: ZyStaticDnsRule[];
  /** mode='dynamic' 时生效 */
  dynamicRule?: (host: string, port: number) => string[];
}

/**
 * 安全配置(映射官方 rcp.SecurityConfiguration 子集)
 * - remoteValidation: 证书校验策略; 'skip' 表示跳过服务端证书校验(仅限开发测试)
 * - tlsVersion: TLS 版本(官方 tlsOptions 联合类型中的 TlsVxxOption 分支, 官方字面量: 'TlsV1.0'~'TlsV1.3')
 * - certificatePinning: 证书锁定(官方 Certificate Pinning: 证书公钥 SHA256 哈希 BASE64 编码限定可信证书范围)
 */
export interface ZySecurityConfig {
  remoteValidation?: 'system' | 'skip';
  tlsVersion?: 'TlsV1.3' | 'TlsV1.2' | 'TlsV1.1' | 'TlsV1.0';
  certificatePinning?: rcp.CertificatePinning;
}

/**
 * 由官方 rcp.TimeInfo 计算派生耗时指标
 * 官方 TimeInfo 七个字段(nameLookup/connect/tlsHandshake/preTransfer/startTransfer/total/redirect)全为必填,
 * 但部分设备可能返回 undefined, 统一按 0 兜底; 派生值为负时按 0 截断
 * @param t 官方时间信息
 * @returns 派生指标
 */
export function computeTimeMetrics(t: rcp.TimeInfo): ZyTimeMetrics {
  const orZero = (v: number | undefined): number => v !== undefined ? v : 0;
  const dnsMs = orZero(t.nameLookupTimeMs);
  const connectMs = orZero(t.connectTimeMs);
  const tlsMs = orZero(t.tlsHandshakeTimeMs) - connectMs;
  const firstByteMs = orZero(t.startTransferTimeMs) - orZero(t.preTransferTimeMs);
  const recvRemainMs = orZero(t.totalTimeMs) - orZero(t.startTransferTimeMs);
  return {
    dnsMs: dnsMs,
    connectMs: connectMs,
    tlsMs: tlsMs > 0 ? tlsMs : 0,
    firstByteMs: firstByteMs > 0 ? firstByteMs : 0,
    recvRemainMs: recvRemainMs > 0 ? recvRemainMs : 0,
    totalMs: orZero(t.totalTimeMs)
  };
}

/**
 * 翻译 DNS 配置为官方 rcp.DnsConfiguration(按 mode 显式三选一)
 * 官方 dnsRules 为 DnsServers | StaticDnsRules | DynamicDnsRule 联合,
 * 逐分支构造, 避免对联合类型直接赋字段导致的编译错误
 * @param dns ZyNet DNS 配置
 * @returns rcp.DnsConfiguration
 */
export function translateDnsConfig(dns: ZyDnsConfig): rcp.DnsConfiguration {
  const dnsConfig: rcp.DnsConfiguration = {};
  if (dns.mode === 'servers' && dns.servers !== undefined) {
    // 官方 DnsServers = IpAndPort[], ZyDnsServer 结构与官方一致
    dnsConfig.dnsRules = dns.servers;
  } else if (dns.mode === 'static' && dns.staticRules !== undefined) {
    // 官方 StaticDnsRules = StaticDnsRule[], 成员为 {host, port, ipAddresses}
    dnsConfig.dnsRules = dns.staticRules;
  } else if (dns.mode === 'dynamic' && dns.dynamicRule !== undefined) {
    // 官方 DynamicDnsRule = (host, port) => IpAddress[]
    dnsConfig.dnsRules = (host: string, port: number): string[] => dns.dynamicRule!(host, port);
  }
  return dnsConfig;
}

/**
 * 翻译安全配置为官方 rcp.SecurityConfiguration
 * 官方 tlsOptions 为 'system' | CipherSuite[] | TlsVxxOption 联合,
 * ZySecurityConfig.tlsVersion 映射为官方 TlsV13Option/TlsV12Option/TlsV11Option/TlsV10Option 字面量对象
 * @param security ZyNet 安全配置
 * @returns rcp.SecurityConfiguration
 */
export function translateSecurityConfig(security: ZySecurityConfig): rcp.SecurityConfiguration {
  const securityConfig: rcp.SecurityConfiguration = {};
  if (security.remoteValidation !== undefined) {
    securityConfig.remoteValidation = security.remoteValidation;
  }
  if (security.tlsVersion !== undefined) {
    // 官方 TlsVxxOption: { tlsVersion: 'TlsV1.3' | 'TlsV1.2' | 'TlsV1.1' | 'TlsV1.0' }
    const tlsOption: rcp.TlsV13Option | rcp.TlsV12Option | rcp.TlsV11Option | rcp.TlsV10Option =
      { tlsVersion: security.tlsVersion };
    securityConfig.tlsOptions = tlsOption;
  }
  if (security.certificatePinning !== undefined) {
    securityConfig.certificatePinning = security.certificatePinning;
  }
  return securityConfig;
}
