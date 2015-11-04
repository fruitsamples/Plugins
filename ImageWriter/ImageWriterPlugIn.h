#import <Quartz/Quartz.h>

@interface ImageWriterPlugIn : QCPlugIn
{
	NSUInteger					_index;
}

/* Declare a property input port of type "Image" and with the key "inputImage" */
@property(assign) id<QCPlugInInputImageSource> inputImage;

/* Declare a property input port of type "String" and with the key "inputPath" */
@property(assign) NSString* inputPath;

@end
