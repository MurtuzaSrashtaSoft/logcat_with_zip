//
//  NSData+AESCrypt.h
//
//  AES128Encryption + Base64Encoding
//  @tharindu http://tharindufit.wordpress.com
//
//

#import "NSData+AESCrypt.h"
#import <CommonCrypto/CommonCryptor.h>
#import "zlib.h"

static char encodingTable[64] = 
{
   'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
   'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
   'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
   'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
};

@implementation NSData (AESCrypt)

+(NSData*) gzipData: (NSData*)pUncompressedData
{
    /*
     Special thanks to Robbie Hanson of Deusty Designs for sharing sample code
     showing how deflateInit2() can be used to make zlib generate a compressed
     file with gzip headers:
     
     http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html
     
     */
    
    if (!pUncompressedData || [pUncompressedData length] == 0)
    {
        NSLog(@"%s: Error: Can't compress an empty or null NSData object.", __func__);
        return nil;
    }
    
    /* Before we can begin compressing (aka "deflating") data using the zlib
     functions, we must initialize zlib. Normally this is done by calling the
     deflateInit() function; in this case, however, we'll use deflateInit2() so
     that the compressed data will have gzip headers. This will make it easy to
     decompress the data later using a tool like gunzip, WinZip, etc.
     
     deflateInit2() accepts many parameters, the first of which is a C struct of
     type "z_stream" defined in zlib.h. The properties of this struct are used to
     control how the compression algorithms work. z_stream is also used to
     maintain pointers to the "input" and "output" byte buffers (next_in/out) as
     well as information about how many bytes have been processed, how many are
     left to process, etc. */
    z_stream zlibStreamStruct;
    zlibStreamStruct.zalloc    = Z_NULL; // Set zalloc, zfree, and opaque to Z_NULL so
    zlibStreamStruct.zfree     = Z_NULL; // that when we call deflateInit2 they will be
    zlibStreamStruct.opaque    = Z_NULL; // updated to use default allocation functions.
    zlibStreamStruct.total_out = 0; // Total number of output bytes produced so far
    zlibStreamStruct.next_in   = (Bytef*)[pUncompressedData bytes]; // Pointer to input bytes
    zlibStreamStruct.avail_in  = (unsigned int)[pUncompressedData length]; // Number of input bytes left to process
    
    /* Initialize the zlib deflation (i.e. compression) internals with deflateInit2().
     The parameters are as follows:
     
     z_streamp strm - Pointer to a zstream struct
     int level      - Compression level. Must be Z_DEFAULT_COMPRESSION, or between
     0 and 9: 1 gives best speed, 9 gives best compression, 0 gives
     no compression.
     int method     - Compression method. Only method supported is "Z_DEFLATED".
     int windowBits - Base two logarithm of the maximum window size (the size of
     the history buffer). It should be in the range 8..15. Add
     16 to windowBits to write a simple gzip header and trailer
     around the compressed data instead of a zlib wrapper. The
     gzip header will have no file name, no extra data, no comment,
     no modification time (set to zero), no header crc, and the
     operating system will be set to 255 (unknown).
     int memLevel   - Amount of memory allocated for internal compression state.
     1 uses minimum memory but is slow and reduces compression
     ratio; 9 uses maximum memory for optimal speed. Default value
     is 8.
     int strategy   - Used to tune the compression algorithm. Use the value
     Z_DEFAULT_STRATEGY for normal data, Z_FILTERED for data
     produced by a filter (or predictor), or Z_HUFFMAN_ONLY to
     force Huffman encoding only (no string match) */
    int initError = deflateInit2(&zlibStreamStruct, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
    if (initError != Z_OK)
    {
        NSString *errorMsg = nil;
        switch (initError)
        {
            case Z_STREAM_ERROR:
                errorMsg = @"Invalid parameter passed in to function.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Insufficient memory.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        NSLog(@"%s: deflateInit2() Error: \"%@\" Message: \"%s\"", __func__, errorMsg, zlibStreamStruct.msg);
        return nil;
    }
    
    // Create output memory buffer for compressed data. The zlib documentation states that
    // destination buffer size must be at least 0.1% larger than avail_in plus 12 bytes.
    NSMutableData *compressedData = [NSMutableData dataWithLength:[pUncompressedData length] * 1.01 + 12];
    
    int deflateStatus;
    do
    {
        // Store location where next byte should be put in next_out
        zlibStreamStruct.next_out = [compressedData mutableBytes] + zlibStreamStruct.total_out;
        
        // Calculate the amount of remaining free space in the output buffer
        // by subtracting the number of bytes that have been written so far
        // from the buffer's total capacity
        zlibStreamStruct.avail_out = (unsigned int)[compressedData length] - (unsigned int)zlibStreamStruct.total_out;

        /* deflate() compresses as much data as possible, and stops/returns when
         the input buffer becomes empty or the output buffer becomes full. If
         deflate() returns Z_OK, it means that there are more bytes left to
         compress in the input buffer but the output buffer is full; the output
         buffer should be expanded and deflate should be called again (i.e., the
         loop should continue to rune). If deflate() returns Z_STREAM_END, the
         end of the input stream was reached (i.e.g, all of the data has been
         compressed) and the loop should stop. */
        deflateStatus = deflate(&zlibStreamStruct, Z_FINISH);
        
    } while ( deflateStatus == Z_OK );
    
    // Check for zlib error and convert code to usable error message if appropriate
    if (deflateStatus != Z_STREAM_END)
    {
        NSString *errorMsg = nil;
        switch (deflateStatus)
        {
            case Z_ERRNO:
                errorMsg = @"Error occured while reading file.";
                break;
            case Z_STREAM_ERROR:
                errorMsg = @"The stream state was inconsistent (e.g., next_in or next_out was NULL).";
                break;
            case Z_DATA_ERROR:
                errorMsg = @"The deflate data was invalid or incomplete.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Memory could not be allocated for processing.";
                break;
            case Z_BUF_ERROR:
                errorMsg = @"Ran out of output buffer for writing compressed bytes.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        NSLog(@"%s: zlib error while attempting compression: \"%@\" Message: \"%s\"", __func__, errorMsg, zlibStreamStruct.msg);
        
        // Free data structures that were dynamically created for the stream.
        deflateEnd(&zlibStreamStruct);
        
        return nil;
    }
    // Free data structures that were dynamically created for the stream.
    deflateEnd(&zlibStreamStruct);
    [compressedData setLength: zlibStreamStruct.total_out];
    
    return compressedData;
}

- (NSData *)AES128EncryptWithKey:(NSString *)key
{
    // 'key' should be 16 bytes for AES128
    char keyPtr[kCCKeySizeAES128 + 1]; // room for terminator (unused)
    bzero( keyPtr, sizeof( keyPtr ) ); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof( keyPtr ) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or 
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc( bufferSize );
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt( kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode | kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES128,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted );
    if( cryptStatus == kCCSuccess )
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free( buffer ); //free the buffer
    return nil;
}

- (NSData*)EncryptAES:(NSString *)key
{
    char keyPtr[kCCKeySizeAES128+1];
    bzero( keyPtr, sizeof(keyPtr) );
    
    [key getCString: keyPtr maxLength: sizeof(keyPtr) encoding: NSUTF8StringEncoding];
    size_t numBytesEncrypted = 0;
    
    NSUInteger dataLength = [self length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    //    const unsigned char iv[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    
    CCCryptorStatus result = CCCrypt( kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                     keyPtr, kCCKeySizeAES128,
                                     nil,
                                     [self bytes], [self length],
                                     buffer, bufferSize,
                                     &numBytesEncrypted );
    
    if( result == kCCSuccess )
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    
    free(buffer);
    return nil;
}

- (NSData *)DecryptAES:(NSString *)key
{
    char  keyPtr[kCCKeySizeAES128+1];
    bzero( keyPtr, sizeof(keyPtr) );
    
    [key getCString: keyPtr maxLength: sizeof(keyPtr) encoding: NSUTF8StringEncoding];
    
    size_t numBytesEncrypted = 0;
    
    NSUInteger dataLength = [self length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer_decrypt = malloc(bufferSize);
    //    const unsigned char iv[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    CCCryptorStatus result = CCCrypt(1 , kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                     keyPtr, kCCKeySizeAES128,
                                     nil,
                                     [self bytes], [self length],
                                     buffer_decrypt, bufferSize,
                                     &numBytesEncrypted );
    
    if( result == kCCSuccess )
        return [NSData dataWithBytesNoCopy:buffer_decrypt length:numBytesEncrypted];
    
    free(buffer_decrypt);
    return nil;
}

#pragma mark -

- (NSString *)base64Encoding
{
   const unsigned char   *bytes = [self bytes];
   NSMutableString *result = [NSMutableString stringWithCapacity:self.length];
   unsigned long ixtext = 0;
   unsigned long lentext = self.length;
   long ctremaining = 0;
   unsigned char inbuf[3], outbuf[4];
   unsigned short i = 0;
   unsigned short charsonline = 0, ctcopy = 0;
   unsigned long ix = 0;
   
   while( YES )
   {
      ctremaining = lentext - ixtext;
      if( ctremaining <= 0 ) break;
      
      for( i = 0; i < 3; i++ )
      {
         ix = ixtext + i;
         if( ix < lentext ) inbuf[i] = bytes[ix];
         else inbuf [i] = 0;
      }
      
      outbuf [0] = (inbuf [0] & 0xFC) >> 2;
      outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
      outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
      outbuf [3] = inbuf [2] & 0x3F;
      ctcopy = 4;
      
      switch( ctremaining )
      {
         case 1:
            ctcopy = 2;
            break;
         case 2:
            ctcopy = 3;
            break;
      }
      
      for( i = 0; i < ctcopy; i++ )
         [result appendFormat:@"%c", encodingTable[outbuf[i]]];
      
      for( i = ctcopy; i < 4; i++ )
         [result appendString:@"="];
      
      ixtext += 3;
      charsonline += 4;
      
   }
   
   return [NSString stringWithString:result];
}

+ (NSData *)base64DataFromString:(NSString *)string
{
    unsigned long ixtext, lentext;
    unsigned char ch, inbuf[4], outbuf[3];
    short i, ixinbuf;
    Boolean flignore, flendtext = false;
    const unsigned char *tempcstring;
    NSMutableData *theData;
    
    if (string == nil)
    {
        return [NSData data];
    }
    
    ixtext = 0;
    
    tempcstring = (const unsigned char *)[string UTF8String];
    
    lentext = [string length];
    
    theData = [NSMutableData dataWithCapacity: lentext];
    
    ixinbuf = 0;
    
    while (true)
    {
        if (ixtext >= lentext)
        {
            break;
        }
        
        ch = tempcstring [ixtext++];
        
        flignore = false;
        
        if ((ch >= 'A') && (ch <= 'Z'))
        {
            ch = ch - 'A';
        }
        else if ((ch >= 'a') && (ch <= 'z'))
        {
            ch = ch - 'a' + 26;
        }
        else if ((ch >= '0') && (ch <= '9'))
        {
            ch = ch - '0' + 52;
        }
        else if (ch == '+')
        {
            ch = 62;
        }
        else if (ch == '=')
        {
            flendtext = true;
        }
        else if (ch == '/')
        {
            ch = 63;
        }
        else
        {
            flignore = true;
        }
        
        if (!flignore)
        {
            short ctcharsinbuf = 3;
            Boolean flbreak = false;
            
            if (flendtext)
            {
                if (ixinbuf == 0)
                {
                    break;
                }
                
                if ((ixinbuf == 1) || (ixinbuf == 2))
                {
                    ctcharsinbuf = 1;
                }
                else
                {
                    ctcharsinbuf = 2;
                }
                
                ixinbuf = 3;
                
                flbreak = true;
            }
            
            inbuf [ixinbuf++] = ch;
            
            if (ixinbuf == 4)
            {
                ixinbuf = 0;
                
                outbuf[0] = (inbuf[0] << 2) | ((inbuf[1] & 0x30) >> 4);
                outbuf[1] = ((inbuf[1] & 0x0F) << 4) | ((inbuf[2] & 0x3C) >> 2);
                outbuf[2] = ((inbuf[2] & 0x03) << 6) | (inbuf[3] & 0x3F);
                
                for (i = 0; i < ctcharsinbuf; i++)
                {
                    [theData appendBytes: &outbuf[i] length: 1];
                }
            }
            
            if (flbreak)
            {
                break;
            }
        }
    }
    
    return theData;
}

@end
