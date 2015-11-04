#import <Quartz/Quartz.h>

@interface SQLiteQueryPlugIn : QCPlugIn

/* Declare a property input port of type "String" and with the key "inputDataBasePath" */
@property(assign) NSString* inputDataBasePath;

/* Declare a property input port of type "String" and with the key "inputQueryString" */
@property(assign) NSString* inputQueryString;

/* Declare a property output port of type "Structure" and with the key "outputResultStructure" */
@property(assign) NSArray* outputResultStructure;

@end
