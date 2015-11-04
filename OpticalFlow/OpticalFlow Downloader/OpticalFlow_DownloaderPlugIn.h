#import <Quartz/Quartz.h>

@interface OpticalFlow_DownloaderPlugIn : QCPlugIn
{
}

@property(assign) id<QCPlugInInputImageSource> inputImage;
@property(assign) NSDictionary* outputVelocities;

@end
