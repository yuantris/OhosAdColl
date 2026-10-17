// API 收敛：baseUrl 改为 const 默认值，运行期修改统一走 NetBasic.baseUrl=
export const DEFAULT_BASE_URL = 'https://api.zyapp.net.cn'
export const V4: string[] = ['/zy/v1/app/ad/status/v4', 'r_a_a_uuid_v_c']
export const V5: string[] = ['/zy/v1/app/ad/status/v5', 'r_v_a_uuid_v_c']
/** 需注入 it 头的路径前缀（V4 等） */
export const INJECT_IT_PATHS: string[] = [V4[0]]