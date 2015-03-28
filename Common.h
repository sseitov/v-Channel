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

enum MediaType {
    Video,
    Audio
};

enum Command {
    Accept = 1,
    Reject,
    Start,
    Started,
    Stop,
    Data,
    Finish
};

#endif
