#import <Quartz/Quartz.h>

@interface CommandLineToolPlugIn : QCPlugIn
{
	NSUInteger				_argumentCount;
}

/* Declare a property input port of type "String" and with the key "inputPath" */
@property(assign) NSString* inputPath;

/* Declare a property input port of type "String" and with the key "inputStandardIn" */
@property(assign) NSString* inputStandardIn;

/* Declare a property output port of type "Number" and with the key "outputStatus" */
@property double outputStatus;

/* Declare a property output port of type "String" and with the key "outputStandardOut" */
@property(assign) NSString* outputStandardOut;

/* Declare a property output port of type "String" and with the key "outputStandardError" */
@property(assign) NSString* outputStandardError;

@end
