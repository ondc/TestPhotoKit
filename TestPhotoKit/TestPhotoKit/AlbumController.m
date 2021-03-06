//
//  AlbumController.m
//  TestPhotoKit
//
//  Created by admin on 16/7/8.
//  Copyright © 2016年 admin. All rights reserved.
//

#import "AlbumController.h"
#import "ContainView.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface AlbumController ()<UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) ContainView *containView;
@property (nonatomic, strong) PHImageRequestOptions *options;
@property (nonatomic, strong) PHFetchResult<PHAsset *> *assets;

@end

@implementation AlbumController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [self getAllPhotosFromAlbum];
    
#pragma mark - 获取video   这段代码这个VC没有使用
    PHFetchResult<PHAsset *> *assetsResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:nil];
    PHVideoRequestOptions *options2 = [[PHVideoRequestOptions alloc] init];
    options2.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    [options2 setNetworkAccessAllowed:true];
    for (PHAsset *a in assetsResult) {
        [[PHImageManager defaultManager] requestAVAssetForVideo:a options:options2 resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            NSLog(@"%@",info);
            NSLog(@"%@",audioMix);
            NSLog(@"%@",((AVURLAsset*)asset).URL);//asset为AVURLAsset类型  可直接获取相应视频的相对地址
//            NSString *path = ((AVURLAsset*)asset).URL.path;//
        }];
    }
}

- (void)setupViews {
    self.view.backgroundColor = [UIColor whiteColor];
    self.containView =[[ContainView alloc] initWithFrame:self.view.bounds delegate:self];
    [self.view addSubview:self.containView];
}

//从系统中捕获所有相片
- (void)getAllPhotosFromAlbum {
    self.options = [[PHImageRequestOptions alloc] init];//请求选项设置
    self.options.resizeMode = PHImageRequestOptionsResizeModeExact;//自定义图片大小的加载模式
    self.options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    self.options.synchronous = YES;//是否同步加载
    
    //容器类
    self.assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil]; //得到所有图片
    /*
     PHAssetMediaType：
     PHAssetMediaTypeUnknown = 0,//在这个配置下，请求不会返回任何东西
     PHAssetMediaTypeImage   = 1,//图片
     PHAssetMediaTypeVideo   = 2,//视频
     PHAssetMediaTypeAudio   = 3,//音频
     */
    [self.containView.collectionView reloadData]; 
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AlbumCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:ALBUMCELLID forIndexPath:indexPath];
//    cell.backgroundColor= [UIColor redColor];
    
    //9.0可用
    CGSizeMake(self.assets[indexPath.row].pixelWidth, self.assets[indexPath.row].pixelHeight);
    
    [self adjustGIFWithAsset2:self.assets[indexPath.row]];
    [[PHImageManager defaultManager] requestImageForAsset:self.assets[indexPath.row] targetSize: CGSizeMake(110, 110) contentMode:PHImageContentModeDefault options:self.options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.photoImageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.photoImageView.image = result;
////        NSLog(@"%@",result);
//        NSLog(@"%ld",self.num);
//        NSLog(@"%@",info.allKeys);
//        NSLog(@"---------------------------------------------------------------");
    }];
    return cell;
}


/** 关于localIdentifier：
 * 我们可以在第一次获取到相册中的 GIF 的时候，将其获取到的所有 GIF 的 localIdentifier 记录下来。这样，下次启动的时候，就可以通过这些 localIdentifier 来直接获取 GIF 资源
 *  PHAsset fetchAssetsWithLocalIdentifiers:<#(nonnull NSArray<NSString *> *)#> options:<#(nullable PHFetchOptions *)#>
 */
#pragma mark - 判断资源是不是GIF ：（资源类型判别可以为UI提供一些图片类型的指示）
////方法1 iOS 9.0
- (BOOL)adjustGIFWithAsset:(PHAsset *)asset {
    if ([asset isKindOfClass:[PHAsset class]]) {
        //每个asset 都有一个或者多个PHAssetResource(如：被编辑保存过的aseet会有若干个resource, 且被修改后的GIF类型的asset得uniformTypeIdentifier 会发生改变变成了public.jpeg 类型，所以修改多地GIF的就不再是GIF了，所以要对比最后一个resource的类型)
        NSArray<PHAssetResource *>* tmpArr = [PHAssetResource assetResourcesForAsset:asset];
        if (tmpArr.count) {
            PHAssetResource *resource = tmpArr.lastObject;
            if (resource.uniformTypeIdentifier.length) {
               return UTTypeConformsTo( (__bridge CFStringRef)resource.uniformTypeIdentifier, kUTTypeGIF);
            }
        }
    }
    return false;
}

//方法2
- (BOOL)adjustGIFWithAsset2:(PHAsset *)asset {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    [options setSynchronous:true];//同步
    __block NSString *dataUTIStr = nil;
    if ([asset isKindOfClass:[PHAsset class]]) {
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            dataUTIStr = dataUTI;
        }];
    }
    if (dataUTIStr.length) {
        return UTTypeConformsTo( (__bridge CFStringRef)dataUTIStr, kUTTypeGIF);
    }
    return false;
}

/**mov转mp4格式 最好设一个block 转完码之后的回调*/
-(void)convertMovWithSourceURL:(NSURL *)sourceUrl fileName:(NSString *)fileName saveExportFilePath:(NSString *)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:sourceUrl options:nil];
    NSArray *compatiblePresets=[AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];//输出模式标识符的集合
    if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
        
        AVAssetExportSession *exportSession=[[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetMediumQuality];
        NSString *resultPath = [path stringByAppendingFormat:@"/%@.mp4",fileName]; 
        exportSession.outputURL=[NSURL fileURLWithPath:resultPath];//输出路径
        exportSession.outputFileType = AVFileTypeMPEG4;//输出类型
        exportSession.shouldOptimizeForNetworkUse = YES;//为网络使用时做出最佳调整
       
        [exportSession exportAsynchronouslyWithCompletionHandler:^(void){//异步输出转码视频
            switch (exportSession.status) {
                case AVAssetExportSessionStatusCancelled:
                    NSLog(@"转码状态：取消转码");
                    break;
                case AVAssetExportSessionStatusUnknown:
                    NSLog(@"转码状态：未知");
                    break;
                case AVAssetExportSessionStatusWaiting:
                    NSLog(@"转码状态：等待转码");
                    break;
                case AVAssetExportSessionStatusExporting:
                    NSLog(@"转码状态：正在转码");
                    break;
                case AVAssetExportSessionStatusCompleted:
                {
                    NSLog(@"转码状态：完成转码");
                        NSArray *files=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
                    for (NSString *fn in files) {
                        if ([resultPath isEqualToString:fn]) {
                            NSLog(@"转码状态：完成转码 文件存在");
                        }
                    }
                    break;
                }
                case AVAssetExportSessionStatusFailed:
                     NSLog(@"转码状态：转码失败");
                    NSLog(@"%@",exportSession.error.description);
                    break;
            }
        }];
    }
}

@end
