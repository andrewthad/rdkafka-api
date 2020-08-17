#include <librdkafka/rdkafka.h>
#include <string.h>
#include "Rts.h"

rd_kafka_resp_err_t hsrdk_copy_version_string(char* dst) {
  const char* src = rd_kafka_version_str();
  size_t len = strlen(src);
  memcpy(dst,src,len);
  return (HsInt)len;
}

rd_kafka_resp_err_t hsrdk_push_nonblocking_noncopying_opaque(
  rd_kafka_t* rk,
  char* topic,
  char* base,
  HsInt off,
  HsInt len,
  void* stable) {
  void* buf = (void*)(base + off);
  // Send the message with no explicit instructions about copying or
  // freeing the payload. We destroy the StablePtr in the
  // delivery callback.
  return rd_kafka_producev(
    rk,
    RD_KAFKA_V_TOPIC(topic),
    RD_KAFKA_V_VALUE(buf,(size_t)len),
    RD_KAFKA_V_OPAQUE(stable),
    RD_KAFKA_V_END);
}

rd_kafka_resp_err_t hsrdk_push_blocking_noncopying_opaque(
  rd_kafka_t* rk,
  char* topic,
  char* base,
  HsInt off,
  HsInt len,
  void* stable) {
  void* buf = (void*)(base + off);
  // The message is in pinned memory, so making a copy would be silly.
  return rd_kafka_producev(
    rk,
    RD_KAFKA_V_TOPIC(topic),
    RD_KAFKA_V_VALUE(buf,(size_t)len),
    RD_KAFKA_V_OPAQUE(stable),
    RD_KAFKA_V_MSGFLAGS(RD_KAFKA_MSG_F_BLOCK),
    RD_KAFKA_V_END);
}

rd_kafka_resp_err_t hsrdk_push_nonblocking_copying_opaque(
  rd_kafka_t* rk,
  char* topic,
  char* base,
  HsInt off,
  HsInt len,
  void* stable) {
  void* buf = (void*)(base + off);
  // The message is in unpinned memory, so we must make a copy of it.
  return rd_kafka_producev(
    rk,
    RD_KAFKA_V_TOPIC(topic),
    RD_KAFKA_V_VALUE(buf,(size_t)len),
    RD_KAFKA_V_OPAQUE(stable),
    RD_KAFKA_V_MSGFLAGS(RD_KAFKA_MSG_F_COPY),
    RD_KAFKA_V_END);
}

rd_kafka_resp_err_t hsrdk_push_nonblocking_copying_no_opaque(
  rd_kafka_t* rk,
  char* topic,
  char* base,
  HsInt off,
  HsInt len) {
  void* buf = (void*)(base + off);
  // The message is in unpinned memory, so we must make a copy of it.
  return rd_kafka_producev(
    rk,
    RD_KAFKA_V_TOPIC(topic),
    RD_KAFKA_V_VALUE(buf,(size_t)len),
    RD_KAFKA_V_MSGFLAGS(RD_KAFKA_MSG_F_COPY),
    RD_KAFKA_V_END);
}

// Variant of rd_kafka_CreateTopics where you only want to create a
// single topic. We also do a HsInt-to-size_t conversion in here.
void hsrdk_create_topic(
  rd_kafka_t* rk,
  rd_kafka_NewTopic_t* new_topic,
  const rd_kafka_AdminOptions_t* options,
  rd_kafka_queue_t* rkqu) {
  rd_kafka_NewTopic_t* ktopics[1];
  ktopics[0] = new_topic;
  rd_kafka_CreateTopics(rk,ktopics,1,options,rkqu);
  return;
}
