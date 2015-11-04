#import <Quartz/Quartz.h>

@interface iPatchPlugIn : QCPlugIn
{
}

/* Declare a property input port of type "String" and with the key "inputString" */
@property(assign) NSString* inputString;

/* Declare a property output port of type "String" and with the key "outputString" */
@property(assign) NSString* outputString;

@end
