#import <Quartz/Quartz.h>

@interface SpeechSynthesisPlugIn : QCPlugIn
{
	NSSpeechSynthesizer*			_synthetizer;
}

/* Declare a property input port of type "String" and with the key "inputVoice" */
@property(assign) NSString* inputVoice;

/* Declare a property input port of type "String" and with the key "inputText" */
@property(assign) NSString* inputText;

@end
