export { AwsS3, AwsS3InitOptions } from './src/main/ets/s3/AwsS3Helper';
export { checkBucketName, checkKey, isNotFoundFileMetadata } from './src/main/ets/s3/AwsS3Check';
export { generatePresignedUrl, encodeKeyPath, hmacSha1Base64 } from './src/main/ets/s3/AwsS3Presign';
export { AwsCannedAcl, AWS_ACL_PRIVATE, AWS_ACL_PUBLIC_READ, AWS_ACL_PUBLIC_READ_WRITE,
  AWS_ACL_AUTHENTICATED_READ, AwsTimeUnit, toMillis, AWS_ERR_PARAM, AWS_ERR_FILE, AWS_ERR_INIT,
  AWS_ERR_NETWORK, AwsError, AwsBucketNameException, AwsKeyException, AwsNotInitException,
  AwsBaseCallback, AwsProgressCallback, AwsHeadResult, AwsObjectSummary, AwsListResult } from './src/main/ets/s3/AwsS3Types';
