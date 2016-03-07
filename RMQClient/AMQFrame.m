#import "AMQFrame.h"
#import "AMQMethodDecoder.h"

@interface AMQFrame ()
@property (nonatomic, copy, readwrite) NSNumber *channelNumber;
@property (nonatomic, readwrite) id<AMQPayload> payload;
@end

typedef NS_ENUM(char, AMQFrameType) {
    AMQFrameTypeMethod = 1,
    AMQFrameTypeContentHeader,
    AMQFrameTypeContentBody,
};

@implementation AMQFrame

- (instancetype)initWithChannelNumber:(NSNumber *)channelNumber
                          payload:(id<AMQPayload>)payload {
    self = [super init];
    if (self) {
        self.channelNumber = channelNumber;
        self.payload = payload;
    }
    return self;
}

- (instancetype)initWithParser:(AMQParser *)parser {
    char typeID         = [parser parseOctet];
    NSNumber *channelNumber = @([parser parseShortUInt]);
    UInt32 payloadSize  = [parser parseLongUInt];

    id <AMQPayload> payload;
    switch (typeID) {
        case AMQFrameTypeContentHeader:
            payload = [[AMQContentHeader alloc] initWithParser:parser];
            break;

        case AMQFrameTypeContentBody:
            payload = [[AMQContentBody alloc] initWithParser:parser payloadSize:payloadSize];
            break;

        default:
            payload = [[[AMQMethodDecoder alloc] initWithParser:parser] decode];
            break;
    }

    return [self initWithChannelNumber:channelNumber payload:payload];
}

- (NSData *)amqEncoded {
    NSMutableData *frameData = [NSMutableData new];
    NSArray *unencodedFrame = @[[[AMQOctet alloc] init:self.payload.frameTypeID.integerValue],
                                [[AMQShort alloc] init:self.channelNumber.integerValue],
                                [[AMQLong alloc] init:self.payload.amqEncoded.length],
                                self.payload,
                                [[AMQOctet alloc] init:0xCE]];
    for (id<AMQEncoding> part in unencodedFrame) {
        [frameData appendData:part.amqEncoded];
    }
    return frameData;
}

@end