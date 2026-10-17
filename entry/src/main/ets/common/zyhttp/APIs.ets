
export class APIs {
  /// url 前缀
  static readonly BASE_Url: string = 'https://api.zyapp.net.cn'
  static readonly Test_Url: string = 'http://192.168.0.3:9092'
  static readonly V3: string[] = ['/zy/v1/app/ad/status/v3','r_a_c_uuid_v']
  static readonly V4: string[] = ['/zy/v1/app/ad/status/v4','r_a_a_uuid_v_c']

  static readonly company: string[] = ['/zy/v1/app/exp/allCompany','rtype_sid_aid_vid_uuid']
  static readonly price: string[] = ['/zy/v1/app/exp/getP','rtype_sid_com_send_aid_vid_uuid']
  static readonly network: string[] = ['/zy/v1/app/exp/getSNetwork','rtype_sid_area_aid_vid_uuid']
  static readonly ttl: string[] = ['/zy/v1/app/exp/getTL','rtype_sid_aid_from_to_vid_uuid']
  static readonly info: string[] = ['/zy/v1/app/exp/query','r_uuid_a_v_uuid']
  static readonly barcode: string[] = ['/zy/v1/app/exp/barcode','rtype_sid_aid_vid_code_uuid']
}
