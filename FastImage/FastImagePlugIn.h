#import <Quartz/Quartz.h>

@interface FastImagePlugIn : QCPlugIn
{
	id						_placeHolderProvider;
}

/* Declare a property output port of type "Image" and with the key "outputImage" */
@property(assign) id<QCPlugInOutputImageProvider> outputImage;

@end
