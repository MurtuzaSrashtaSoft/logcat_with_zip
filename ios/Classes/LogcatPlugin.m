#import "LogcatPlugin.h"
#import "UserUtil.h"

@implementation LogcatPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"app.channel.logcat"
            binaryMessenger:[registrar messenger]];
  LogcatPlugin* instance = [[LogcatPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"execLogcat" isEqualToString:call.method]) {
    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [allPaths objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"logfile.txt"];
    // read the contents into a string
    NSString *content = [[NSString alloc] initWithContentsOfFile:fileName
                                                  usedEncoding:nil
                                                          error:nil];
    NSLog(@"content: %@", content);
    result(content);
  }else if ([@"zipAndEncryptLogFile" isEqualToString:call.method]) {
    result([UserUtil zipAndEncryptFile: call.arguments[@"srcFilePath"] toPath: call.arguments[@"dstFilePath"] toKey:call.arguments[@"key"]]);
  }else if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
