package com.by.zhangying.adhelper.helper;

import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.event.ProgressEvent;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferListener;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferObserver;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState;
import com.amazonaws.mobileconnectors.s3.transferutility.TransferUtility;
import com.amazonaws.regions.Region;
import com.amazonaws.regions.Regions;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.S3ClientOptions;
import com.amazonaws.services.s3.model.AmazonS3Exception;
import com.amazonaws.services.s3.model.CannedAccessControlList;
import com.amazonaws.services.s3.model.ObjectListing;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.by.zhangying.adhelper.ADHelper;
import com.by.zhangying.adhelper.https.entity.GetK;
import com.by.zhangying.adhelper.util.ADUtil;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.Date;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

import io.reactivex.Scheduler;
import io.reactivex.android.schedulers.AndroidSchedulers;
import io.reactivex.schedulers.Schedulers;

/**
 * @description: 密钥管理，cdn管理
 * @author: isLxz
 * @date: 2023/3/29 9:11
 */
public class AwsHelper {

    private Scheduler mScheduler = Schedulers.io();

    private final GetKHelper mGetKHelper;

    /**
     * AmazonS3
     */
    private AmazonS3 mAmazonS3;
    public static String sEndpoint = new String(new byte[]{104, 116, 116, 112, 58, 47, 47, 115,
            115, 46, 98, 115, 99, 115, 116, 111, 114, 97, 103, 101, 46, 99, 111, 109});
    private TransferUtility mTransferUtility;

    private AwsHelper() {
        mGetKHelper = GetKHelper.getInstance("5");
    }

    private static final class AwsHelperInstance {
        private static final AwsHelper INSTANCE = new AwsHelper();
    }

    public static AwsHelper getInstance() {
        return AwsHelperInstance.INSTANCE;
    }

    public GetKHelper getGetKHelper() {
        return mGetKHelper;
    }

    /**
     * 获取AmazonS3
     *
     * @return
     */
    public AmazonS3 getAmazonS3() {
        if (mGetKHelper.getKey() == null) {
            return null;
        }
        return mAmazonS3;
    }

    public TransferUtility getTransferUtility() {
        if (mGetKHelper.getKey() == null) {
            return null;
        }
        return mTransferUtility;
    }

    /**
     * 检查获取AmazonS3
     *
     * @param callback
     */
    public void initAmazonS3(OnBaseCallback<AmazonS3> callback) {
        initAmazonS3(callback, null);
    }

    /**
     * 检查获取AmazonS3
     *
     * @param callback
     * @param observeOn
     */
    public void initAmazonS3(OnBaseCallback<AmazonS3> callback, Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            AmazonS3 amazonS3 = getAmazonS3();
            if (amazonS3 != null) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onSuccess(amazonS3));
                }
                return;
            }
            mGetKHelper.initKey(new GetKHelper.OnBaseCallback<GetK>() {
                @Override
                public void onSuccess(GetK bean) {
                    try {
                        GetK.Data data = bean.getData().get(0);
                        BasicAWSCredentials awsCredentials = new BasicAWSCredentials(data.getApiKey(), data.getSecretKey());
                        mAmazonS3 = new AmazonS3Client(awsCredentials, Region.getRegion(Regions.CN_NORTH_1));
                        mAmazonS3.setEndpoint(ADUtil.isBlank(data.getPoint()) ? sEndpoint : data.getPoint());
                        mAmazonS3.setS3ClientOptions(S3ClientOptions.builder()
                                .setPathStyleAccess(true)
//                        .disableChunkedEncoding()
                                .build());
                        mTransferUtility = TransferUtility.builder()
                                .context(ADHelper.getContext())
                                .s3Client(mAmazonS3)
                                .build();
                    } catch (Exception e) {
                        onError(-1, e);
                        return;
                    }
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onSuccess(mAmazonS3));
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                    }
                }
            }, mScheduler);
        });
    }

    /**
     * 上传文件
     *
     * @param sourceFile
     * @param bucketName
     * @param keyPathFile
     * @param callback
     */
    public void uploadFile(File sourceFile, String bucketName, String keyPathFile, OnProgressCallback<String> callback) {
        uploadFile(sourceFile, bucketName, keyPathFile, null, callback, null);
    }

    /**
     * 上传文件
     *
     * @param sourceFile
     * @param bucketName
     * @param keyPathFile
     * @param cannedAccessControlList
     * @param callback
     * @param observeOn
     */
    public void uploadFile(File sourceFile, String bucketName, String keyPathFile, CannedAccessControlList cannedAccessControlList,
                           OnProgressCallback<String> callback, Scheduler observeOn) {
        uploadFile(sourceFile, bucketName, keyPathFile, cannedAccessControlList, 0, null,
                callback, observeOn);
    }

    /**
     * 上传文件
     *
     * @param sourceFile
     * @param bucketName
     * @param keyPathFile
     * @param cannedAccessControlList
     * @param urlExpires
     * @param urlExpiresUnit
     * @param callback
     * @param observeOn
     */
    public void uploadFile(File sourceFile, String bucketName, String keyPathFile, CannedAccessControlList cannedAccessControlList,
                           long urlExpires, TimeUnit urlExpiresUnit, OnProgressCallback<String> callback, Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            try {
                if (!(sourceFile.exists() && sourceFile.isFile() && sourceFile.canRead())) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, new Exception("FILE ERROR")));
                    return;
                }
            } catch (SecurityException e) {
                e.printStackTrace();
                finalObserveOn.scheduleDirect(() -> callback.onError(-1, e));
                return;
            }
            final String finalBucketName, finalKeyPathFile;
            try {
                finalBucketName = checkBucketName(bucketName);
                finalKeyPathFile = checkKey(keyPathFile);
            } catch (AwsException awsException) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, awsException));
                }
                return;
            }
            //文件长度，code，已传输长度，进度1
            final long[] progress = new long[]{sourceFile.length(), 0, 0};
            final float[] percent = new float[1];
            initAmazonS3(new OnBaseCallback<AmazonS3>() {
                @Override
                public void onSuccess(AmazonS3 bean) {
                    final URL url;
                    try {
                        PutObjectRequest request = new PutObjectRequest(finalBucketName, finalKeyPathFile, sourceFile)
                                .withCannedAcl(cannedAccessControlList == null
                                        ? CannedAccessControlList.Private : cannedAccessControlList)
                                .withGeneralProgressListener(progressEvent -> {
                                    switch (progressEvent.getEventCode()) {
                                        case ProgressEvent.STARTED_EVENT_CODE:
                                            if (progress[1] == 0) {
                                                progress[1] = ProgressEvent.STARTED_EVENT_CODE;
                                            }
                                            break;
                                        case 0:
                                            if (progress[1] == ProgressEvent.STARTED_EVENT_CODE) {
                                                progress[2] += progressEvent.getBytesTransferred();
                                                float fileLength = progress[0];
                                                float current = progress[2];
                                                float temp = current / Math.max(fileLength, current);
                                                if (temp >= 1) {
                                                    temp = percent[0] + (1 - percent[0]) / 2;
                                                }
                                                percent[0] = temp;
                                                if (callback != null) {
                                                    finalObserveOn.scheduleDirect(() -> callback.onProgress(percent[0]));
                                                }
                                            }
                                            break;
                                        case ProgressEvent.COMPLETED_EVENT_CODE:
                                            if (progress[1] == ProgressEvent.STARTED_EVENT_CODE) {
                                                progress[1] = ProgressEvent.COMPLETED_EVENT_CODE;
                                                if (percent[0] < 1) {
                                                    percent[0] = 1;
                                                    if (callback != null) {
                                                        finalObserveOn.scheduleDirect(() -> callback.onProgress(1));
                                                    }
                                                }
                                            }
                                            break;
                                    }
                                });
                        bean.putObject(request);
                        if (percent[0] < 1) {
                            percent[0] = 1;
                            if (callback != null) {
                                finalObserveOn.scheduleDirect(() -> callback.onProgress(1));
                            }
                        }
                        url = bean.generatePresignedUrl(finalBucketName, finalKeyPathFile,
                                new Date(System.currentTimeMillis()
                                        + ((urlExpiresUnit == null || urlExpires <= 0) ? TimeUnit.DAYS.toMillis(7)
                                        : urlExpiresUnit.toMillis(urlExpires))));
//                    URL url = bean.getUrl(finalBucketName, finalKeyPathFile);
                    } catch (Exception e) {
                        onError(-1, e);
                        return;
                    }
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onSuccess(url == null ? "" : url.toString()));
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                    }
                }
            }, mScheduler);
        });
    }

    /**
     * 上传文件
     *
     * @param inputStream
     * @param objectMetadata
     * @param bucketName
     * @param keyPathFile
     * @param cannedAccessControlList
     * @param urlExpires
     * @param urlExpiresUnit
     * @param callback
     * @param observeOn
     */
    public void uploadInputStream(InputStream inputStream, ObjectMetadata objectMetadata, String bucketName, String keyPathFile, CannedAccessControlList cannedAccessControlList,
                                  long urlExpires, TimeUnit urlExpiresUnit, OnProgressCallback<String> callback, Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            try {
                if (inputStream == null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, new Exception("INPUT STREAM ERROR")));
                    return;
                }
            } catch (SecurityException e) {
                e.printStackTrace();
                finalObserveOn.scheduleDirect(() -> callback.onError(-1, e));
                return;
            }
            final String finalBucketName, finalKeyPathFile;
            try {
                finalBucketName = checkBucketName(bucketName);
                finalKeyPathFile = checkKey(keyPathFile);
            } catch (AwsException awsException) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, awsException));
                }
                return;
            }
            //文件长度，code，已传输长度，进度1
            final long[] progress = new long[3];
//            try {
//                progress[0] = inputStream.available();
//            } catch (IOException e) {
//                progress[0] = 0;
//            }
            final float[] percent = new float[1];
            initAmazonS3(new OnBaseCallback<AmazonS3>() {
                @Override
                public void onSuccess(AmazonS3 bean) {
                    final URL url;
                    try {
                        PutObjectRequest request = new PutObjectRequest(finalBucketName, finalKeyPathFile, inputStream, objectMetadata)
                                .withCannedAcl(cannedAccessControlList == null
                                        ? CannedAccessControlList.Private : cannedAccessControlList)
                                .withGeneralProgressListener(progressEvent -> {
                                    switch (progressEvent.getEventCode()) {
                                        case ProgressEvent.STARTED_EVENT_CODE:
                                            if (progress[1] == 0) {
                                                progress[1] = ProgressEvent.STARTED_EVENT_CODE;
                                            }
                                            break;
                                        case 0:
                                            if (progress[1] == ProgressEvent.STARTED_EVENT_CODE) {
                                                progress[2] += progressEvent.getBytesTransferred();
                                                float fileLength = progress[0];
                                                float current = progress[2];
                                                float temp = current / Math.max(fileLength, current);
                                                if (temp >= 1) {
                                                    temp = percent[0] + (1 - percent[0]) / 2;
                                                }
                                                percent[0] = temp;
                                                if (callback != null) {
                                                    finalObserveOn.scheduleDirect(() -> callback.onProgress(percent[0]));
                                                }
                                            }
                                            break;
                                        case ProgressEvent.COMPLETED_EVENT_CODE:
                                            if (progress[1] == ProgressEvent.STARTED_EVENT_CODE) {
                                                progress[1] = ProgressEvent.COMPLETED_EVENT_CODE;
                                                if (percent[0] < 1) {
                                                    percent[0] = 1;
                                                    if (callback != null) {
                                                        finalObserveOn.scheduleDirect(() -> callback.onProgress(1));
                                                    }
                                                }
                                            }
                                            break;
                                    }
                                });
                        bean.putObject(request);
                        if (percent[0] < 1) {
                            percent[0] = 1;
                            if (callback != null) {
                                finalObserveOn.scheduleDirect(() -> callback.onProgress(1));
                            }
                        }
                        url = bean.generatePresignedUrl(finalBucketName, finalKeyPathFile,
                                new Date(System.currentTimeMillis()
                                        + ((urlExpiresUnit == null || urlExpires <= 0) ? TimeUnit.DAYS.toMillis(7)
                                        : urlExpiresUnit.toMillis(urlExpires))));
//                    URL url = bean.getUrl(finalBucketName, finalKeyPathFile);
                    } catch (Exception e) {
                        onError(-1, e);
                        return;
                    }
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onSuccess(url == null ? "" : url.toString()));
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                    }
                }
            }, mScheduler);
        });
    }

    /**
     * 获取文件下载链接（带密钥，可直接访问加密文件）
     *
     * @param bucketName
     * @param keyPathFile
     * @return
     */
    public String getFilePresignedUrl(String bucketName, String keyPathFile) {
        return getFilePresignedUrl(bucketName, keyPathFile, 0, null);
    }

    /**
     * 获取文件下载链接（带密钥，可直接访问加密文件）
     *
     * @param bucketName
     * @param keyPathFile
     * @param urlExpires
     * @param urlExpiresUnit
     * @return
     */
    public String getFilePresignedUrl(String bucketName, String keyPathFile, long urlExpires, TimeUnit urlExpiresUnit) {
        if (mAmazonS3 == null) {
            return null;
        }
        try {
            bucketName = checkBucketName(bucketName);
        } catch (AwsException e) {
            e.printStackTrace();
            return null;
        }
        try {
            keyPathFile = checkKey(keyPathFile);
        } catch (AwsException e) {
            e.printStackTrace();
            return null;
        }
        URL url = mAmazonS3.generatePresignedUrl(bucketName, keyPathFile,
                new Date(System.currentTimeMillis()
                        + ((urlExpiresUnit == null || urlExpires <= 0) ? TimeUnit.DAYS.toMillis(7)
                        : urlExpiresUnit.toMillis(urlExpires))));
        return url == null ? "" : url.toString();
    }

    /**
     * 获取文件Metadata
     *
     * @param bucketName
     * @param keyPathFile
     * @param callback
     */
    public void getFileMetadata(String bucketName, String keyPathFile, OnBaseCallback<ObjectMetadata> callback) {
        getFileMetadata(bucketName, keyPathFile, callback, null);
    }

    /**
     * 获取文件Metadata
     *
     * @param bucketName
     * @param keyPathFile
     * @param callback
     * @param observeOn
     */
    public void getFileMetadata(String bucketName, String keyPathFile, OnBaseCallback<ObjectMetadata> callback, Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            final String finalBucketName, finalKeyPathFile;
            try {
                finalBucketName = checkBucketName(bucketName);
                finalKeyPathFile = checkKey(keyPathFile);
            } catch (AwsException awsException) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, awsException));
                }
                return;
            }
            initAmazonS3(new OnBaseCallback<AmazonS3>() {
                @Override
                public void onSuccess(AmazonS3 bean) {
                    final ObjectMetadata objectMetadata;
                    try {
                        objectMetadata = bean.getObjectMetadata(finalBucketName, finalKeyPathFile);
                    } catch (Exception e) {
                        onError(-1, e);
                        return;
                    }
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onSuccess(objectMetadata));
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                    }
                }
            }, mScheduler);
        });
    }

    /**
     * 获取文件列表
     *
     * @param bucketName
     * @param keyPath
     * @param callback
     */
    public void listFiles(String bucketName, String keyPath, OnBaseCallback<ObjectListing> callback) {
        listFiles(bucketName, keyPath, callback, null);
    }

    /**
     * 获取文件列表
     *
     * @param bucketName
     * @param keyPath
     * @param callback
     * @param observeOn
     */
    public void listFiles(String bucketName, String keyPath, OnBaseCallback<ObjectListing> callback, Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            final String finalBucketName, finalKeyPathFile;
            try {
                finalBucketName = checkBucketName(bucketName);
                finalKeyPathFile = checkKey(keyPath);
            } catch (AwsException awsException) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, awsException));
                }
                return;
            }
            initAmazonS3(new OnBaseCallback<AmazonS3>() {
                @Override
                public void onSuccess(AmazonS3 bean) {
                    final ObjectListing objectListing;
                    try {
                        objectListing = bean.listObjects(finalBucketName, finalKeyPathFile);
                    } catch (Exception e) {
                        onError(-1, e);
                        return;
                    }
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onSuccess(objectListing));
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                    }
                }
            }, mScheduler);
        });
    }

    /**
     * 删除文件
     *
     * @param bucketName
     * @param keyPathFile
     * @param callback
     */
    public void deleteFile(String bucketName, String keyPathFile, OnBaseCallback<Integer> callback) {
        deleteFile(bucketName, keyPathFile, callback, null);
    }

    /**
     * 删除文件
     *
     * @param bucketName
     * @param keyPathFile
     * @param callback
     * @param observeOn
     */
    public void deleteFile(String bucketName, String keyPathFile, OnBaseCallback<Integer> callback, Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            final String finalBucketName, finalKeyPathFile;
            try {
                finalBucketName = checkBucketName(bucketName);
                finalKeyPathFile = checkKey(keyPathFile);
            } catch (AwsException awsException) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, awsException));
                }
                return;
            }
            getFileMetadata(finalBucketName, finalKeyPathFile, new OnBaseCallback<ObjectMetadata>() {
                @Override
                public void onSuccess(ObjectMetadata bean) {
                    try {
                        mAmazonS3.deleteObject(finalBucketName, finalKeyPathFile);
                    } catch (Exception e) {
                        onError(-1, e);
                        return;
                    }
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onSuccess(1));
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        if (isNotFondFileMetadata(e)) {
                            finalObserveOn.scheduleDirect(() -> callback.onSuccess(0));
                        } else {
                            finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                        }
                    }
                }
            }, mScheduler);
        });
    }

    /**
     * 下载文件
     *
     * @param targetFile
     * @param bucketName
     * @param keyPathFile
     * @param callback
     */
    public void downloadFile(File targetFile, String bucketName, String keyPathFile, OnProgressCallback<File> callback) {
        downloadFile(targetFile, bucketName, keyPathFile, callback, null);
    }

    /**
     * 下载文件
     *
     * @param targetFile
     * @param bucketName
     * @param keyPathFile
     * @param callback
     * @param observeOn
     */
    public void downloadFile(File targetFile, String bucketName, String keyPathFile, OnProgressCallback<File> callback,
                             Scheduler observeOn) {
        final Scheduler finalObserveOn = observeOn == null ? AndroidSchedulers.mainThread() : observeOn;
        mScheduler.scheduleDirect(() -> {
            try {
                if (!targetFile.exists()) {
                    if (!targetFile.getParentFile().exists()) {
                        targetFile.getParentFile().mkdirs();
                    }
                    targetFile.createNewFile();
                }
                if (targetFile.isDirectory() || !targetFile.canWrite()) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, new Exception("FILE ERROR")));
                    return;
                }
                if (targetFile.exists()) {
                    targetFile.delete();
                }
            } catch (SecurityException | IOException e) {
                e.printStackTrace();
                finalObserveOn.scheduleDirect(() -> callback.onError(-1, e));
                return;
            }
            final String finalBucketName, finalKeyPathFile;
            try {
                finalBucketName = checkBucketName(bucketName);
                finalKeyPathFile = checkKey(keyPathFile);
            } catch (AwsException awsException) {
                if (callback != null) {
                    finalObserveOn.scheduleDirect(() -> callback.onError(-1, awsException));
                }
                return;
            }
            getFileMetadata(finalBucketName, finalKeyPathFile, new OnBaseCallback<ObjectMetadata>() {
                @Override
                public void onSuccess(ObjectMetadata bean) {
                    try {
                        TransferObserver download = mTransferUtility.download(finalBucketName, finalKeyPathFile, targetFile, new TransferListener() {
                            @Override
                            public void onStateChanged(int id, TransferState state) {
                                switch (state) {
                                    case PAUSED:
                                        if (callback != null) {
                                            finalObserveOn.scheduleDirect(() -> callback.onPaused());
                                        }
                                        break;
                                    case RESUMED_WAITING:
                                        if (callback != null) {
                                            finalObserveOn.scheduleDirect(() -> callback.onResumed());
                                        }
                                        break;
                                    case CANCELED:
                                        if (callback != null) {
                                            finalObserveOn.scheduleDirect(() -> callback.onCanceled());
                                        }
                                        break;
                                    case COMPLETED://下载完成
                                        if (callback != null) {
                                            finalObserveOn.scheduleDirect(() -> callback.onSuccess(targetFile));
                                        }
                                        break;
                                }
                            }

                            @Override
                            public void onProgressChanged(int id, long bytesCurrent, long bytesTotal) {
                                if (callback != null) {
                                    finalObserveOn.scheduleDirect(() -> callback.onProgress(bytesCurrent / bytesTotal));
                                }
                            }

                            @Override
                            public void onError(int id, Exception ex) {
                                onError(-1, ex);
                            }
                        });
                        if (callback != null) {
                            finalObserveOn.scheduleDirect(() -> callback.bindTransfer(new TransferBridge() {
                                @Override
                                public void pause() {
                                    mScheduler.scheduleDirect(() -> mTransferUtility.pause(download.getId()));
                                }

                                @Override
                                public void resume() {
                                    mScheduler.scheduleDirect(() -> mTransferUtility.resume(download.getId()));
                                }

                                @Override
                                public void cancel() {
                                    mScheduler.scheduleDirect(() -> mTransferUtility.cancel(download.getId()));
                                }
                            }));
                        }
                    } catch (Exception e) {
                        onError(-1, e);
                    }
                }

                @Override
                public void onError(int code, Throwable e) {
                    if (callback != null) {
                        finalObserveOn.scheduleDirect(() -> callback.onError(code, e));
                    }
                }
            }, mScheduler);
        });
    }

    public static boolean isNotFondFileMetadata(Throwable e) {
        if (e != null && e instanceof AmazonS3Exception) {
            if (((AmazonS3Exception) e).getStatusCode() == 404) {
                return true;
            }
        }
        return false;
    }

    private final static Pattern PATTERN_BUCKET = Pattern.compile("(^[a-z]$|^[a-z][a-z0-9-]*[a-z0-9]$)");

    public static String checkBucketName(String bucketName) throws AwsException {
        if (bucketName == null) {
            throw new BucketNameException("bucket name is null.");
        }
        while (true) {
            if (bucketName.startsWith("/")) {
                bucketName = bucketName.substring(1);
                continue;
            } else if (bucketName.endsWith("/")) {
                bucketName = bucketName.substring(0, bucketName.length() - 1);
                continue;
            }
            break;
        }
        if (PATTERN_BUCKET.matcher(bucketName).matches()) {
            return bucketName;
        }
        throw new BucketNameException("bucket name is unuseful.");
    }

    public static String checkKey(String key) throws AwsException {
        if (key == null) {
            throw new KeyException("key is null.");
        }
        while (true) {
            if (key.startsWith("/")) {
                key = key.substring(1);
                continue;
            } else if (key.endsWith("/")) {
                key = key.substring(0, key.length() - 1);
                continue;
            }
            break;
        }
        if (key.length() > 0 && key.length() <= 512) {
            return key;
        }
        throw new KeyException("key is unuseful.");
    }

    public interface TransferBridge {
        void pause();

        void resume();

        void cancel();
    }

    public interface OnBaseCallback<T> {
        void onSuccess(T bean);

        void onError(int code, Throwable e);
    }

    public interface OnProgressCallback<T> {
        void onSuccess(T bean);

        default void onPaused() {
        }

        default void onResumed() {
        }

        default void onCanceled() {
        }

        default void onProgress(float percent) {
        }

        void onError(int code, Throwable e);

        default void bindTransfer(TransferBridge bridge) {
        }
    }

    public static class AwsException extends Exception {
        public AwsException(String message) {
            super(message);
        }
    }

    public static class BucketNameException extends AwsException {
        public BucketNameException(String message) {
            super(message);
        }
    }

    public static class KeyException extends AwsException {
        public KeyException(String message) {
            super(message);
        }
    }

}
