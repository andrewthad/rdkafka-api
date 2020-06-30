#include <librdkafka/rdkafka.h>

-- | Message corresponds to @rd_kafka_message_t@ and has these fields:
--
-- > rd_kafka_resp_err_t err
-- > rd_kafka_topic_t *  rkt
-- > int32_t             partition
-- > void *              payload
-- > size_t              len
-- > void *              key
-- > size_t              key_len
-- > int64_t             offset
-- > void *              _private
module Rdkafka.Struct.Message
  ( peekError
  , peekPartition
  , peekPayload
  , peekLength
  , peekKey
  , peekKeyLength
  , peekOffset
  , peekPrivate
  ) where

import Data.Int (Int32,Int64)
import Data.Void (Void)
import Foreign.C.Types (CSize)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peekByteOff)
import Rdkafka.Types (Message,ResponseError,MessageOpaque(..))

peekError :: Ptr Message -> IO ResponseError
peekError = #{peek rd_kafka_message_t, err}

peekPartition :: Ptr Message -> IO Int32
peekPartition = #{peek rd_kafka_message_t, partition}

peekPayload :: Ptr Message -> IO (Ptr Void)
peekPayload = #{peek rd_kafka_message_t, payload}

peekLength :: Ptr Message -> IO CSize
peekLength = #{peek rd_kafka_message_t, len}

peekKey :: Ptr Message -> IO (Ptr Void)
peekKey = #{peek rd_kafka_message_t, key}

peekKeyLength :: Ptr Message -> IO (Ptr CSize)
peekKeyLength = #{peek rd_kafka_message_t, key_len}

peekOffset :: Ptr Message -> IO Int64
peekOffset = #{peek rd_kafka_message_t, offset}

peekPrivate :: Ptr Message -> IO MessageOpaque
peekPrivate ptr = do
  p <- #{peek rd_kafka_message_t, _private} ptr
  pure (MessageOpaque p)
