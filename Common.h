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
#define SERVER_HOST @"192.168.1.13"

#define CONNECTION_TIMEOUT 5
#define READ_TIMEOUT -1
#define WRITE_TIMEOUT -1

#define READ_RIGHT_TAG  1975
#define READ_LEFT_TAG   3012

enum Command {
    NoCommand,
    Accept,
    Reject,
    Start,
    Data,
    Stop,
    Finish
};

enum Media {
    Common,
    Video,
    Audio
};

struct Packet {
    enum Command    command;
    enum Media      media;
    long            dataLength;
};

#endif
