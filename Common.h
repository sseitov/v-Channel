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

#define CONNECTION_TIMEOUT 5
#define READ_TIMEOUT -1
#define WRITE_TIMEOUT -1

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
    enum Command    command;
    long            dataLength;
};

#endif
