#import <Quartz/Quartz.h>

@interface ImageInfo : QCPlugIn
{
	NSMutableArray*					_plugInControllers; 	/* Reference to the plug-in controllers */
	id<QCPlugInInputImageSource>	_image;					/* Reference to the inputImage */
}

/* Declare a property input port of type "Image" and with the key "inputImage" */
@property(assign) id<QCPlugInInputImageSource> inputImage;

@end
