#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>

@interface MovieExporterPlugIn : QCPlugIn
{
	NSTimeInterval							_time;
	QTMovie*								_movie;
	NSArray*								_codecTypes,
											*_codecKeys;
	NSUInteger								_codecQuality,
											_codecIndex;
	pthread_mutex_t							_threadMutex;
	pthread_cond_t							_threadCondition;
	CFRunLoopRef							_runLoop;
	CFRunLoopSourceRef						_source;
	
	NSImage*								_currentImage, *_previousImage;
	id<QCPlugInInputImageSource>			_currentQCImage, _previousQCImage;
	QTTime									_previousDuration;
}

/* Declare a property input port of type "Boolean" and with the key "inputExport" */
@property BOOL inputExport;

/* Declare a property input port of type "String" and with the key "inputExportPath" */
@property(assign) NSString* inputExportPath;

/* Declare a property input port of type "Image" and with the key "inputImage" */
@property(assign) id<QCPlugInInputImageSource> inputImage;

@end
