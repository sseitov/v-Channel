//
//  Common.h
//  v-Channel
//
//  Created by Sergey Seitov on 28.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#ifndef v_Channel_Common_h
#define v_Channel_Common_h

#define SERVER_PORT 1964
#define SERVER_HOST @"192.168.1.15"

#define DEFAULT_CONNECTION_TIMEOUT 5

#define READ_TAG    1402

enum Command {
    NoCommand,
    Accept,
    Reject,
    VideoStart,
    VideoStarted,
    VideoData,
    Finish
};

struct Packet {
    uint32_t    command;
    uint32_t    dataLength;
};

#define HEADER_SIZE 8

#endif
