#include <librdkafka/rdkafka.h>

-- | Message corresponds to @rd_kafka_topic_partition_t@ and has these fields:
--
-- > char *               topic
-- > int32_t              partition
-- > int64_t              offset
-- > void *               metadata
-- > size_t               metadata_size
-- > void *               opaque
-- > rd_kafka_resp_err_t  err
-- > void *               _private
module Rdkafka.Struct.TopicPartition
  ( -- * Getters
    peekError
  , peekTopic
  , peekPartition
  , peekOffset
    -- * Setters
  , pokeOffset
  ) where

import Data.Int (Int32,Int64)
import Data.Void (Void)
import Foreign.C.Types (CSize)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peekByteOff,pokeByteOff)
import Rdkafka.Types (Topic,TopicPartition,ResponseError,Partition)

-- | Get field @rkt@
peekTopic :: Ptr TopicPartition -> IO (Ptr Topic)
peekTopic = #{peek rd_kafka_topic_partition_t, topic}

-- | Get field @err@
peekError :: Ptr TopicPartition -> IO ResponseError
peekError = #{peek rd_kafka_topic_partition_t, err}

-- | Get field @partition@
peekPartition :: Ptr TopicPartition -> IO Partition
peekPartition = #{peek rd_kafka_topic_partition_t, partition}

-- | Get field @offset@
peekOffset :: Ptr TopicPartition -> IO Int64
peekOffset = #{peek rd_kafka_topic_partition_t, offset}

-- | Set field @offset@
pokeOffset :: Ptr TopicPartition -> Int64 -> IO ()
pokeOffset = #{poke rd_kafka_topic_partition_t, offset}
