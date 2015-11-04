#import <Quartz/Quartz.h>

@interface SimpleTextPlugIn : QCPlugIn
{
	NSString*					text;
}

/* Declare an internal setting as a property of type NSString* */
@property(copy) NSString* text;

/* Declare a property output port of type "String" and with the key "outputString" */
@property(assign) NSString* outputString;

@end
